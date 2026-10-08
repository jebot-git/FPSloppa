#!/usr/bin/env python3
"""Rebuild the Classic pack as playable ST BSP2 maps from pinned survey geometry.

Retains mission metres, source terrain holes, scaled/rotated convex interiors,
flag positions and equipment. Original texture pixels are replaced with the
project's licensed Makkon/LibreQuake materials. No TorqueScript is executed.
"""
from pathlib import Path
import argparse, hashlib, json, math, re, struct, subprocess, sys
import numpy as np
from sources import HERE, LOCAL, parse
ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from stonehenge.build import Stonehenge, Arena
from katabatic.build import transform
from makkon.theme import wad_textures
OUT=ROOT/'maps/T2Classic'
LOG=ROOT/'test-results/t2-classic'
GRASS='grass';SNOW='snow1';ROCK='med_rock4';WALL='ind_w02_grey1';FLOOR='ind_dp01_grey1';TRIM='metal_iron1_01';SKY='sky_star'
DESERT={'Acid Rain','Confusco','Desert of Death','Gorgon','Rollercoaster','Sandstorm'}
ICE={'IceRidge','Shock Ridge','Snowblind','Sub-zero'}
VOLCANO={'Magmatic','White Dwarf'}
def fields(d):return '\n'.join(f'"{k}" "{v}"' for k,v in d.items())
def xyz(row):return np.array(list(map(float,row['position'].split()))[:3])
def team(row):
    parents=[p.lower() for p in row['parents']]
    return 0 if 'team1' in parents else 1 if 'team2' in parents else -1

def wad():
    records={}
    for p in ['Raindance/raindance.wad','Stonehenge/stonehenge.wad','Katabatic/katabatic.wad','KOTH/source/koth-used.wad','CTFStudies/materials.wad']:
        records.update(wad_textures((ROOT/'maps'/p).read_bytes()))
    # Reuse licensed rock for desert/volcanic ground; do not bundle T2 art.
    names=['skip',GRASS,SNOW,ROCK,'med_rock10b',WALL,FLOOR,TRIM,SKY,'ind_dp01_red1','ind_dp01_blu1','*water0','*lava1']
    raw=bytearray(b'WAD2'+bytes(8));directory=[]
    for name in names:
        data=records[name];directory.append(struct.pack('<iiiBBH16s',len(raw),len(data),len(data),68,0,0,name.encode()));raw.extend(data)
    at=len(raw);raw.extend(b''.join(directory));struct.pack_into('<ii',raw,4,len(directory),at)
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'classic.wad').write_bytes(raw)

