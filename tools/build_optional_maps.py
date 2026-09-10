"""Build the optional pack from LibreQuake v0.09-beta full.zip and dev.zip.
Usage: python3 tools/build_optional_maps.py FULL_EXTRACTED/id1 DEV_EXTRACTED
Every embedded mip is replaced by its named LibreQuake WAD asset. All BSP
lump offsets and BSPX collision extensions are preserved byte-for-byte.
"""
from pathlib import Path
import struct, hashlib, json, shutil, sys, re, zipfile
ROOT=Path(__file__).resolve().parents[1]
def digest(data): return hashlib.sha256(data).hexdigest()
def build(full,dev):
    out=ROOT/'optional-map-pack';out.mkdir(exist_ok=True)
    (out/'.gdignore').write_text('')
    wads={}
    for p in sorted((dev/'texture-wads').glob('*.wad')):
        d=p.read_bytes();n,off=struct.unpack_from('<ii',d,4)
        for i in range(n):
            at,size,_,kind,comp,_,rawname=struct.unpack_from('<iiiBBH16s',d,off+i*32)
            if kind==68 and not comp:wads[rawname.split(b'\0')[0].decode().lower()]=(d[at:at+size],p.name)
    rows=[]
    for number in range(9,14):
        name=f'lqdm{number}';original=(full/'maps'/f'{name}.bsp').read_bytes();d=bytearray(original)
        assert struct.unpack_from('<i',d)[0]==29
        at,length=struct.unpack_from('<ii',d,20);count=struct.unpack_from('<i',d,at)[0];textures=[]
        for index in range(count):
            rel=struct.unpack_from('<i',d,at+4+index*4)[0];assert rel>=0,'External texture forbidden'
            base=at+rel;tex=d[base:base+16].split(b'\0')[0].decode().lower();raw,wad=wads[tex]
            width,height=struct.unpack_from('<II',d,base+16);assert (width,height)==struct.unpack_from('<II',raw,16)
            for mip in range(4):
                start=struct.unpack_from('<I',d,base+24+4*mip)[0];source=struct.unpack_from('<I',raw,24+4*mip)[0];size=max(1,width>>mip)*max(1,height>>mip)
                assert start>=40 and rel+start+size<=length and source>=40 and source+size<=len(raw)
                d[base+start:base+start+size]=raw[source:source+size]
            textures.append({'name':tex,'wad':wad,'source_sha256':digest(raw),'width':width,'height':height})
        offset,size=struct.unpack_from('<ii',d,4);entities=[dict(re.findall(r'"([^"\n]+)"\s*"([^"\n]*)"',block)) for block in re.findall(r'\{([^}]+)\}',d[offset:offset+size].decode())]
        world=entities[0];spawns=sum(e.get('classname')=='info_player_deathmatch' and not int(e.get('spawnflags','0'))&2048 for e in entities)
        assert spawns>=2
        (out/f'{name}.bsp').write_bytes(d)
        # Retain matching colored lighting alongside the BSP for compatible engines.
        lit=full/'maps'/f'{name}.lit'
        if lit.exists():shutil.copy2(lit,out/lit.name)
        warnings=[]
        classes=sorted({e.get('classname','') for e in entities})
        if 'func_door' in classes:warnings.append('Doors use FPSloppa proximity activation; Quake key, shooting and relay puzzles are not required.')
        if any(c in classes for c in ['trigger_relay','trigger_counter','trigger_once']):warnings.append('Quake progression triggers are inert in arena play; teleport/push/hurt volumes remain active.')
        warnings.append('Quake powerups are mapped to existing arena health pickups; IG and CC suppress all pickups.')
        row={'id':name,'title':world.get('message',name),'author':world.get('_credits','LibreQuake contributors'),'spawns':spawns,'sha256':digest(d),'upstream_sha256':digest(original),'textures':textures,'entity_classes':classes,'adaptations':warnings}
        rows.append(row)
        (out/f'{name}-README.txt').write_text(f'{row["title"]} ({name})\nAuthor: {row["author"]}\nSource: LibreQuake v0.09-beta, full.zip maps/{name}.bsp\nhttps://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta\nLicense: BSD-3-Clause; see COPYING and CREDITS.\nFPSloppa modification: all four texture mips replaced from the same release\'s LibreQuake WADs, including liquid textures. Geometry and BSPX unchanged.\n\n'+ '\n'.join(warnings)+'\n')
    for name in ['COPYING','CREDITS','README-IMPORTANT-LICENCE-INFO','README.md','deathmatch-setup-guide.txt']:
        shutil.copy2(full/'docs'/name,out/('UPSTREAM-README.md' if name=='README.md' else name))
    manifest={'source':'https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta','license':'BSD-3-Clause','maps':rows}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('BUILT',[(r['id'],r['title'],r['spawns'],len(r['textures'])) for r in rows])
if __name__=='__main__':build(Path(sys.argv[1]),Path(sys.argv[2]))
