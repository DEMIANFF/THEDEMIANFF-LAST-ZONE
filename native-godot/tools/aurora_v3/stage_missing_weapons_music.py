#!/usr/bin/env python3
"""Stage the SIX user-provided model/music derivatives locally and verify SHA.
Never publishes third-party data or alters Firebase, keys, account or user saves.
This is a binary import test, NOT a certificate of gameplay or redistribution.
"""
from pathlib import Path
import argparse,hashlib,json,tempfile,zipfile

MANIFEST_SHA256 = '42c578e86e6b3f16d8b2053cd06a65a8ee0d3893e3c90df11e655fcb9a3e3d5d'  # verify after writing


def digest(b):return hashlib.sha256(b).hexdigest()


def stage(archive,project,install=False):
    root=Path(project).resolve()
    if root.name!='native-godot' or not (root/'project.godot').is_file():raise ValueError('Project is not native-godot')
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:raise ValueError('Corrupt zip CRC')
        names=z.namelist()
        if len(names)!=len(set(names)):raise ValueError('Duplicate zip entry')
        mb=z.read('PRIVATE_STAGE_MANIFEST.json')
        # The per-file content hashes are checked below; pinning manifest defends against remapping destinations.
        if digest(mb)!=MANIFEST_SHA256:raise ValueError('Unrecognized private manifest')
        manifest=json.loads(mb)
        if manifest['format']!='aurora_v3_private_expansion_v1' or len(manifest['entries'])!=6:raise ValueError('Unexpected private manifest')
        expected={e['path'] for e in manifest['entries']}|{'PRIVATE_STAGE_MANIFEST.json','README_ES.txt'}
        if set(names)!=expected:raise ValueError('Unexpected ZIP contents')
        staged=[]
        for entry in manifest['entries']:
            rel=entry['path']
            if not rel.startswith('native-godot/assets/') or ('..' in Path(rel).parts):raise ValueError('Invalid destination')
            dest=root/rel.removeprefix('native-godot/')
            if not dest.resolve().is_relative_to(root) or dest.is_symlink():raise ValueError('Unexpected local destination')
            info=z.getinfo(rel)
            if info.file_size!=entry['bytes'] or info.file_size>15_000_000:raise ValueError('Invalid size')
            source=z.read(rel)
            if digest(source)!=entry['sha256']:raise ValueError('SHA mismatch '+rel)
            if dest.exists():
                if not dest.is_file() or digest(dest.read_bytes())!=entry['sha256']:
                    raise FileExistsError('Refusing to overwrite '+str(dest))
            staged.append((dest,source))
    if install:
        for dest,source in staged:
            if dest.is_file():continue
            dest.parent.mkdir(parents=True,exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=dest.parent,prefix='.aurora-',delete=False) as fp:
                fp.write(source);temp=Path(fp.name)
            if digest(temp.read_bytes())!=digest(source):
                temp.unlink(missing_ok=True);raise ValueError('Failed staged copy verification')
            temp.replace(dest)
    return {'source_files_sha256_verified':6,'installed':install,'scene_import_tested':False,
            'motorola_tested':False,'rights_cleared':False}


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--pack',type=Path,required=True)
    ap.add_argument('--project',type=Path,required=True)
    ap.add_argument('--install',action='store_true')
    a=ap.parse_args();print(json.dumps(stage(a.pack,a.project,a.install),indent=2))