"""Apply shared replacements to BSP29/BSP2 textures. Missing-only by default; CC0 tool.

--replace-known explicitly retextures known embedded assets for a licensed/local conversion.
Unknown embedded assets stay byte-for-byte unchanged. Never grants map redistribution rights.
"""
from pathlib import Path
import argparse, hashlib, json, struct
ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'deathmatch/maps/texture_replacements'
def convert(raw, replace_known=False, use_lightmaps=False):
    assert 124<=len(raw)<=25_000_000 and raw[:4] in [struct.pack('<i',29),b'BSP2',b'2PSB']
    manifest=json.loads((PACK/'manifest.json').read_text()); entries=manifest['textures']; pack=(PACK/'replacement-miptex.lmp').read_bytes()
    lumps=[struct.unpack_from('<II',raw,4+8*i) for i in range(15)];assert all(o+n<=len(raw) for o,n in lumps)
    offset,length=lumps[2];count=struct.unpack_from('<I',raw,offset)[0];assert count<=2048 and 4+4*count<=length
    table=bytearray(struct.pack('<I',count)+bytes(4*count));report=[]
    for i in range(count):
        relative=struct.unpack_from('<i',raw,offset+4+4*i)[0]
        if relative==-1:
            struct.pack_into('<i',table,4+4*i,-1);report.append({'slot':i,'status':'unnamed; runtime neutral fallback'});continue
        assert relative>=4+4*count and relative+40<=length
        at=offset+relative;name=raw[at:at+16].split(b'\0')[0].decode('ascii').lower();w,h=struct.unpack_from('<II',raw,at+16)
        assert 0<w<=2048 and 0<h<=2048
        starts=struct.unpack_from('<4I',raw,at+24);embedded=starts[0]>0
        known=name in entries
        replace=(not embedded) or (replace_known and known)
        tile=bytearray(raw[at:at+40]);tile[24:40]=bytes(16)
        for mip in range(4):
            width,height=max(1,w>>mip),max(1,h>>mip)
            if replace:
                row=entries[name if known else '_fallback'];sw,sh=max(1,row['width']>>mip),max(1,row['height']>>mip)
                src=row['offset']+struct.unpack_from('<I',pack,row['offset']+24+4*mip)[0]
                pixels=bytes(pack[src+(y*sh//height)*sw+x*sw//width] for y in range(height) for x in range(width))
            elif starts[mip]:
                assert starts[mip]>=40 and relative+starts[mip]+width*height<=length
                pixels=raw[at+starts[mip]:at+starts[mip]+width*height]
            else:continue
            struct.pack_into('<I',tile,24+4*mip,len(tile));tile.extend(pixels)
        struct.pack_into('<I',table,4+4*i,len(table));table.extend(tile)
        report.append({'name':name,'status':'named replacement' if replace and known else 'neutral fallback' if replace else 'embedded preserved','width':w,'height':h})
    # Repack rather than leaving original copyrighted texture bytes in dead lumps.
    result=bytearray(raw[:124]);delta={}
    for i,(at,size) in enumerate(lumps):
        while len(result)%4:result.append(0)
        data=table if i==2 else raw[at:at+size]
        if i==0 and use_lightmaps:
            import re
            world,rest=data.split(b'}',1)
            world=re.sub(rb'"_fpsloppa_(?:bake|atlas)"\s*"[^"]*"',b'',world)
            data=world+b'"_fpsloppa_bake" "1"\n"_fpsloppa_atlas" "4096"\n}'+rest
        delta[i]=len(result)-at
        struct.pack_into('<II',result,4+8*i,len(result),len(data));result.extend(data)
    end=(max(o+n for o,n in lumps)+3)&~3
    if raw[end:end+4]==b'BSPX':
        n=struct.unpack_from('<I',raw,end+4)[0];assert n<=64
        while len(result)%4:result.append(0)
        header=len(result);result.extend(b'BSPX'+struct.pack('<I',n)+bytes(n*32))
        for i in range(n):
            name,at,size=struct.unpack_from('<24sII',raw,end+8+32*i);assert at+size<=len(raw)
            while len(result)%4:result.append(0)
            struct.pack_into('<24sII',result,header+8+32*i,name,len(result),size);result.extend(raw[at:at+size])
    assert len(result)<=25_000_000
    return bytes(result),{'dictionary_version':manifest['version'],'source_sha256':hashlib.sha256(raw).hexdigest(),'sha256':hashlib.sha256(result).hexdigest(),'textures':report,'geometry_lighting_unchanged':True,'world_lightmap_opt_in':use_lightmaps}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('output',type=Path);p.add_argument('--replace-known',action='store_true');p.add_argument('--use-lightmaps',action='store_true',help='Opt local conversion into rendering its embedded Quake lightmaps');a=p.parse_args()
    if a.source.resolve()==a.output.resolve():raise SystemExit('Use a separate output; original maps are preserved.')
    data,report=convert(a.source.read_bytes(),a.replace_known,a.use_lightmaps);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(data)
    a.output.with_suffix('.textures.json').write_text(json.dumps(report,indent=2)+'\n');print(a.output)
