#!/usr/bin/env python3
"""Integrity-gated optional local install of Aurora V2 armory GLBs.

Does not publish assets, change source/player data, or clear licensing.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile

STAGED = {
    "HK416": ("native-godot/assets/weapons/aurora_v2_optional/aurora_hk416.glb",
              "dae024ca21a784553c3c588f67c9c6dc64f0ef2309b2a1d9a81b59bbc09c237d"),
    "P90": ("native-godot/assets/weapons/aurora_v2_optional/aurora_p90.glb",
            "0560b555ce3c01014d9fb689b93bd48cf2a600b2a66b844ec8db94f29406308c"),
    "VSS": ("native-godot/assets/weapons/aurora_v2_optional/aurora_vss.glb",
            "57decf52b1ed0c661786c13192a414f2e9b5ef59b72a6976f94e210080578576"),
}


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def prepare(archive: Path, project_root: Path, install: bool = False,
            models: tuple[str, ...] | None = None) -> dict:
    # Always verify the entire archive, even for a selective installation.
    # The public P90 has a newer derivative than this private pack.
    selected = set(STAGED) if models is None else set(models)
    if not selected or not selected.issubset(STAGED):
        raise ValueError("Unknown or empty model selection")
    project_root = project_root.resolve()
    if project_root.name != "native-godot" or not (project_root / "project.godot").is_file():
        raise ValueError("Project must be native-godot with project.godot")
    allowed = {value[0] for value in STAGED.values()}
    with zipfile.ZipFile(archive) as bundle:
        present = set(bundle.namelist())
        if not allowed.issubset(present):
            raise ValueError("Incomplete staging pack: " + repr(sorted(allowed - present)))
        if len(present) != len(bundle.infolist()):
            raise ValueError("Duplicate ZIP entries")
        if present - allowed - {"PRIVATE_ARMORY_MANIFEST.json", "README_ES.txt"}:
            raise ValueError("Unexpected ZIP member")
        manifest = json.loads(bundle.read("PRIVATE_ARMORY_MANIFEST.json"))
        rows = manifest.get("models", [])
        if len(rows) != len(STAGED) or {row["name"] for row in rows} != set(STAGED):
            raise ValueError("Unexpected manifest models")
        candidates = []
        for row in manifest["models"]:
            name = row["name"]
            rel, expected = STAGED[name]
            if row["staged_path"] != rel or row["sha256"] != expected:
                raise ValueError("Model path or SHA changed: " + name)
            info = bundle.getinfo(rel)
            if info.file_size > 12_000_000 or info.file_size <= 1000:
                raise ValueError("Unsupported model size: " + name)
            with bundle.open(info) as stream:
                data = stream.read(info.file_size + 1)
            if len(data) != info.file_size or sha_bytes(data) != expected:
                raise ValueError("Model SHA mismatch: " + name)
            if name not in selected:
                continue
            dest = project_root / rel.removeprefix("native-godot/")
            if not dest.resolve().is_relative_to(project_root):
                raise ValueError("Unsafe destination")
            if dest.is_symlink() or dest.exists() and dest.is_file() and sha_bytes(dest.read_bytes()) != expected:
                raise FileExistsError("Refusing to overwrite a different GLB: " + str(dest))
            if dest.exists() and not dest.is_file():
                raise ValueError("Non-file destination")
            candidates.append((name, dest, data))
    if install:
        for name, dest, data in candidates:
            if dest.exists():
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile("wb", dir=dest.parent, prefix=".staging-", delete=False) as tmp:
                tmp.write(data)
                temp_path = Path(tmp.name)
            if sha_bytes(temp_path.read_bytes()) != STAGED[name][1]:
                temp_path.unlink(missing_ok=True)
                raise ValueError("Staged copy corrupted: " + name)
            temp_path.replace(dest)
    return {"models": len(candidates), "archive_models_verified": len(STAGED),
            "selected": sorted(selected), "excluded": sorted(set(STAGED) - selected),
            "checked": True, "installed": install,
            "paths": [str(dest.relative_to(project_root)) for _, dest, _ in candidates],
            "physical_qa_complete": False, "distribution_rights_approved": False}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--models", choices=sorted(STAGED), nargs="+",
                        help="Select models without replacing unselected assets")
    args = parser.parse_args()
    print(json.dumps(prepare(args.pack, args.project, args.install,
                             tuple(args.models) if args.models else None), indent=2))


if __name__ == "__main__":
    main()
