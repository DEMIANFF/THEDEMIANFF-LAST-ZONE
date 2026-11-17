#!/usr/bin/env python3
"""Stage user-provided Aurora asset derivatives into a LOCAL Godot checkout.

Only known manifest SHA-256 and exact asset roots are accepted. No source-asset
redistribution, APK, keystore, Firebase or remote modifications occur here.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile
from zipfile import ZipFile

# Immutable manifest from the 21-file private staging pack prepared 16 Nov 2026.
PINNED_MANIFEST_SHA256 = "6cba0b04d9aea0d2cea396b5c5f21033dcc2056e90b315ddc56b62e453c7f711"
EXACT_STAGING_ROOTS = (
    "native-godot/assets/weapons/aurora_v2_optional/",
    "native-godot/assets/weapons/aurora_v3_sources/",
    "native-godot/assets/vehicles/user_pack/",
    "native-godot/assets/audio/aurora_v3_addendum/",
)
EXPECTED_COUNTS = {".glb": 5, ".ogg": 10, ".wav": 6}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inspect(pack: Path) -> dict[str, bytes]:
    """Validate complete snapshot before any local installation side effect."""
    result = {}
    with ZipFile(pack) as z:
        names = z.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP entries")
        manifest_bytes = z.read("STAGING_SHA256_MANIFEST.json")
        if sha256(manifest_bytes) != PINNED_MANIFEST_SHA256:
            raise ValueError("Unknown or modified private manifest")
        manifest = json.loads(manifest_bytes)
        expected = manifest["runtime_paths"]
        if len(expected) != 21:
            raise ValueError("Expected 21 assets")
        others = set(names) - set(expected) - {
            "STAGING_SHA256_MANIFEST.json", "LEEME_PRIVADO.txt", "SCAR_SOURCE_ANIMATION_NOTES.txt"}
        if others or set(expected) - set(names):
            raise ValueError(f"Unexpected or missing entries: {others} {set(expected)-set(names)}")
        counts = {ext: 0 for ext in EXPECTED_COUNTS}
        for name, meta in expected.items():
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts or not name.startswith(EXACT_STAGING_ROOTS):
                raise ValueError("Unsafe asset path: " + name)
            extension = path.suffix.lower()
            if extension not in counts:
                raise ValueError("Unexpected asset type: " + name)
            counts[extension] += 1
            info = z.getinfo(name)
            if info.is_dir() or info.file_size < 16 or info.file_size > 16_800_000:
                raise ValueError("Unexpected asset size: " + name)
            payload = z.read(name)
            if len(payload) != int(meta["bytes"]) or sha256(payload) != meta["sha256"]:
                raise ValueError("Corrupted asset: " + name)
            if extension == ".glb":
                if payload[:4] != b"glTF" or int.from_bytes(payload[4:8], "little") != 2 or int.from_bytes(payload[8:12], "little") != len(payload):
                    raise ValueError("Invalid GLB v2: " + name)
            elif extension == ".ogg" and payload[:4] != b"OggS":
                raise ValueError("Invalid OGG: " + name)
            elif extension == ".wav" and not (payload[:4] == b"RIFF" and payload[8:12] == b"WAVE"):
                raise ValueError("Invalid WAV: " + name)
            result[name] = payload
        if counts != EXPECTED_COUNTS:
            raise ValueError(f"Unexpected asset type counts: {counts}")
    return result


def stage(pack: Path, project: Path, install: bool) -> dict:
    project = project.resolve()
    if project.name != "native-godot" or not (project / "project.godot").is_file():
        raise ValueError("Select existing native-godot/ directory with project.godot")
    payloads = inspect(pack)
    targets = []
    for name, payload in payloads.items():
        relative = name.removeprefix("native-godot/")
        destination = project / relative
        if not destination.resolve().is_relative_to(project):
            raise ValueError("Destination outside project")
        if destination.is_symlink() or (destination.exists() and not destination.is_file()):
            raise ValueError("Unsafe existing target: " + str(destination))
        if destination.exists() and sha256(destination.read_bytes()) != sha256(payload):
            raise FileExistsError("Refusing to overwrite altered resource: " + str(destination))
        targets.append((destination, payload))
    if install:
        for target, payload in targets:
            if target.exists():
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(mode="wb", dir=target.parent, delete=False) as tmp:
                tmp.write(payload)
                staged = Path(tmp.name)
            try:
                if sha256(staged.read_bytes()) != sha256(payload):
                    raise ValueError("Staging integrity mismatch")
                staged.replace(target)
            finally:
                staged.unlink(missing_ok=True)
    return {"validated": len(targets), "installed": bool(install),
            "optional_weapon_models": 3, "animated_source_scar": True,
            "c17_source_model": True, "audio_samples": 16,
            "release_rights_approved": False, "motorola_tested": False,
            "next_qa": "bash native-godot/tools/run_qa.sh (with Godot 4.7.2 in PATH)"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--install", action="store_true",
                        help="Actually place assets after validating the complete snapshot")
    args = parser.parse_args()
    print(json.dumps(stage(args.pack, args.project, args.install), indent=2))


if __name__ == "__main__":
    main()