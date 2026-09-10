"""Independently check baked BSP29 light extents, RGB payloads and light levels."""
from pathlib import Path
import hashlib,json,math,struct,statistics
ROOT=Path(__file__).resolve().parents[1]
def check(path):
    raw=path.read_bytes();assert struct.unpack_from('<i',raw)[0]==29
    lumps=[struct.unpack_from('<II',raw,4+i*8) for i in range(15)]
    def lump(i):o,n=lumps[i];return raw[o:o+n]
    light=lump(8);assert light
    at=(max(o+n for o,n in lumps)+3)&~3
    assert raw[at:at+4]==b'BSPX'
    rgb=None
    for i in range(struct.unpack_from('<I',raw,at+4)[0]):
        name,o,n=struct.unpack_from('<24sII',raw,at+8+i*32)
        assert o+n<=len(raw)
        if name.rstrip(b'\0')==b'RGBLIGHTING':rgb=raw[o:o+n]
    assert rgb is not None and len(rgb)==len(light)*3
    verts=list(struct.iter_unpack('<3f',lump(3)));edges=list(struct.iter_unpack('<HH',lump(12)));surf=[x[0] for x in struct.iter_unpack('<i',lump(13))];tex=list(struct.iter_unpack('<8fii',lump(6)))
    checked=0;missing=0
    for plane,side,first,count,ti,styles,offset in struct.iter_unpack('<HHIHH4sI',lump(7)):
        if offset==0xffffffff:missing+=1;continue
        info=tex[ti];uv=[]
        assert styles[0]==0 and styles[1:]==b'\xff\xff\xff','Unexpected animated light style'
        for e in surf[first:first+count]:
            v=verts[edges[abs(e)][0 if e>=0 else 1]]
            uv.append([sum(v[k]*info[k+a] for k in range(3))+info[a+3] for a in (0,4)])
        size=[math.ceil(max(v[a] for v in uv)/16)-math.floor(min(v[a] for v in uv)/16)+1 for a in (0,1)]
        assert offset+size[0]*size[1]<=len(light),(path.name,offset,size)
        checked+=1
    clipping=sum(x==255 for x in light)/len(light)
    assert clipping<.02,(path.name,'Excessive saturated bake',clipping)
    return dict(id=path.stem,sha256=hashlib.sha256(raw).hexdigest(),lit_faces=checked,unlit_sky_faces=missing,luxels=len(light),mean=round(statistics.mean(light),2),saturated_fraction=round(clipping,5),rgb_embedded=True)
if __name__=='__main__':
    rows=[check(p) for p in sorted((ROOT/'optional-arena-pack').glob('*.bsp'))]
    assert len(rows)==40
    (ROOT/'test-results/map-lighting-validation.json').write_text(json.dumps({'maps':rows,'passed':True},indent=2)+'\n')
    print('LIGHTING PASS',len(rows),'maps;',sum(r['lit_faces'] for r in rows),'valid face lightmaps')
