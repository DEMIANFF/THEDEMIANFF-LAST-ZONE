#!/usr/bin/env python3
"""Recover the 24 independent ZIPs without overwriting originals.

The delivered reconstruction script is executed only in a fresh staging
directory, after safe extraction. Success means byte integrity, never Godot
import, licensing clearance, animation retargeting or playable integration.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

REPO = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = REPO / "docs/aurora-v3/AURORA_V3_INVENTARIO_80.json"
LEGACY_SCRIPT = Path(__file__).resolve().parent / "aurora_v3/RECONSTRUIR_AURORA_V3.py"
PART_NAMES = tuple(f"AURORA_V3_ASSETS_{i:02d}_DE_24.zip" for i in range(1, 25))


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def manifest_entries(manifest):
    entries = manifest["files"]
    if len(entries) != manifest["received_files"]:
        raise ValueError("Manifest count mismatch")
    names = set()
    for item in entries:
        name = item["name"]
        if (not name or name in (".", "..") or "/" in name or "\\" in name
                or "\x00" in name or name in names):
            raise ValueError("Unsafe or repeated original name")
        if not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]):
            raise ValueError("Invalid SHA-256: " + name)
        if not isinstance(item["size_bytes"], int) or item["size_bytes"] < 0:
            raise ValueError("Invalid byte count: " + name)
        names.add(name)
    if sum(item["size_bytes"] for item in entries) != manifest["total_original_bytes"]:
        raise ValueError("Manifest total byte count mismatch")
    return entries


def verify_originals(originals, manifest):
    result = []
    for item in manifest_entries(manifest):
        path = Path(originals) / item["name"]
        if path.is_symlink() or not path.is_file():
            raise ValueError("Missing regular original: " + item["name"])
        if path.stat().st_size != item["size_bytes"]:
            raise ValueError("Incorrect size: " + item["name"])
        actual = sha256(path)
        if actual != item["sha256"]:
            raise ValueError("SHA-256 mismatch: " + item["name"])
        result.append({"file": item["name"], "bytes": path.stat().st_size,
                       "expected_sha256": item["sha256"], "actual_sha256": actual,
                       "integrity": "HECHO", "godot_import": "PENDIENTE",
                       "functionality": "PENDIENTE", "license_verified": False})
    return result


def extract_archives(archives, destination, byte_budget):
    consumed = 0
    destination = Path(destination).resolve()
    for archive in archives:
        with zipfile.ZipFile(archive) as bundle:
            for info in bundle.infolist():
                name = info.filename
                path = PurePosixPath(name)
                if (not name or path.is_absolute() or ".." in path.parts
                        or "\\" in name or "\x00" in name or ":" in name):
                    raise ValueError("Unsafe ZIP member: " + name)
                mode = info.external_attr >> 16
                if stat.S_ISLNK(mode) or stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
                    raise ValueError("Non-regular ZIP member: " + name)
                target = destination.joinpath(*path.parts)
                if not target.resolve().is_relative_to(destination):
                    raise ValueError("ZIP member escapes destination")
                if info.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                consumed += info.file_size
                if consumed > byte_budget:
                    raise ValueError("Archive expansion exceeds expected budget")
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists():
                    # Several parts may repeat documentation. Keep only identical
                    # bytes; never silently select one conflicting original.
                    with bundle.open(info) as incoming:
                        digest = hashlib.file_digest(incoming, "sha256").hexdigest()
                    if not target.is_file() or sha256(target) != digest:
                        raise ValueError("Conflicting ZIP member: " + name)
                    continue
                with bundle.open(info) as incoming, target.open("xb") as outgoing:
                    shutil.copyfileobj(incoming, outgoing, 1024 * 1024)


def recover(parts, output, manifest_path=DEFAULT_MANIFEST, legacy_script=LEGACY_SCRIPT):
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    manifest_entries(manifest)
    archives = [Path(parts) / name for name in PART_NAMES]
    missing = [p.name for p in archives if not p.is_file() or p.is_symlink()]
    if missing:
        raise ValueError("Missing archive parts: " + ", ".join(missing))
    output = Path(output).resolve()
    if output.exists():
        raise FileExistsError("Refusing to overwrite recovery directory: " + str(output))
    if output.is_relative_to(REPO / "native-godot"):
        raise ValueError("Keep originals outside the Godot resource tree")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".aurora-v3-recovery-", dir=output.parent) as temporary:
        stage = Path(temporary) / "bundle"
        stage.mkdir()
        extract_archives(archives, stage, manifest["total_original_bytes"] * 2 + 64 * 1024 * 1024)
        # Use the reviewed script and manifest from the repository, not executable
        # content extracted from a ZIP. No source archive or original is modified.
        shutil.copyfile(legacy_script, stage / "RECONSTRUIR_AURORA_V3.py")
        (stage / "AURORA_V3_INVENTARIO_80.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        with (stage / "RECONSTRUCTION.log").open("w", encoding="utf-8") as log:
            subprocess.run([sys.executable, str(stage / "RECONSTRUIR_AURORA_V3.py")],
                           check=True, stdout=log, stderr=subprocess.STDOUT)
        records = verify_originals(stage / "originales", manifest)
        report = {"original_count": len(records), "integral_integration_complete": False,
                  "records": records}
        (stage / "RECOVERY_REPORT.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        # Stage is on the same filesystem; the complete, verified bundle becomes
        # visible only after all original hashes have succeeded.
        if output.exists():
            raise FileExistsError("Recovery destination appeared during verification")
        stage.rename(output)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    sub = parser.add_subparsers(dest="command", required=True)
    recovery = sub.add_parser("recover")
    recovery.add_argument("--parts", type=Path, required=True)
    recovery.add_argument("--output", type=Path, required=True)
    verify = sub.add_parser("verify")
    verify.add_argument("--originals", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "recover":
        report = recover(args.parts, args.output, args.manifest)
        print("ORIGINALS_SHA256_VERIFIED", report["original_count"])
        print("GODOT_IMPORT_AND_INTEGRATION_NOT_IMPLIED")
    else:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        records = verify_originals(args.originals, manifest)
        print(json.dumps(records, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
