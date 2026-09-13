"""Fetch hash-pinned original WAD archives; optionally assemble an editor WAD."""
from pathlib import Path
import argparse
import json
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from makkon.theme import makkon, sha


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--editor-wad',action='store_true')
    args=parser.parse_args()
    local=Path(__file__).with_name('local');local.mkdir(exist_ok=True)
    inventory=json.loads(Path(__file__).with_name('inventory.json').read_text())
    for pack in inventory['packs']:
        target=local/pack['archive']
        if not target.exists():
            part=target.with_suffix('.zip.part')
            subprocess.run(['curl','-fL','--retry','2',pack['download'],'-o',str(part)],check=True)
            assert sha(part.read_bytes())==pack['sha256'],'Archive hash mismatch'
            part.replace(target)
        assert sha(target.read_bytes())==pack['sha256'],'Archive hash mismatch'
        print('VERIFIED',target.name,flush=True)
    if args.editor_wad:
        textures,sources=makkon()
        selected=set()
        for path in [ROOT/'maps/HiSlop/texture-sources.json',ROOT/'maps/Frigate/texture-sources.json',*(ROOT/'maps/Community').glob('*/texture-sources.json')]:
            for key,source in json.loads(path.read_text()).items():
                if source.get('author')=='Ben "Makkon" Hale':selected.add(key)
        # The shared builder includes actual map usage and active aliases only.
        from makkon.build_shared import build
        proof=build()
        selected=set(proof['textures'])
        wad=bytearray(b'WAD2'+bytes(8));directory=[]
        for key in sorted(selected):
            raw=textures[key];at=len(wad);wad.extend(raw)
            directory.append(struct.pack('<iiiBBH16s',at,len(raw),len(raw),68,0,0,key.encode()))
        at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
        (local/'FPSloppa-Makkon.wad').write_bytes(wad)
        assert sha(wad)==proof['sha256']
        print('EDITOR_WAD',len(selected),'original textures',len(wad),'bytes')


if __name__=='__main__':main()
