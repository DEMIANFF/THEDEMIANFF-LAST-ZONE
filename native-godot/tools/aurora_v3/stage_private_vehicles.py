#!/usr/bin/env python3
"""Integrity-gated local staging of two actual author-attributed Aurora car GLBs.
No files are published or overwritten; a license check still precedes distribution.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile

EXPECTED={
  'native-godot/assets/vehicles/aurora_v3_private/AuroraToyotaOriginal.glb':
    ('7b3d2dfd5002c9beb167c35bb537452dae8e7936f205c24e594071163eef2ad0',51878376),
  'native-godot/assets/vehicles/aurora_v3_private/AuroraBMWOriginal.glb':
    ('751c816b8ec140120a5a9a498db606a760cde8bdf3f2e98ff83781a6b6bd23ea',21945796),
}

def main() -> None:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--pack',type=Path,required=True)
    p.add_argument('--project',type=Path,required=True)
    p.add_argument('--install',action='store_true')
    a=p.parse_args()
    project=a.project.resolve()
    if project.name!='native-godot' or not (project/'project.godot').is_file():
        p.error('Expected a native-godot project with project.godot')
    validated=[]
    with zipfile.ZipFile(a.pack) as z:
        names=z.namelist()
        if len(names)!=len(set(names)) or set(names)!=set(EXPECTED)|{'AURORA_VEHICLES_PRIVATE_MANIFEST.json'}:
            raise ValueError('Missing or unexpected ZIP paths / duplicate member')
        meta=json.loads(z.read('AURORA_VEHICLES_PRIVATE_MANIFEST.json'))
        if {x['path'] for x in meta.get('models',[])}!=set(EXPECTED):
            raise ValueError('Manifest paths mismatch')
        for name,(sha,size) in EXPECTED.items():
            if z.getinfo(name).file_size!=size:
                raise ValueError('Untrusted size '+name)
            blob=z.read(name)
            if hashlib.sha256(blob).hexdigest()!=sha:
                raise ValueError('Untrusted SHA-256 '+name)
            target=project/name.removeprefix('native-godot/')
            if not target.resolve().is_relative_to(project) or target.is_symlink():
                raise ValueError('Unsafe destination '+str(target))
            if target.exists() and (not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest()!=sha):
                raise FileExistsError('Refusing to replace a different GLB '+str(target))
            validated.append((target,blob,sha))
    created=[]
    if a.install:
        for target,data,sha in validated:
            if target.exists():
                continue
            target.parent.mkdir(parents=True,exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=target.parent,delete=False,prefix='.vehicle-stage-',mode='wb') as fp:
                fp.write(data)
                temporary=Path(fp.name)
            if hashlib.sha256(temporary.read_bytes()).hexdigest()!=sha:
                temporary.unlink(missing_ok=True)
                raise ValueError('Staging altered car bytes')
            temporary.replace(target)
            created.append(target)
    print(json.dumps({'verified_count':len(validated),'newly_installed':len(created),
      'physical_godot_qa':False,'motorola_verified':False,'licensing_approved':False},indent=2))

if __name__=='__main__':
    main()