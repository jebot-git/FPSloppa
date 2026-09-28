"""Embed authored convex solids/materials in a BSPX lump for bounded wall traces.

No reference BSP geometry is imported. Planes come from the same editable MAP
brushes as collision. Unknown roles and sky seal the trace; liquids do not.
"""
import json
import re
import struct
from pathlib import Path

import numpy as np

POINT = re.compile(r'\( ([^()]+) \)')
LUMP = 'FSLP_BALLISTICS'
ROLES = {
    'd2_crate':'wood', 'crate':'wood', 'd2_door':'wood', 'wood':'wood',
    'd2_iron':'metal', 'metal':'metal', 'vent':'vent', 'tank':'metal',
    'wagon':'metal', 'wagon2':'metal', 'glass':'glass', 'de_glass':'glass', 'window':'glass',
    'wall':'concrete', 'floor':'concrete', 'trim':'concrete',
    'd2_stone':'concrete', 'd2_floor':'concrete', 'd2_trim':'concrete',
    'd2_rock':'concrete', 'rock':'concrete', 'carved':'concrete', 'moss':'concrete',
    'roof':'wood', 'rope':'wood', 'mark':'concrete', 'd2_red':'concrete',
    'd2_signa':'concrete', 'd2_signb':'concrete',
}

def convert(p):
    x,y,z=p
    return np.array([-y,z,-x])/32

def solid(brush):
    faces=[];points=[];materials=[]
    for line in brush.splitlines():
        triplet=POINT.findall(line)
        if len(triplet)!=3:continue
        vs=np.array([convert(list(map(float,p.split()))) for p in triplet])
        points.extend(vs);faces.append(vs)
        texture=line.split(')')[-1].split()[0]
        if texture.startswith('*') or texture=='trigger':return None
        materials.append(ROLES.get(texture,'stop'))
    if not faces:return None
    center=np.mean(points,axis=0);planes=[]
    for vs in faces:
        n=np.cross(vs[1]-vs[0],vs[2]-vs[0]);length=np.linalg.norm(n)
        if length<1e-9:raise ValueError('degenerate brush plane')
        n/=length;distance=n@vs[0]
        if n@center>distance:n=-n;distance=-distance
        planes.append([*n,distance])
    lo=np.min(points,axis=0);hi=np.max(points,axis=0)
    return [np.round(lo,7).tolist(),np.round(hi,7).tolist(),
            np.round(planes,7).tolist(),materials]

def tree(brushes):
    nodes=[]
    def build(ids):
        index=len(nodes);nodes.append(None)
        lo=np.min([brushes[i][0] for i in ids],axis=0)
        hi=np.max([brushes[i][1] for i in ids],axis=0)
        if len(ids)<=6:children=ids
        else:
            axis=int(np.argmax(hi-lo));ids.sort(key=lambda i:brushes[i][0][axis]+brushes[i][1][axis])
            mid=len(ids)//2;children=[build(ids[:mid]),build(ids[mid:])]
        nodes[index]=[lo.tolist(),hi.tolist(),len(ids)<=6,children]
        return index
    if brushes:build(list(range(len(brushes))))
    return nodes

def capture(a):
    brushes=[s for b in a.brushes+getattr(a,'detail_brushes',[]) if (s:=solid(b))]
    movers=[]
    for attrs,parts in getattr(a,'models',[]):
        if attrs['classname'] not in ['func_door','func_wall']:continue
        solids=[s for b in parts if (s:=solid(b))]
        movers.append({'name':attrs.get('_fps_id',attrs['targetname']),'brushes':solids})
    return {'version':1,'static':brushes,'tree':tree(brushes),'movers':movers}

def embed(path,data):
    path=Path(path);raw=path.read_bytes()
    lumps=[struct.unpack_from('<ii',raw,4+8*i) for i in range(15)]
    end=(max(o+n for o,n in lumps)+3)&~3
    records={}
    if raw[end:end+4]==b'BSPX':
        count=struct.unpack_from('<I',raw,end+4)[0]
        for i in range(count):
            name,offset,length=struct.unpack_from('<24sII',raw,end+8+32*i)
            records[name.split(b'\0')[0].decode()]=raw[offset:offset+length]
    records[LUMP]=json.dumps(data,separators=(',',':')).encode()
    out=bytearray(raw[:end]);out.extend(bytes(end-len(out)))
    out.extend(b'BSPX'+struct.pack('<I',len(records))+bytes(32*len(records)))
    for i,(name,payload) in enumerate(records.items()):
        struct.pack_into('<24sII',out,end+8+32*i,name.encode(),len(out),len(payload))
        out.extend(payload);out.extend(bytes((-len(out))%4))
    path.write_bytes(out)

def interval(brush,start,direction,limit):
    """Reference clip used by the pre-runtime feasibility probe."""
    enter,leave=0.,limit
    for p in brush[2]:
        n=np.array(p[:3]);distance=n@start-p[3];slope=n@direction
        if abs(slope)<1e-9:
            if distance>1e-6:return None
        elif slope<0:enter=max(enter,-distance/slope)
        else:leave=min(leave,-distance/slope)
        if enter>leave:return None
    return [enter,leave]

def probe():
    # Use actual builder planes, including an angled thin wooden wall.
    import sys
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
    from generate_tf_maps import Arena
    a=Arena('probe','probe');a.box((-64,-4,0),(64,4,96),'wood')
    a.box((-64,-40,0),(64,-36,96),'metal')
    rows=[solid(b) for b in a.brushes]
    start=convert((0,16,48));direction=convert((0,-32,0))
    hits=[interval(b,start,direction,4) for b in rows]
    assert np.allclose(hits,[[.375,.625],[1.625,1.75]])
    angled=direction+np.array([0,0,.8]);angled/=np.linalg.norm(angled)
    hit=interval(rows[0],start,angled,4)
    assert abs(hit[1]-hit[0]-.25/angled[0])<1e-6
    assert interval(rows[0],convert((90,16,48)),direction,4) is None
    print(json.dumps({'passed':True,'straight_intervals_m':hits,
          'angled_thickness_m':hit[1]-hit[0],
          'conclusion':'Convex clipping measures exact entry/exit, retains later walls and increases thickness at oblique incidence.'}))

def fixture(path):
    """Reproducible collision/combat fixture, generated from real MAP planes."""
    import sys
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
    from generate_tf_maps import Arena
    a=Arena('probe','probe');boxes=[]
    def box(x,width,z,material):
        a.box((-(z+1)*32,-(x+width)*32,0),
              (-(z-1)*32,-x*32,96),material)
        boxes.append({'position':[x+width/2,1.5,z],'size':[width,3,2]})
    for material,width,z in [('wood',.25,0),('wood',2,5),('metal',.125,10),
            ('metal',.3,15),('wall',.2,20),('unknown',.02,25),
            ('wood',.125,30),('wood',.125,35),('wood',.125,40)]:
        box(0,width,z,material)
    box(.125,.125,30,'wood');box(.5,.125,35,'wood');box(.125,.5,40,'metal')
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps({'data':capture(a),'boxes':boxes})+'\n')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture',type=Path,help='Write the Godot collision/combat fixture')
    args=parser.parse_args()
    if args.fixture:fixture(args.fixture)
    else:probe()