class Classic(Stonehenge):
    def __init__(self,row):
        Arena.__init__(self,row['id'],row['title']+' | Tribes 2 Classic');self.row=row
        self.items=[r for r in parse((LOCAL/row['mission']).read_text()) if not r.get('missionTypesList') or 'CTF' in r['missionTypesList'].upper().split()];self.detail=[];self.building_models=[];self.floors=[];self.solids=[];self.hull_count=0
        self.terrain_row=next(r for r in self.items if r['class']=='TerrainBlock');self.square=float(self.terrain_row['squareSize'])
        self.heightmap=np.frombuffer((LOCAL/row['terrain']).read_bytes(),dtype='<u2',offset=1,count=65536).reshape(256,256)/32
        area=next(r for r in self.items if r['class']=='MissionArea');x,y,w,h=map(float,area['area'].split())
        self.center=np.array([x+w/2,y+h/2,0.]);self.extent=(x,y,x+w,y+h)
        self.low=-32.;self.high=max(float(self.heightmap.max())+160,450.)
        self.flags=[xyz(next(r for r in self.items if r.get('dataBlock','').lower()=='flag' and team(r)==t)) for t in range(2)]
        self.holes=set()
        for run in map(int,self.terrain_row.get('emptySquares','').split()):self.holes.update(range(run&65535,(run&65535)+(run>>16)))
        self.models={key:json.loads((LOCAL/(path+'.json')).read_text()) for key,path in row['interiors'].items()}
        self.ground=SNOW if row['title'] in ICE else 'med_rock10b' if row['title'] in DESERT|VOLCANO else GRASS
        self.probes={'id':row['id'],'title':row['title'],'spawns':[],'flags':[],'stations':[],'portals':[],'views':[],'boundary':{'min':[-w/2,self.low,-h/2],'max':[w/2,self.high,h/2]},'source_objects':len(self.items),'adjustments':[]}
        self.grids={};self.triangles=[];self.buildings=[r for r in self.items if r['class']=='InteriorInstance']
        # Each coarse cell subdivides to source resolution near buildings/holes,
        # 2x on approaches, and 4x at the periphery. Shared edges interpolate.
        s=self.square;coarse=s*4
        self.x0=math.floor(x/coarse)*coarse;self.y0=math.floor(y/coarse)*coarse
        self.x1=math.ceil((x+w)/coarse)*coarse;self.y1=math.ceil((y+h)/coarse)*coarse
        self.building_boxes=[]
        for b in self.buildings:
            d=self.models[b['interiorFile']];rotation,origin=transform(b);scale=np.array(list(map(float,b.get('scale','1 1 1').split())))
            pts=(np.array(d['points'])*scale)@rotation.T+origin
            self.building_boxes.append((pts.min(axis=0),pts.max(axis=0)))
        # T2 permits bases beyond MissionArea (which only warns/drops flags).
        # ST has solid borders, so enclose authored bases and service fixtures too.
        useful=[xyz(r) for r in self.items if 'position' in r and (r['class']=='SpawnSphere' or r.get('dataBlock') in ['StationInventory','GeneratorLarge','StationVehiclePad','SolarPanel'])]
        useful.extend(p for box in self.building_boxes for p in box)
        if useful:
            lo=np.array(useful).min(axis=0);hi=np.array(useful).max(axis=0)
            x=min(x,math.floor((lo[0]-16)/coarse)*coarse);y=min(y,math.floor((lo[1]-16)/coarse)*coarse)
            X=max(self.extent[2],math.ceil((hi[0]+16)/coarse)*coarse);Y=max(self.extent[3],math.ceil((hi[1]+16)/coarse)*coarse)
            self.extent=(x,y,X,Y);w=X-x;h=Y-y;self.center=np.array([(x+X)/2,(y+Y)/2,0.]);self.high=max(self.high,float(hi[2])+100)
            self.x0=math.floor(x/coarse)*coarse;self.y0=math.floor(y/coarse)*coarse;self.x1=math.ceil(X/coarse)*coarse;self.y1=math.ceil(Y/coarse)*coarse
            self.probes['boundary']={'min':[-w/2,self.low,-h/2],'max':[w/2,self.high,h/2]}
        for cy in np.arange(self.y0,self.y1,coarse):
            for cx in np.arange(self.x0,self.x1,coarse):
                near=min(math.hypot(cx+coarse/2-p[0],cy+coarse/2-p[1]) for p in self.flags)
                interior=any(lo[0]-s<cx+coarse and hi[0]+s>cx and lo[1]-s<cy+coarse and hi[1]+s>cy for lo,hi in self.building_boxes)
                cut=any(self.hole(cx+ix*s,cy+iy*s) for ix in range(4) for iy in range(4))
                self.grids[(cx,cy)]=s if interior or cut or near<70 else s*2 if near<220 else coarse
    def game(self,p):return [round(float(p[0]-self.center[0]),5),round(float(p[2]),5),round(float(self.center[1]-p[1]),5)]
    def quake(self,p):return ((p[1]-self.center[1])*32,(self.center[0]-p[0])*32,p[2]*32)
    def face(self,points,texture):return ' '.join('( %.6f %.6f %.6f )'%tuple(p) for p in reversed(points))+f' {texture} 0 0 0 {4 if texture in [GRASS,SNOW,ROCK,"med_rock10b",SKY] else 1} {4 if texture in [GRASS,SNOW,ROCK,"med_rock10b",SKY] else 1}'
    def convex(self,vertices,faces,texture,detail=True):
        pts=np.array(vertices);center=pts.mean(axis=0);rows=[]
        for f in faces:
            p=pts[f];n=np.cross(p[1]-p[0],p[2]-p[0])
            if n@(p.mean(axis=0)-center)<0:p=p[::-1]
            if np.linalg.norm(n)>1e-7:rows.append(self.face([self.quake(v) for v in p[:3]],texture))
        if len(rows)>=4:(self.detail if detail else self.brushes).append('{\n'+'\n'.join(rows)+'\n}')
    def marker(self,kind,p,**props):self.ent(kind,self.quake((p[0],p[1],p[2]+.70)),**props)
    def hole(self,x,y):return (math.floor(y/self.square+128)%256)*256+math.floor(x/self.square+128)%256 in self.holes
    def original_height(self,x,y):
        gx=x/self.square+128;gy=y/self.square+128;cx=math.floor(gx);cy=math.floor(gy);u=gx-cx;v=gy-cy;m=self.heightmap
        a,b,c,d=m[cy%256,cx%256],m[cy%256,(cx+1)%256],m[(cy+1)%256,(cx+1)%256],m[(cy+1)%256,cx%256]
        if (cx+cy)%2:return a+u*(b-a)+v*(d-a) if u+v<=1 else c+(1-v)*(b-c)+(1-u)*(d-c)
        return a+u*(b-a)+v*(c-b) if u>=v else a+u*(c-d)+v*(d-a)
    def vertex(self,x,y):
        coarse=self.square*4;x0=math.floor(x/coarse)*coarse;y0=math.floor(y/coarse)*coarse;step=self.grids.get((x0,y0),coarse)
        if abs(x-x0)<1e-6:
            s=max(step,self.grids.get((x0-coarse,y0),step));start=math.floor((y-y0)/s)*s+y0
            if y!=start:return self.original_height(x,start)+(self.original_height(x,start+s)-self.original_height(x,start))*(y-start)/s
        if abs(y-y0)<1e-6:
            s=max(step,self.grids.get((x0,y0-coarse),step));start=math.floor((x-x0)/s)*s+x0
            if x!=start:return self.original_height(start,y)+(self.original_height(start+s,y)-self.original_height(start,y))*(x-start)/s
        return self.original_height(x,y)
    def terrain(self):
        for (cx,cy),s in self.grids.items():
            for y in np.arange(cy,cy+self.square*4,s):
                for x in np.arange(cx,cx+self.square*4,s):
                    if self.hole(x+.01,y+.01):continue
                    corners=[(a,b,self.vertex(a,b)) for a,b in [(x,y),(x+s,y),(x+s,y+s),(x,y+s)]]
                    for f in ([[0,1,3],[1,2,3]] if (round(x/s)+round(y/s))%2 else [[0,1,2],[0,2,3]]):
                        top=np.array([corners[i] for i in f]);n=np.cross(top[1]-top[0],top[2]-top[0]);tex=ROCK if abs(n[2])/np.linalg.norm(n)<.48 else self.ground
                        # Thin shells avoid filling underground rooms. The sky
                        # hull below seals the world independently of cutouts.
                        near_building=any(lo[0]-s<x+s and hi[0]+s>x and lo[1]-s<y+s and hi[1]+s>y for lo,hi in self.building_boxes)
                        bottom=top-np.array([0,0,.75]) if near_building else np.array([(p[0],p[1],self.low) for p in top]);self.convex(np.vstack([bottom,top]),[[0,2,1],[0,1,4,3],[1,2,5,4],[2,0,3,5],[3,4,5]],tex)
                        self.triangles.append(top)
        x0,y0,x1,y1=self.x0,self.y0,self.x1,self.y1;lo=self.low;hi=self.high
        self.block((x0-4,y0-4,lo-4),(x1+4,y1+4,lo),ROCK,detail=False)
        self.block((x0-4,y0-4,hi),(x1+4,y1+4,hi+4),SKY,detail=False)
        for a,b in [((x0-4,y0-4,lo),(x0,y1+4,hi)),((x1,y0-4,lo),(x1+4,y1+4,hi)),((x0,y0-4,lo),(x1,y0,hi)),((x0,y1,lo),(x1,y1+4,hi))]:self.block(a,b,SKY,detail=False)
        x,y,X,Y=self.extent;self.marker('info_playable_bounds',(self.center[0],self.center[1],(lo+hi)/2),size=f'{X-x} {hi-lo} {Y-y}')
    def material(self,name,t):
        n=name.upper()
        if 'LIG' in n:return 'ind_dp01_red1' if t==0 else 'ind_dp01_blu1' if t==1 else TRIM
        if 'FLO' in n or 'GRATE' in n:return FLOOR
        if any(v in n for v in ['BOR','COL','THRESH','METAL']):return TRIM
        return WALL
    def building(self,row):
        d=self.models[row['interiorFile']];rotation,origin=transform(row);scale=np.array(list(map(float,row.get('scale','1 1 1').split())))
        points=np.array(d['points']);world=(points*scale)@rotation.T+origin;brushes=[]
        hulls=d['convexHulls']
        for hi,h in enumerate(hulls):
            ids=d['hullIndices'][h['hullStart']:h['hullStart']+h['hullCount']];vertices=points[ids];center=vertices.mean(axis=0);faces=[];planes=[]
            end=hulls[hi+1]['planeStart'] if hi+1<len(hulls) else len(d['hullPlaneIndices'])
            surfaces=[d['nullSurfaces'][i&0x7fffffff] if i&0x80000000 else d['surfaces'][i] for i in d['hullSurfaceIndices'][h['surfaceStart']:h['surfaceStart']+h['surfaceCount']]]
            for idx in d['hullPlaneIndices'][h['planeStart']:end]:
                plane=d['planes'][idx&0x7fff];normal=np.array(d['normals'][plane['normalIndex']]);distance=plane['distance'];candidates=vertices[np.abs(vertices@normal+distance)<.004]
                if len(candidates)<3:continue
                a=candidates[0];b=max(candidates,key=lambda p:np.linalg.norm(p-a));c=max(candidates,key=lambda p:np.linalg.norm(np.cross(b-a,p-a)))
                n=np.cross(b-a,c-a)
                if np.linalg.norm(n)<1e-7:continue
                poly=np.array([a,b,c]);
                if n@(poly.mean(axis=0)-center)<0:poly=poly[::-1]
                face=next((s for s in surfaces if s['planeIndex']&0x7fff==idx&0x7fff and 'textureIndex' in s),None)
                tex=self.material(d['materialNames'][face['textureIndex']] if face else '',team(row))
                poly=(poly*scale)@rotation.T+origin
                faces.append(self.face([self.quake(p) for p in poly],tex))
                n=np.cross(poly[1]-poly[0],poly[2]-poly[0]);n/=np.linalg.norm(n);planes.append([*n,-n@poly[0]])
            if len(faces)>=4:
                brushes.append('{\n'+'\n'.join(faces)+'\n}');self.hull_count+=1
                wp=world[ids];self.solids.append((wp.min(axis=0),wp.max(axis=0),np.array(planes)))
        if brushes:self.building_models.append('{\n"classname" "func_wall"\n'+'\n'.join(brushes)+'\n}')
        for s in d['surfaces']:
            idx=s['planeIndex'];p=d['planes'][idx&0x7fff];normal=np.array(d['normals'][p['normalIndex']])*(-1 if idx&0x8000 else 1)
            if (rotation@(normal/scale))[2]<.5:continue
            winding=d['windings'][s['windingStart']:s['windingStart']+s['windingCount']];poly=world[winding]
            for i in range(1,len(poly)-1):self.floors.append(poly[[0,i,i+1]])
    def prepare_floors(self):
        self.surface=np.array(self.triangles+self.floors);self.mins=self.surface.min(axis=1);self.maxs=self.surface.max(axis=1)
    def floor(self,x,y,z,max_distance=8):
        mask=(self.mins[:,0]<=x+.001)&(self.maxs[:,0]>=x-.001)&(self.mins[:,1]<=y+.001)&(self.maxs[:,1]>=y-.001)&(self.mins[:,2]<z+max_distance)&(self.maxs[:,2]>z-max_distance)
        found=[]
        for tri in self.surface[mask]:
            a,b,c=tri;mat=np.array([b[:2]-a[:2],c[:2]-a[:2]]).T
            if abs(np.linalg.det(mat))<1e-7:continue
            u,v=np.linalg.solve(mat,np.array([x,y])-a[:2])
            if min(u,v)>=-.001 and u+v<=1.001:
                h=a[2]+u*(b[2]-a[2])+v*(c[2]-a[2])
                if abs(h-z)<max_distance:found.append(h)
        return min(found,key=lambda h:abs(h-z)) if found else None
    def clear(self,p,r=.45,height=1.9):
        p=np.array(p)
        for lo,hi,planes in self.solids:
            if (p[0]+r<lo[0] or p[0]-r>hi[0] or p[1]+r<lo[1] or p[1]-r>hi[1] or p[2]+height<lo[2] or p[2]>hi[2]):continue
            for z in [.45,1.,height-.3]:
                point=p+np.array([0,0,z]);distance=planes[:,:3]@point+planes[:,3]
                if np.all(distance<r):return False
        return True
    def supported(self,p,max_distance=8):
        p=np.array(p,dtype=float);h=self.floor(*p,max_distance)
        if h is None:return None
        p[2]=h+.08
        return p if self.clear(p) else None
    def portal(self,p):
        g=self.game(p)
        if len(self.probes['portals'])>=900 or any(math.dist(g,q)<2 for q in self.probes['portals']):return
        self.marker('info_tribes_navigation',p);self.probes['portals'].append(g)
    def equipment(self):
        # Unpowered/neutral missions explicitly opt in. Ordinary imported BSPs
        # still require the original full ST fixture contract.
        generators=[r for r in self.items if r.get('dataBlock') in ['GeneratorLarge','SolarPanel']]
        for t in range(2):
            f=self.supported(self.flags[t],12)
            if f is None:raise ValueError(f'{self.title}: unsupported flag {t} {self.flags[t]}')
            self.flags[t]=f;self.marker('item_flag_team'+str(t+1),f);self.probes['flags'].append({'team':t,'position':self.game(f)});self.portal(f)
        mapping={'StationInventory':'inventory','StationAmmo':'ammo','StationVehiclePad':'vehicle','GeneratorLarge':'portable_generator','SolarPanel':'solar','SensorLargePulse':'sensor','SensorMediumPulse':'sensor','SensorSmallPulse':'sensor','TurretBaseLarge':'turret','SentryTurret':'turret','RepairPack':'repair_patch'}
        for index,row in enumerate(self.items):
            db=row.get('dataBlock','');kind=mapping.get(db)
            if not kind:continue
            t=team(row);p=xyz(row);original=p.copy();f=self.floor(*p,8)
            if f is not None:p[2]=f+.08
            angle=list(map(float,row.get('rotation','1 0 0 0').split()));yaw=angle[2]*angle[3]
            props={'team':t,'angle':round(yaw,5)}
            # Torque uses self-powered fixtures when no generators exist.
            # Retain local power groups when generators are in separate subgroups.
            own=[g for g in generators if team(g)==t]
            if not own:props['self_powered']='1'
            if kind in ['portable_generator','solar']:props['targetname']=f'power_{index}'
            if kind=='turret':props['type']='mini' if db=='SentryTurret' else 'missile' if row.get('initialBarrel')=='AABarrelLarge' else 'fusion'
            if kind=='vehicle':
                # Source is deck centre; ST terminal sits at its trailing edge.
                pad=p.copy();r=math.radians(yaw);p+=np.array([8*math.sin(r),-8*math.cos(r),0]);props['vehicle_spawn']=' '.join(map(str,self.game(pad+np.array([0,0,1.4]))))
            if kind in ['inventory','ammo','vehicle']:
                if not self.clear(p):
                    candidates=[]
                    for radius in [1.,2.,3.]:
                        for a in np.linspace(0,2*math.pi,16,endpoint=False):
                            q=self.supported(p+np.array([math.cos(a)*radius,math.sin(a)*radius,0]),2)
                            if q is not None:candidates.append(q)
                        if candidates:break
                    if candidates:p=min(candidates,key=lambda q:np.linalg.norm(q-original));self.probes['adjustments'].append({'kind':kind,'from':self.game(original),'to':self.game(p)})
                self.probes['stations'].append({'team':t,'kind':kind,'position':self.game(p),'self_powered':not own});self.portal(p)
            self.marker('info_tribes_'+kind,p,**props)
            if kind=='inventory':self.ent('light',self.quake(p+np.array([0,0,3])),light=260,_color='.8 .85 1',wait='.3')
        # Sample true floors inside original spawn spheres. Keep separate rooms
        # and roofs available rather than spawning every player at the flag.
        for t in range(2):
            spheres=[r for r in self.items if r['class']=='SpawnSphere' and team(r)==t]
            candidates=[]
            for sphere in spheres:
                c=xyz(sphere);rad=float(sphere.get('radius',50))
                for tri in self.floors:
                    for p in [tri.mean(axis=0)]:
                        if np.linalg.norm(p-c)<=rad and self.clear(p+np.array([0,0,.08])):candidates.append(p+np.array([0,0,.08]))
                if float(sphere.get('outdoorWeight',100))>0:
                    for dy in np.arange(-rad*.7,rad*.71,6):
                        for dx in np.arange(-rad*.7,rad*.71,6):
                            x,y=c[0]+dx,c[1]+dy;h=self.original_height(x,y);p=self.supported((x,y,h),12)
                            if p is not None and np.linalg.norm(p-c)<rad:candidates.append(p)
            if not candidates:
                f=self.flags[t]
                for dy in range(-16,17,4):
                    for dx in range(-16,17,4):
                        p=self.supported(f+np.array([dx,dy,0]),8)
                        if p is not None:candidates.append(p)
            candidates=[p for p in candidates if self.extent[0]+2<p[0]<self.extent[2]-2 and self.extent[1]+2<p[1]<self.extent[3]-2 and not any(math.dist(self.game(p),r['position'])<4 for r in self.probes['stations'])]
            if len(candidates)<8:
                self.probes['adjustments'].append({'kind':'spawn_sphere','team':t,'reason':'Source sphere has no usable in-bounds CTF floors; survey near own flag'})
                f=self.flags[t]
                for dy in range(-40,41,4):
                    for dx in range(-40,41,4):
                        p=self.supported(f+np.array([dx,dy,0]),24)
                        if p is not None and self.extent[0]+2<p[0]<self.extent[2]-2 and self.extent[1]+2<p[1]<self.extent[3]-2 and not any(math.dist(self.game(p),r['position'])<4 for r in self.probes['stations']):candidates.append(p)
            chosen=[]
            # Farthest-point selection spreads spawns over the surveyed area.
            candidates.sort(key=lambda p:np.linalg.norm(p-self.flags[t]))
            while candidates and len(chosen)<8:
                p=candidates.pop(0) if not chosen else max(candidates,key=lambda p:min(np.linalg.norm(p-q) for q in chosen))
                if chosen:candidates=[q for q in candidates if not np.array_equal(q,p)]
                if any(np.linalg.norm(p-q)<2 for q in chosen):continue
                chosen.append(p)
            if len(chosen)<4:raise ValueError(f'{self.title}: only {len(chosen)} clear spawns for team {t}')
            for i,p in enumerate(chosen):
                self.marker('info_player_team'+str(t+1),p,angle=t*180);self.probes['spawns'].append({'team':t,'position':self.game(p)});self.portal(p)
                if t==0 and i==0:self.marker('info_player_start',p)
            self.probes['views'].append({'eye':self.game(self.flags[t]+np.array([90,-90,65])),'look':self.game(self.flags[t])})
        # Floor centroids provide indoor jet-route transitions. Physics QA checks
        # their support and clearance after compilation, before cache generation.
        for tri in self.floors:
            if len(self.probes['portals'])>=850:break
            if np.linalg.norm(np.cross(tri[1]-tri[0],tri[2]-tri[0]))<8:continue
            p=tri.mean(axis=0)+np.array([0,0,.08])
            if self.clear(p):self.portal(p)
    def water(self):
        # WaterBlock repeats in 2048 m tiles and its surface is position+scale.z.
        for row in self.items:
            if row['class']!='WaterBlock':continue
            p=xyz(row);size=np.array(list(map(float,row['scale'].split())));kind='lava' if 'lava' in row.get('liquidType','').lower() else 'water'
            for dx in [-2048,0,2048]:
                for dy in [-2048,0,2048]:
                    lo=np.array([max(self.x0,p[0]+dx),max(self.y0,p[1]+dy),p[2]])
                    hi=np.array([min(self.x1,p[0]+dx+size[0]),min(self.y1,p[1]+dy+size[1]),p[2]+size[2]])
                    if np.any(hi<=lo):continue
                    # Native BSP liquids provide swimming, underwater queries and lava damage.
                    self.block(lo,hi,'*lava1' if kind=='lava' else '*water0',detail=False)
    def build(self):
        self.terrain()
        for row in self.buildings:self.building(row)
        self.prepare_floors();self.equipment();self.water()

