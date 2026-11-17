#!/usr/bin/env python3
"""Verify and privately stage the four uploaded Ch02/Mixamo FBXs.

Never edits game data, overwrites different files, or publishes source binaries.
Requires zstd only when --archive is used; --sources accepts extracted files.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tarfile
import tempfile

SOURCES = {
    "Ch02_nonPBR.fbx": (50_037_840, "6a390659d923ebd1e80b6275490334d23cca593ec928db55669beeab81310e85"),
    "Jump.fbx": (50_409_472, "54ba333c8946d401bcfeba1c610522cc38e233f869012e1aa83d1ac5adf452c7"),
    "Start Walking.fbx": (50_492_992, "805643560b696a1929202a04a78d126dbc34b735e3296807104178f82b550ad0"),
    "Jogging.fbx": (50_466_080, "1f572e771f605c6cb14b2f8079403029dd0572c0eecdefba711f81134e224663"),
}
HEADER = b"Kaydara FBX Binary  \x00\x1a\x00"


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def _fbx_model_info(path: Path) -> dict:
    """Read FBX 7700 structural declarations, not an animation preview."""
    data = memoryview(path.read_bytes())
    if data[:23].tobytes() != HEADER or struct.unpack_from("<I", data, 23)[0] != 7700:
        raise ValueError("Unsupported FBX header/version: " + path.name)
    counts: Counter[str] = Counter()
    joints: list[str] = []
    source_end = len(data)

    def parse_props(start: int, amount: int) -> list:
        values = []
        pos = start
        for _ in range(amount):
            kind = chr(data[pos]); pos += 1
            if kind in "SR":
                size = struct.unpack_from("<I", data, pos)[0]; pos += 4
                values.append(bytes(data[pos:pos + size]).decode("utf8", "replace") if kind == "S" else None)
                pos += size
            elif kind in "LI":
                fmt = "<q" if kind == "L" else "<i"
                values.append(struct.unpack_from(fmt, data, pos)[0]); pos += 8 if kind == "L" else 4
            elif kind in "DF":
                fmt = "<d" if kind == "D" else "<f"
                values.append(struct.unpack_from(fmt, data, pos)[0]); pos += 8 if kind == "D" else 4
            elif kind == "C":
                values.append(bool(data[pos])); pos += 1
            elif kind == "Y":
                values.append(struct.unpack_from("<h", data, pos)[0]); pos += 2
            elif kind in "filbdc":
                count, encoding, compressed = struct.unpack_from("<III", data, pos)
                pos += 12 + compressed
                values.append(None)
            else:
                raise ValueError("Unknown FBX property " + kind + " in " + path.name)
        return values

    def scan(start: int, end: int, depth: int = 0, section: str = "") -> None:
        while start + 25 <= end:
            stop, num_props, bytes_props, name_size = struct.unpack_from("<QQQB", data, start)
            if stop == 0:
                return
            if stop <= start or stop > source_end:
                raise ValueError("Invalid FBX object offset in " + path.name)
            name = bytes(data[start + 25:start + 25 + name_size]).decode("utf8", "replace")
            counts[name] += 1
            props_at = start + 25 + name_size
            if section == "Objects" and depth == 1 and name == "Model":
                attrs = parse_props(props_at, int(num_props))
                if len(attrs) >= 3 and attrs[2] == "LimbNode":
                    joints.append(str(attrs[1]).split("\x00")[0])
            if depth == 0 and name == "Objects":
                scan(props_at + bytes_props, stop, 1, "Objects")
            start = stop

    scan(27, source_end)
    skeleton = sorted(joints)
    if len(skeleton) != 65 or counts["Model"] != 71 or counts["AnimationCurve"] < 300:
        raise ValueError("Uploaded FBX lacks original 65-bone animated Ch02 rig: " + path.name)
    if "mixamorig:Hips" not in skeleton or "mixamorig:RightHand" not in skeleton:
        raise ValueError("Missing required Mixamo skeleton bones: " + path.name)
    return {
        "fbx_version": 7700, "bones": skeleton, "bone_count": len(skeleton),
        "model_count": counts["Model"], "curve_count": counts["AnimationCurve"],
        "animation_stacks": counts["AnimationStack"],
        "animation_curve_nodes": counts["AnimationCurveNode"],
    }


def _extract_archive(archive: Path, dest: Path) -> None:
    if shutil.which("zstd") is None:
        raise RuntimeError("zstd command required to read private .tar.zst archive")
    proc = subprocess.Popen(["zstd", "-dc", str(archive)], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    try:
        found = set()
        assert proc.stdout is not None
        with tarfile.open(fileobj=proc.stdout, mode="r|") as tar:
            for item in tar:
                if item.name not in SOURCES or not item.isfile() or item.name in found:
                    raise ValueError("Unexpected, duplicate or unsafe archive member: " + item.name)
                found.add(item.name)
                if item.size != SOURCES[item.name][0]:
                    raise ValueError("Source size mismatch: " + item.name)
                source = tar.extractfile(item)
                if source is None:
                    raise ValueError("Archive entry unreadable: " + item.name)
                with (dest / item.name).open("wb") as out:
                    shutil.copyfileobj(source, out, 1 << 20)
        if found != set(SOURCES):
            raise ValueError("Missing source entries: " + repr(set(SOURCES) - found))
        proc.stdout.close()
        if proc.wait() != 0:
            raise ValueError("zstd decompression failed: " + proc.stderr.read().decode("utf8", "replace")[:300])
    finally:
        if proc.poll() is None:
            proc.kill(); proc.wait()
        if proc.stdout and not proc.stdout.closed:
            proc.stdout.close()
        if proc.stderr:
            proc.stderr.close()


def stage(source_dir: Path | None, archive: Path | None, project: Path,
          install: bool) -> dict:
    root = project.resolve()
    if root.name != "native-godot" or not (root / "project.godot").is_file():
        raise ValueError("--project must point to the native-godot project")
    if bool(source_dir) == bool(archive):
        raise ValueError("Exactly one of --sources or --archive is required")
    with tempfile.TemporaryDirectory(prefix="aurora_ch02_source_") as temp:
        staging = Path(temp)
        if archive:
            _extract_archive(archive.resolve(), staging)
        else:
            for name in SOURCES:
                src = source_dir.resolve() / name
                if not src.is_file() or src.is_symlink():
                    raise ValueError("Missing regular FBX original: " + name)
                shutil.copyfile(src, staging / name)
        report = []
        joint_reference = None
        for name, (size, expected) in SOURCES.items():
            file = staging / name
            if file.stat().st_size != size or digest(file) != expected:
                raise ValueError("Original size or SHA-256 mismatch: " + name)
            structure = _fbx_model_info(file)
            if joint_reference is None:
                joint_reference = structure["bones"]
            if joint_reference != structure["bones"]:
                raise ValueError("FBX bone names differ across motions: " + name)
            del structure["bones"]
            report.append({"name": name, "bytes": size, "sha256": expected, **structure})
        destination = root / "out" / "private_mixamo_sources"
        if install:
            destination.mkdir(parents=True, exist_ok=True)
            for item in report:
                source = staging / item["name"]
                target = destination / item["name"]
                if target.is_symlink():
                    raise ValueError("Destination symlink not allowed: " + str(target))
                if target.exists():
                    if not target.is_file() or digest(target) != item["sha256"]:
                        raise FileExistsError("Existing FBX differs; refusing overwrite: " + str(target))
                    continue
                with tempfile.NamedTemporaryFile(dir=destination, prefix=".mixamo_", delete=False) as tmp:
                    shutil.copyfileobj(source.open("rb"), tmp, 1 << 20)
                    temporary = Path(tmp.name)
                if digest(temporary) != item["sha256"]:
                    temporary.unlink(missing_ok=True)
                    raise ValueError("Temporary copied file failed digest")
                temporary.replace(target)
    return {
        "source_count": 4, "matching_bone_names": 65,
        "source_sha256_verified": True, "installed": install,
        "model_available_in_game": False,
        "godot_animation_import_validated": False,
        "files": report,
        "destination_if_installed": str(root / "out" / "private_mixamo_sources"),
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    inputs = p.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--sources", type=Path, help="directory containing four exact original FBX files")
    inputs.add_argument("--archive", type=Path, help="private tar.zst with four original FBX files")
    p.add_argument("--project", type=Path, required=True)
    p.add_argument("--install", action="store_true", help="copy verified source bytes to ignored out folder")
    p.add_argument("--report", type=Path)
    args = p.parse_args()
    result = stage(args.sources, args.archive, args.project, args.install)
    serialized = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.report:
        if args.report.exists():
            p.error("Refusing to overwrite existing audit file")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(serialized, encoding="utf8")
    print(serialized)


if __name__ == "__main__":
    main()