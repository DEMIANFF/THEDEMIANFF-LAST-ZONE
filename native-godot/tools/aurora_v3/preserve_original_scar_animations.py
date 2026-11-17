#!/usr/bin/env python3
"""Produce an *optional private* animated SCAR GLB from the SHA-verified original.

Unlike the mobile static SCAR mesh exporter, the 4 authored skin animations
and all original rigging stay in this source-faithful derivative. Only FPS hand
and sleeve mesh nodes are detached from the scene graph. Never edit originals.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path

EXPECTED_SOURCE_SHA = 'd32f15d810ce1e0639ff6a833dd03299cc01cc3f4eb55e660293e04b0dc15267'
EXPECTED_DERIVATIVE_SHA = '799289d31fd6d55f64425f28367465e155aed36a0f2f2aae1fa4e22fd99b29e6'
SOURCE_MESH_PARENT = 5
FPS_ARMS_NODES = (129,131)
EXPECTED_CLIPS = ('Akito Rig|Idle','Akito Rig|Reload','Akito Rig|Shoot','Akito Rig|Take')


def build(source: Path, destination: Path) -> dict:
    if source.resolve()==destination.resolve() or destination.exists():
        raise FileExistsError('Refusing to overwrite the original or an existing derivative')
    raw=source.read_bytes()
    source_hash=hashlib.sha256(raw).hexdigest()
    if source_hash != EXPECTED_SOURCE_SHA:
        raise ValueError('Original source does not match 80-file SHA inventory')
    if len(raw)<24 or raw[:4]!=b'glTF':
        raise ValueError('Not GLB 2.0')
    magic,revision,declared_size,json_size,json_type=struct.unpack_from('<4sIIII',raw)
    if revision!=2 or declared_size!=len(raw) or json_type!=0x4E4F534A:
        raise ValueError('Malformed glTF header')
    doc=json.loads(raw[20:20+json_size])
    clips=tuple(a.get('name') for a in doc.get('animations',[]))
    if clips!=EXPECTED_CLIPS or len(doc.get('skins',[])) != 1:
        raise ValueError('Original animation tracks / skeleton changed')
    meshes=[doc['meshes'][i].get('name','') for i in (0,1)]
    if 'Hands' not in meshes[0] or 'Sleeves' not in meshes[1]:
        raise ValueError('FPS mesh identifiers have changed')
    parent=doc['nodes'][SOURCE_MESH_PARENT]
    if any(n not in parent.get('children',[]) for n in FPS_ARMS_NODES):
        raise ValueError('Hands no longer under recorded scene node')
    parent['children']=[n for n in parent['children'] if n not in FPS_ARMS_NODES]
    extras=doc['asset'].get('extras',{})
    if not extras.get('license','').startswith('CC-BY-4.0'):
        raise ValueError('Rights statement changed; manual review required')
    extras.update({
        'aurora_derivative':'Source SCAR animation preserved; FPS hands and sleeve mesh nodes detached from active scene',
        'aurora_source_sha256':source_hash,
    })
    doc['asset']['extras']=extras
    encoded=json.dumps(doc,separators=(',',':')).encode('utf-8')
    encoded+=b' ' * (-len(encoded)%4)
    tail=raw[20+json_size:]
    result=struct.pack('<4sIIII',b'glTF',2,20+len(encoded)+len(tail),len(encoded),0x4E4F534A)+encoded+tail
    actual=hashlib.sha256(result).hexdigest()
    if actual != EXPECTED_DERIVATIVE_SHA:
        raise ValueError('Derivative differs from inspected result; refusing to stage')
    destination.parent.mkdir(parents=True,exist_ok=True)
    with destination.open('xb') as output:
        output.write(result)
    return {'source_sha256':source_hash,'derivative_sha256':actual,'clips':list(clips),
            'skinned_rig_preserved':True,'fps_hands_visible':False,
            'lila_retarget_complete':False,'license_final_review_complete':False}


def main() -> None:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    print(json.dumps(build(args.source,args.output),indent=2))


if __name__=='__main__':main()