def build(row,args):
    folder=OUT/row['id'];folder.mkdir(parents=True,exist_ok=True);logs=LOG/row['id'];logs.mkdir(parents=True,exist_ok=True)
    arena=Classic(row);arena.build();key=row['id']
    corrections=HERE/'placements.json'
    for fix in json.loads(corrections.read_text()).get(key,[]) if corrections.exists() else []:
        old=arena.game(fix['from']);new=arena.game(fix['to'])
        def origin(v):return '%g %g %g'%(-v[2]*32,-v[0]*32,(v[1]+.7)*32)
        for entity in arena.entities:
            if fix['category']=='vehicle_spawn':
                if 'vehicle_spawn' in entity and math.dist(list(map(float,entity['vehicle_spawn'].split())),old)<.01:entity['vehicle_spawn']=' '.join(map(str,new))
                continue
            if 'origin' in entity and math.dist(list(map(float,str(entity['origin']).split())),list(map(float,origin(old).split())))<.2:entity['origin']=origin(new)
        for category in ['spawns','flags','stations']:
            for item in arena.probes[category]:
                if math.dist(item['position'],old)<.01:item['position']=new
        arena.probes['portals']=[new if math.dist(p,old)<.01 else p for p in arena.probes['portals']]
    world={'classname':'worldspawn','message':arena.title,'wad':'classic.wad','_fpsloppa_st_classic':'1','_fpsloppa_bake':'1','_fpsloppa_light_response':'quake','_fpsloppa_atlas':'4096','_lightmap_scale':'64','_minlight':'30','_sunlight':'160','_sunlight2':'70','_sun_mangle':'120 -55 0','_phong':'1','_phong_angle':'65'}
    source='{\n'+fields(world)+'\n'+'\n'.join(arena.brushes)+'\n}\n{\n"classname" "func_detail"\n'+'\n'.join(arena.detail)+'\n}\n'+'\n'.join(arena.building_models)+'\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in arena.entities)+'\n'
    path=folder/(key+'.map');path.write_text(source);(folder/'probes.json').write_text(json.dumps(arena.probes,indent=2)+'\n')
    bsp=ROOT/'maps'/(key+'.bsp');bsp.with_suffix('.pts').unlink(missing_ok=True)
    commands=[('qbsp',['-bsp2','-noclip','-subdivide','4096','-wadpath',str(OUT),str(path),str(bsp)])]
    if not args.geometry_only:commands.extend([('vis',['-threads','2','-fast',str(bsp)]),('light',['-threads','2','-lmscale','64','-bspxlit',str(bsp)])])
    for exe,flags in commands:
        print(key,exe,flush=True)
        with (logs/(exe+'.log')).open('w') as log:subprocess.run([str(args.compiler/exe),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
    raw=bsp.read_bytes()
    if len(raw)>25_000_000:raise ValueError(f'{key}: BSP exceeds transfer limit ({len(raw)})')
    if bsp.with_suffix('.pts').exists():raise ValueError(key+': BSP leaked')
    report={'id':key,'title':arena.title,'bsp_sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'bsp_version':'BSP2','source_mission':row['mission'],'terrain_triangles':len(arena.triangles),'interior_hulls':arena.hull_count,'building_instances':len(arena.buildings),'flags':arena.probes['flags'],'spawns':len(arena.probes['spawns']),'stations':len(arena.probes['stations']),'portals':len(arena.probes['portals']),'flag_separation_m':float(np.linalg.norm(arena.flags[0]-arena.flags[1])),'lighting':not args.geometry_only,'visibility':'fast conservative'}
    (folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
    return report

def register(reports):
    catalog=ROOT/'deathmatch/maps/manifest.json';rows=json.loads(catalog.read_text())
    for r in reports:
        rows=[row for row in rows if row['id']!=r['id']]
        rows.append({'id':r['id'],'title':r['title'],'path':f'res://maps/{r["id"]}.bsp','scene':f'res://maps/cache/{r["id"]}.scn','sha256':r['bsp_sha256'],'size':r['bytes'],'modes':['st'],'source_name':r['id'],'distribution':'base','objectives':{['red','blue'][f['team']]:f['position'] for f in r['flags']}})
    catalog.write_text(json.dumps(rows,indent=2)+'\n')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--map');p.add_argument('--geometry-only',action='store_true');p.add_argument('--register-only',action='store_true');p.add_argument('--resume',action='store_true');a=p.parse_args()
    manifest=json.loads((HERE/'sources.json').read_text());rows=[r for r in manifest['maps'] if not r['existing'] and (not a.map or a.map in [r['id'],r['title']])]
    if not rows:raise ValueError('No matching maps')
    wad();reports=[]
    for r in rows:
        reports.append(json.loads((OUT/r['id']/'manifest.json').read_text()) if a.register_only or a.resume and (OUT/r['id']/'manifest.json').exists() else build(r,a))
        register(reports)
    (LOG/'build.json').write_text(json.dumps(reports,indent=2)+'\n')
if __name__=='__main__':main()
