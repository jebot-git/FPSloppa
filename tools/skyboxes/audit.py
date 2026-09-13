"""Audit base BSP sky sightlines without modifying maps or their embedded artwork."""
import hashlib
import json
import math
from pathlib import Path
import re
import struct

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/skyboxes'
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def mix(a,b,t):return tuple(x+(y-x)*t for x,y in zip(a,b))
def godot(p):return [-p[1]/32,p[2]/32,-p[0]/32]

class BSP:
    def __init__(self,path):
        self.raw=path.read_bytes()
        assert struct.unpack_from('<i',self.raw)[0]==29,'This offline audit handles current BSP29 base maps only'
        self.lumps=[self.raw[o:o+n] for o,n in struct.iter_unpack('<ii',self.raw[4:124])]
        self.entities=[dict(re.findall(r'"([^"\n]*)"\s*"([^"\n]*)"',entity)) for entity in re.findall(r'\{([^{}]*)\}',self.lumps[0].decode('latin1'))]
        self.planes=list(struct.iter_unpack('<4fi',self.lumps[1]))
        self.nodes=[struct.unpack_from('<ihh',self.lumps[5],at) for at in range(0,len(self.lumps[5]),24)]
        self.leaves=[struct.unpack_from('<i',self.lumps[10],at)[0] for at in range(0,len(self.lumps[10]),28)]
        self.head=struct.unpack_from('<i',self.lumps[14],36)[0]
        tex=self.lumps[2];self.textures=[]
        for i in range(struct.unpack_from('<i',tex)[0]):
            at=struct.unpack_from('<i',tex,4+i*4)[0]
            self.textures.append({'name':tex[at:at+16].split(b'\0')[0].decode('latin1'),'size':list(struct.unpack_from('<II',tex,at+16))} if at>=0 else {'name':'','size':[0,0]})
    def contents(self,point):
        node=self.head
        while node>=0:
            plane,front,back=self.nodes[node];p=self.planes[plane]
            node=front if dot(point,p[:3])-p[3]>=0 else back
        return self.leaves[-node-1]
    def trace(self,start,end):
        stack=[(self.head,start,end)]
        while stack:
            node,a,b=stack.pop()
            if node<0:
                contents=self.leaves[-node-1]
                if contents not in [-1,-3,-4,-5]:return contents,a
                continue
            plane,front,back=self.nodes[node];p=self.planes[plane]
            da=dot(a,p[:3])-p[3];db=dot(b,p[:3])-p[3]
            if da>=0 and db>=0:stack.append((front,a,b))
            elif da<0 and db<0:stack.append((back,a,b))
            else:
                middle=mix(a,b,da/(da-db))
                near,far=(front,back) if da>=0 else (back,front)
                stack.append((far,middle,b));stack.append((near,a,middle))
        return -1,end
    def candidates(self):
        points=[]
        for entity in self.entities:
            if 'origin' not in entity:continue
            if not entity.get('classname','').startswith(('info_player','item_','weapon_','info_tfgoal')):continue
            p=add(tuple(map(float,entity['origin'].split())),(0,0,48))
            if self.contents(p)==-1:points.append((p,entity['classname']))
        first,count=struct.unpack_from('<ii',self.lumps[14],56)
        for i in range(first,first+count):
            plane,side,edge_start,edges,texinfo=struct.unpack_from('<HHiHH',self.lumps[7],i*20)
            if self.planes[plane][2]*(-1 if side else 1)<.7:continue
            tex=struct.unpack_from('<i',self.lumps[6],texinfo*40+32)[0]
            if self.textures[tex]['name'].startswith(('sky','*')):continue
            vertices=[]
            for edge in range(edge_start,edge_start+edges):
                signed=struct.unpack_from('<i',self.lumps[13],edge*4)[0]
                vi=struct.unpack_from('<HH',self.lumps[12],abs(signed)*4)[0 if signed>=0 else 1]
                vertices.append(struct.unpack_from('<3f',self.lumps[3],vi*12))
            if not vertices:continue
            p=tuple(sum(v[k] for v in vertices)/len(vertices)+(48 if k==2 else 0) for k in range(3))
            if self.contents(p)==-1:points.append((p,'floor'))
        cells=set();unique=[]
        for p,label in points:
            cell=tuple(round(v/128) for v in p)
            if cell in cells:continue
            cells.add(cell);unique.append((p,label))
        if len(unique)>240:unique=unique[::math.ceil(len(unique)/240)]
        return unique

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[]
    directions=[(math.cos(a*math.tau/24)*math.cos(e),math.sin(a*math.tau/24)*math.cos(e),math.sin(e)) for e in [.15,.45,.85,1.25] for a in range(24)]
    for row in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()):
        if row.get('distribution','base')!='base':continue
        bsp=BSP(ROOT/row['path'].removeprefix('res://'))
        candidates=bsp.candidates();views=[];rays=0;sky_rays=0
        for point,label in candidates:
            hits=[]
            for direction in directions:
                content,_=bsp.trace(point,add(point,tuple(v*16384 for v in direction)));rays+=1
                if content==-6:hits.append(direction);sky_rays+=1
            if hits:
                # Aim at the lowest visible opening, retaining the steep angle
                # needed by narrow indoor roof windows. Never average straight up.
                direction=hits[0]
                views.append({'eye':godot(point),'target':godot(add(point,tuple(v*640 for v in direction))),'source':label,'sky_rays':len(hits),'ray_count':len(directions)})
        views.sort(key=lambda v:(v['source']!='floor',v['sky_rays']),reverse=True)
        fields={k:v for k,v in bsp.entities[0].items() if k.lower() in ['sky','skyname','_sky','_skybox','skybox']}
        result={'id':row['id'],'title':row['title'],'sha256':hashlib.sha256(bsp.raw).hexdigest(),'embedded_sky_textures':[t for t in bsp.textures if t['name'].lower().startswith('sky')],'named_skybox':fields,'sky_leaves':bsp.leaves.count(-6),'sampled_positions':len(candidates),'sky_visible_positions':len(views),'rays':rays,'sky_rays':sky_rays,'views':views[:4]}
        result['visible_spawn_item_positions']=sum(v['source']!='floor' for v in views)
        rows.append(result);print(row['id'],'visible',len(views),'/',len(candidates),'spawn/item',result['visible_spawn_item_positions'],'best',views[0]['sky_rays'] if views else 0,flush=True)
    (OUT/'map-audit.json').write_text(json.dumps({'method':'Exact world-BSP leaf traces from spawn/item eyes and sampled upward floor centers; 96 upper-hemisphere rays per point. World sky content (-6) must precede a solid leaf. Static geometry only; doors may affect practical visibility.','maps':rows},indent=2)+'\n')

if __name__=='__main__':main()
