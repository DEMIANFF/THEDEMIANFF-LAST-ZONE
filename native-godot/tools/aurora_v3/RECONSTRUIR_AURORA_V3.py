#!/usr/bin/env python3
"""Reconstruct files split across AURORA_V3_ASSETS_*.zip archives.
Usage: extract all archives into the same directory; python RECONSTRUIR_AURORA_V3.py
"""
from pathlib import Path
import json, hashlib,sys
root=Path(__file__).resolve().parent
manifest=json.loads((root/'AURORA_V3_INVENTARIO_80.json').read_text(encoding='utf-8'))
for item in manifest['files']:
    filename=item['name']
    dst=root/'originales'/filename
    if not dst.exists():
        parts=sorted((root/'fragmentos').glob(filename+'.parte*'))
        if not parts:raise SystemExit('Falta archivo o fragmentos: '+filename)
        dst.parent.mkdir(parents=True,exist_ok=True)
        with dst.open('wb') as out:
            for part in parts:
                with part.open('rb') as f:
                    while True:
                        buf=f.read(8*1024*1024)
                        if not buf:break
                        out.write(buf)
    with dst.open('rb') as f:
        digest=hashlib.file_digest(f,'sha256').hexdigest()
    if digest != item['sha256']:raise SystemExit('HASH NO COINCIDE: '+filename)
    print('OK',filename)
print('VERIFICADOS TODOS:',len(manifest['files']))
