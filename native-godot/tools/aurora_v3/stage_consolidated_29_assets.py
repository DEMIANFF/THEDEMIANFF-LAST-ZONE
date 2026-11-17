#!/usr/bin/env python3
"""Verify and optionally stage the 29 user-supplied PREVIEW assets into a local Godot checkout.

Does not grant distribution rights, retarget rigs, generate an APK, or edit user:// data.
"""
from __future__ import annotations
import argparse, hashlib, json, os, tempfile, zipfile
from pathlib import Path

MANIFEST_SHA256 = "15daa974e8e956fa0f9e2c447ed245759f889d9669d87ea3bba683b1afd35bbf"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stage(pack: Path, project: Path, *, install: bool=False) -> dict:
    root=project.resolve(strict=True)
    if root.name != 'native-godot' or not (root/'project.godot').is_file():
        raise ValueError('Expected native-godot directory containing project.godot')
    with zipfile.ZipFile(pack) as z:
        entries=z.namelist()
        if len(entries)!=len(set(entries)):
            raise ValueError('Duplicate ZIP members')
        blob=z.read('MANIFEST_29.json')
        if digest(blob)!=MANIFEST_SHA256:
            raise ValueError('Invalid canonical manifest SHA-256')
        manifest=json.loads(blob)
        rows=manifest['assets']
        if manifest['asset_count']!=29 or len(rows)!=29:
            raise ValueError('Incorrect count')
        permitted={r['path'] for r in rows}
        if set(entries)!=permitted|{'MANIFEST_29.json','LEEME.txt'}:
            raise ValueError('Unexpected or missing ZIP members')
        results=[]
        for item in rows:
            path=item['path']
            if not path.startswith('native-godot/assets/'):
                raise ValueError('Not a game asset path')
            sub=Path(path[len('native-godot/'):])
            if any(part in ('..','.','') for part in sub.parts):
                raise ValueError('Unsafe path')
            dest=root/sub
            # Never follow symlinked destination directories to external storage.
            parent=dest.parent
            while parent != root:
                if parent.is_symlink():
                    raise ValueError('Symlinked destination ancestor: '+str(parent))
                parent=parent.parent
            if dest.is_symlink():
                raise ValueError('Symlink destination: '+str(dest))
            size=z.getinfo(path).file_size
            if size!=item['size'] or size>60_000_000:
                raise ValueError('Size bound failed: '+path)
            data=z.read(path)
            if len(data)!=size or digest(data)!=item['sha256']:
                raise ValueError('Source data checksum failed: '+path)
            if dest.exists() and (not dest.is_file() or digest(dest.read_bytes())!=item['sha256']):
                raise FileExistsError('Refusing overwrite: '+str(dest))
            results.append((dest,data,path))
    installed=0
    if install:
        for dest,data,path in results:
            if dest.is_file():
                continue
            dest.parent.mkdir(parents=True,exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=dest.parent,prefix='.aurora-verify-',delete=False) as handle:
                handle.write(data)
                temporary=Path(handle.name)
            try:
                if digest(temporary.read_bytes())!=digest(data):
                    raise IOError('Stage verification failed for '+path)
                os.replace(temporary,dest)
                installed+=1
            finally:
                temporary.unlink(missing_ok=True)
    return {'verified':len(results),'installed_now':installed,'install_requested':install,
            'rights_approved':False,'godot_visual_qa_completed':False,
            'android_qa_completed':False,'test_mode_only':True}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack',required=True,type=Path)
    parser.add_argument('--project',required=True,type=Path)
    parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    print(json.dumps(stage(args.pack,args.project,install=args.install),indent=2))


if __name__=='__main__':
    main()