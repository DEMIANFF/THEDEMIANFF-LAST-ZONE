#!/usr/bin/env python3
"""SHA-gated local-only import of 4 original-source Aurora protective/medical GLBs."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile

SOURCES = {
    "AuroraFirstAidPrivate.glb": "6fc81a69f24bc43aa4c40e443fb7dd67c920b3292377b1a0720f68f7dca4420b",
    "AuroraHelmetHeadsetPrivate.glb": "9bea49e42fae3eff8cb445753db5571da1ff6f32f4fbca466309e996e9add4a4",
    "AuroraMilitaryBackpackPrivate.glb": "e454e59766e480c7c0321ff92c1c675f3709fc3ebc0da610a17eee285cd923bb",
    "AuroraTacticalCarrierPrivate.glb": "e86ebdf7afe038289b7c10a84e3bf5fe26f6ad1636ea286208025806ce1d5b98",
}
PREFIX = "native-godot/assets/gear/aurora_v3_private/"
MANIFEST_SHA = "1d609fe59e9e4331b9b6f39a38ba269c135f244aeeef2ede080ffaba12544b31"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stage(pack: Path, project: Path, install: bool = False) -> dict:
    root = project.resolve()
    if root.name != 'native-godot' or not (root / 'project.godot').exists():
        raise ValueError('Project must be a native-godot project folder')
    staged = []
    with zipfile.ZipFile(pack) as archive:
        entries = archive.namelist()
        expected = {'GEAR_MANIFEST.json'} | {PREFIX + n for n in SOURCES}
        if len(entries) != len(expected) or set(entries) != expected:
            raise ValueError('Unexpected, missing or duplicate package entries')
        manifest_raw = archive.read('GEAR_MANIFEST.json')
        if sha(manifest_raw) != MANIFEST_SHA:
            raise ValueError('Gear manifest changed')
        manifest = json.loads(manifest_raw)
        if {v['name'] for v in manifest['models']} != set(SOURCES):
            raise ValueError('Gear manifest models differ')
        if manifest['distribution_approved'] is not False:
            raise ValueError('Unsigned rights clearance is not a distribution license')
        if archive.testzip() is not None:
            raise ValueError('ZIP CRC failure')
        for item in manifest['models']:
            name = item['name']; rel = PREFIX + name
            if item['staged_path'] != rel or item['sha256'] != SOURCES[name]:
                raise ValueError('Expected model source hash/path mismatch')
            if item['bytes'] < 2000 or item['bytes'] > 6_000_000:
                raise ValueError('Unexpected or oversized model')
            data = archive.read(rel)
            if len(data) != item['bytes'] or sha(data) != SOURCES[name]:
                raise ValueError('Model bytes do not match audit: ' + name)
            destination = root / rel.removeprefix('native-godot/')
            if destination.is_symlink() or destination.exists() and (
                not destination.is_file() or sha(destination.read_bytes()) != SOURCES[name]
            ):
                raise FileExistsError('Refusing to replace different model: ' + str(destination))
            staged.append((destination, data))
    installed_now = 0
    if install:
        for destination, data in staged:
            if destination.exists():
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=destination.parent,
                                             prefix='.aurora_gear_', delete=False) as file:
                file.write(data)
                temporary = Path(file.name)
            if sha(temporary.read_bytes()) != sha(data):
                temporary.unlink(missing_ok=True)
                raise ValueError('Destination corrupted before atomic rename')
            temporary.replace(destination)
            installed_now += 1
    return {'sources_verified': len(staged), 'installed_now': installed_now,
            'distribution_cleared': False, 'godot_import_qa_complete': False,
            'model_paths': [str(d.relative_to(root)) for d, _ in staged]}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--pack', type=Path, required=True)
    p.add_argument('--project', type=Path, required=True)
    p.add_argument('--install', action='store_true')
    a = p.parse_args()
    print(json.dumps(stage(a.pack, a.project, a.install), indent=2))


if __name__ == '__main__':
    main()