#!/usr/bin/env python3
"""GLB v2 texture-only optimization. Rewrites image bufferViews, never mesh/skin bytes.
Requires Pillow. Validates all original geometry bufferViews remain byte-identical.
This is only a texture budget step, not geometry LOD or Motorola certification.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
from io import BytesIO
import json
import struct
from pathlib import Path
from PIL import Image


def encode(data: bytes, max_dim: int=1024)->bytes:
    with Image.open(BytesIO(data)) as source:
        source.load()
        width,height=source.size
        if max(width,height)<=max_dim:
            return data
        factor=max_dim/max(width,height)
        resized=source.resize((max(1,round(width*factor)),max(1,round(height*factor))),Image.Resampling.LANCZOS)
        if resized.mode=='P':
            resized=resized.convert('RGBA' if 'transparency' in resized.info else 'RGB')
        if resized.mode not in ('RGB','RGBA','L','LA'):
            resized=resized.convert('RGBA')
        stream=BytesIO()
        resized.save(stream,format='PNG',optimize=True,compress_level=6)
        return stream.getvalue()


def glb_read(path: Path):
    blob=path.read_bytes()
    if len(blob)<28 or blob[:4]!=b'glTF' or struct.unpack_from('<I',blob,4)[0]!=2 or struct.unpack_from('<I',blob,8)[0]!=len(blob):
        raise ValueError('Not a valid GLB2 with matching length: '+str(path))
    size,kind=struct.unpack_from('<II',blob,12)
    if kind!=0x4e4f534a:
        raise ValueError('JSON chunk expected')
    doc=json.loads(blob[20:20+size].decode('utf8'))
    pos=20+size
    bsize,btype=struct.unpack_from('<II',blob,pos)
    if btype!=0x004e4942:
        raise ValueError('BIN chunk expected')
    binary=blob[pos+8:pos+8+bsize]
    if pos+8+bsize!=len(blob) or len(doc.get('buffers',[]))!=1:
        raise ValueError('Only one embedded GLB buffer is supported')
    return doc,binary


def repack(input_file: Path,output_file: Path,max_dim: int=1024)->dict:
    if output_file.exists():
        raise FileExistsError(output_file)
    doc,raw=glb_read(input_file)
    old=copy.deepcopy(doc)
    views=doc.get('bufferViews',[])
    images={image['bufferView']:image for image in doc.get('images',[]) if 'bufferView' in image}
    if len(images)!=len(doc.get('images',[])):
        raise ValueError('External/dataURI images unsupported')
    used_elsewhere=set()
    for accessor in doc.get('accessors',[]):
        if 'bufferView' in accessor:used_elsewhere.add(accessor['bufferView'])
        if 'sparse' in accessor:
            for key in ['indices','values']:
                used_elsewhere.add(accessor['sparse'][key]['bufferView'])
    if used_elsewhere.intersection(images):
        raise ValueError('An image bufferView is also used by a geometry accessor')
    new=bytearray()
    reduced=[]
    original_non_images=[]
    for i,view in enumerate(views):
        if view.get('buffer',0)!=0:
            raise ValueError('Multiple buffers not supported')
        begin=view.get('byteOffset',0)
        data=raw[begin:begin+view['byteLength']]
        if len(data)!=view['byteLength']:
            raise ValueError('Bad source bufferView length '+str(i))
        if i in images:
            updated=encode(data,max_dim)
            if len(updated)<len(data):
                reduced.append({'bufferView':i,'before':len(data),'after':len(updated)})
                data=updated
        else:
            original_non_images.append((i,hashlib.sha256(data).hexdigest()))
        while len(new)%4:new.append(0)
        view['byteOffset']=len(new)
        view['byteLength']=len(data)
        new.extend(data)
    doc['buffers'][0]['byteLength']=len(new)
    json_bytes=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf8')
    while len(json_bytes)%4:json_bytes+=b' '
    while len(new)%4:new.append(0)
    total=12+8+len(json_bytes)+8+len(new)
    out=struct.pack('<4sII',b'glTF',2,total)+struct.pack('<II',len(json_bytes),0x4e4f534a)+json_bytes+struct.pack('<II',len(new),0x004e4942)+new
    output_file.parent.mkdir(parents=True,exist_ok=True)
    output_file.write_bytes(out)
    verify_doc,verify_bin=glb_read(output_file)
    for i,sha in original_non_images:
        v=verify_doc['bufferViews'][i]
        data=verify_bin[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
        if hashlib.sha256(data).hexdigest()!=sha:
            output_file.unlink(missing_ok=True)
            raise ValueError('Geometry bufferView changed: '+str(i))
    if old.get('meshes')!=verify_doc.get('meshes') or old.get('nodes')!=verify_doc.get('nodes') or old.get('materials')!=verify_doc.get('materials') or old.get('accessors')!=verify_doc.get('accessors'):
        output_file.unlink(missing_ok=True)
        raise ValueError('Mesh topology/nodes/accessors/materials changed')
    return {'source':input_file.name,'source_sha256':hashlib.sha256(input_file.read_bytes()).hexdigest(),
            'output':output_file.name,'output_sha256':hashlib.sha256(out).hexdigest(),
            'bytes_before':input_file.stat().st_size,'bytes_after':output_file.stat().st_size,
            'geometry_bufferViews_unchanged':len(original_non_images),
            'meshes_unchanged':len(doc.get('meshes',[])),'images_reduced':reduced,
            'suspension_verified':False,'poly_lod_completed':False,'motorola_verified':False}


def main()->None:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--max-dimension',type=int,default=1024)
    a=p.parse_args()
    if a.max_dimension not in (512,1024,2048):
        p.error('Supported texture ceilings: 512, 1024, 2048')
    print(json.dumps(repack(a.input,a.output,a.max_dimension),indent=2))

if __name__=='__main__':
    main()