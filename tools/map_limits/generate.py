"""Tiny synthetic BSP rooms isolate coordinate extent from geometry complexity."""
import json, struct
from pathlib import Path
OUT=Path(__file__).resolve().parents[2]/'test-results/map-limits'
OUT.mkdir(parents=True,exist_ok=True)
pack=struct.pack

def room(name,lo,hi,version=0x32505342):
    bsp2=version!=29
    low=[lo,lo,0];high=[hi,hi,128]
    lumps=[b'' for _ in range(15)]
    lumps[0]=b'{\n"classname" "worldspawn"\n"message" "Coordinate limit fixture"\n}\n{\n"classname" "info_player_deathmatch"\n"origin" "0 0 48"\n}\n\0'
    texture=pack('<16s6I',b'limit_gray',16,16,40,296,360,376)+bytes([80])*340
    lumps[2]=pack('<ii',1,8)+texture
    planes=[];vertices=[];edges=[];faces=[];surfedges=[]
    for axis in range(3):
        for sign in [-1,1]:
            normal=[0.,0.,0.];normal[axis]=sign
            plane=len(planes);distance=high[axis] if sign>0 else -low[axis]
            planes.append(pack('<4fi',*normal,distance,axis))
            other=[a for a in range(3) if a!=axis]
            points=[]
            for a,b in [(0,0),(1,0),(1,1),(0,1)]:
                p=[0.,0.,0.];p[axis]=high[axis] if sign>0 else low[axis]
                p[other[0]]=[low,high][a][other[0]];p[other[1]]=[low,high][b][other[1]];points.append(p)
            def sub(a,b):return [x-y for x,y in zip(a,b)]
            u=sub(points[1],points[0]);v=sub(points[2],points[0]);cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            # Godot consumes clockwise front faces; their cross product points outward.
            if cross[axis]*sign<0:points.reverse()
            first=len(vertices);vertices+=points
            edgefirst=len(edges)
            for i in range(4):edges.append((first+i,first+(i+1)%4));surfedges.append(edgefirst+i)
            faces.append(pack('<5i4Bi',plane,1,edgefirst,4,plane,255,255,255,255,-1) if bsp2 else pack('<HHiHH4Bi',plane,1,edgefirst,4,plane,255,255,255,255,-1))
            s=[0.,0.,0.];t=[0.,0.,0.];s[other[0]]=1.;t[other[1]]=1.
            lumps[6]+=pack('<8fii',*s,0.,*t,0.,0,0)
    lumps[1]=b''.join(planes);lumps[3]=b''.join(pack('<3f',*p) for p in vertices)
    for i in range(6):
        child=i+1 if i<5 else -2
        lumps[5]+=pack('<3i6f2I',i,-1,child,*low,*high,i,1) if bsp2 else pack('<i2h6h2H',i,-1,child,*low,*high,i,1)
    lumps[7]=b''.join(faces)
    for contents in [-2,-1]:
        lumps[10]+=pack('<2i6f2I4B',contents,-1,*low,*high,0,6,0,0,0,0) if bsp2 else pack('<2i6h2H4B',contents,-1,*low,*high,0,6,0,0,0,0)
    lumps[11]=b''.join(pack('<I' if bsp2 else '<H',i) for i in range(6))
    lumps[12]=b''.join(pack('<2I' if bsp2 else '<2H',*e) for e in edges)
    lumps[13]=b''.join(pack('<i',i) for i in surfedges)
    lumps[14]=pack('<9f7i',*low,*high,0.,0.,0.,0,-1,-1,-1,1,0,6)
    data=bytearray(pack('<I',version)+bytes(120))
    for i,lump in enumerate(lumps):
        while len(data)%4:data.append(0)
        struct.pack_into('<2I',data,4+i*8,len(data),len(lump));data.extend(lump)
    (OUT/(name+'.bsp')).write_bytes(data)
    return dict(name=name,version=version,minimum_units=lo,maximum_units=hi,side_m=(hi-lo)/32,area_km2=((hi-lo)/32000)**2,bytes=len(data),faces=6)
rows=[room('bsp29_bounds',-32768,32767,29)]
for bound in [32768,131072,1048576,8388608,10000000,10000001]:rows.append(room('bsp2_'+str(bound),-bound,bound))
# This legacy signature passes the wrapper's version check but the reader declines it.
legacy=bytearray((OUT/'bsp2_32768.bsp').read_bytes());struct.pack_into('<I',legacy,0,0x42535032);(OUT/'legacy_2psb.bsp').write_bytes(legacy)
(OUT/'fixtures.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows,indent=2))
