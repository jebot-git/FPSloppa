#!/usr/bin/env python3
"""Reconstruct Tribes 2 Katabatic as BSP29 with native ST equipment and routing.

Authoring coordinates remain original Torque XY/Z-up metres. Terrain and
convex building solids are surveyed from the pinned original mission. Surface
materials, equipment and collision-clearance adjustments use FPSloppa systems.
"""
from pathlib import Path
import argparse,hashlib,json,math,re,struct,subprocess,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from stonehenge.build import Stonehenge,Arena,wad_records
ID='ctf_katabatic';OUT=ROOT/'maps/Katabatic';LOCAL=ROOT/'tools/katabatic/local';LOG=ROOT/'test-results/st-katabatic'
CENTER=(-144,0);EXTENT=(-896,-704,608,704)
SNOW='snow1';ROCK='med_rock10b';WALL='ind_w02_grey1';FLOOR='ind_dp01_grey1';TRIM='metal_iron1_01';SKY='sky_star'
def game(p):return [round(p[0]-CENTER[0],5),round(p[2],5),round(-p[1],5)]
def quake(p):return (p[1]*32,(CENTER[0]-p[0])*32,p[2]*32)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def fields(d):return '\n'.join(f'"{k}" "{v}"' for k,v in d.items())
def mission():
    source=(LOCAL/'Katabatic.mis').read_text();stack=[];items=[]
    token=re.compile(r'new\s+(\w+)\(([^)]*)\)\s*\{|(\w+)\s*=\s*"([^"]*)"\s*;|\};')
    for m in token.finditer(source):
        if m[1]:stack.append({'class':m[1],'name':m[2],'parents':[n['name'] for n in stack]})
        elif m[3] and stack:stack[-1][m[3]]=m[4]
        elif stack:items.append(stack.pop())
    return items
def transform(row):
    axis=np.array(list(map(float,row.get('rotation','1 0 0 0').split())));angle=math.radians(axis[3]);axis=axis[:3]
    axis/=max(np.linalg.norm(axis),1e-9);x,y,z=axis;k=np.array([[0,-z,y],[z,0,-x],[-y,x,0]])
    # Torque's axis-angle mission rotations use the opposite handedness.
    rotation=np.eye(3)-math.sin(angle)*k+(1-math.cos(angle))*(k@k)
    return rotation,np.array(list(map(float,row['position'].split())))

class Katabatic(Stonehenge):
    def __init__(self):
        Arena.__init__(self,ID,'Katabatic | Tribes 2 CTF');self.detail=[];self.heights={};self.items=mission()
        self.heightmap=np.frombuffer((LOCAL/'Katabatic.ter').read_bytes(),dtype='<u2',count=65536,offset=1).reshape(256,256)/32
        self.models={p.stem:json.loads(p.read_text()) for p in LOCAL.glob('*.json') if p.stem in ['sbunk2','svpad','smisc3','stowr6','stowr4']}
        self.holes=set();terrain=next(r for r in self.items if r['class']=='TerrainBlock')
        for run in map(int,terrain['emptySquares'].split()):self.holes.update(range(run&65535,(run&65535)+(run>>16)))
        self.probes=dict(spawns=[],flags=[],stations=[],landmarks=[],routes=[],views=[],portals=[],boundary=dict(min=[-750,-24,-694],max=[750,360,694]))
        self.terrain_triangles=[];self.building_floors=[];self.floor_groups=[];self.interior_hulls=0;self.building_models=[];self.roofs={}
        self.flags=[tuple(map(float,next(r for r in self.items if r['name']==f'Team{i+1}Flag1')['position'].split())) for i in range(2)]
        self.grids={}
        for y in range(EXTENT[1],EXTENT[3],32):
            for x in range(EXTENT[0],EXTENT[2],32):
                near=min(math.hypot(x+16-f[0],y+16-f[1]) for f in self.flags)
                # Eight-metre source grid around terrain-cut underground bases;
                # sixteen-metre cap approaches, thirty-two elsewhere for BSP29.
                self.grids[x,y]=8 if near<75 else 16 if near<160 else 32
    def face(self,points,texture):
        scale=4 if texture in [SNOW,ROCK] else 1
        return ' '.join('( %.7f %.7f %.7f )'%tuple(p) for p in reversed(points))+f' {texture} 0 0 0 {scale} {scale}'
    def convex(self,vertices,faces,texture,detail=True):
        # Shared brush writer expects Stonehenge's authoring origin.
        super().convex([(x-CENTER[0]+384,y+416,z) for x,y,z in vertices],faces,texture,detail)
    def marker(self,kind,p,**props):self.ent(kind,quake((p[0],p[1],p[2]+.70)),**props)
    def portal(self,p):
        if any(math.dist(p,(q[0]+CENTER[0],-q[2],q[1]))<1 for q in self.probes['portals']):return
        self.marker('info_tribes_navigation',p);self.probes['portals'].append(game(p))
    def original_height(self,x,y):
        gx=x/8+128;gy=y/8+128;cx=math.floor(gx);cy=math.floor(gy);u=gx-cx;v=gy-cy;m=self.heightmap
        a,b,c,d=m[cy%256,cx%256],m[cy%256,(cx+1)%256],m[(cy+1)%256,(cx+1)%256],m[(cy+1)%256,cx%256]
        if (cx+cy)%2:return a+u*(b-a)+v*(d-a) if u+v<=1 else c+(1-v)*(b-c)+(1-u)*(d-c)
        return a+u*(b-a)+v*(c-b) if u>=v else a+u*(c-d)+v*(d-a)
    def terrain_height(self,x,y):
        # On adaptive-grid boundaries, both sides share the coarse straight edge.
        x0=math.floor((x-EXTENT[0])/32)*32+EXTENT[0];y0=math.floor((y-EXTENT[1])/32)*32+EXTENT[1]
        step=self.grids.get((x0,y0),32)
        if x==x0:
            coarse=max(step,self.grids.get((x0-32,y0),step));start=math.floor((y-y0)/coarse)*coarse+y0
            if y!=start:return self.original_height(x,start)+(self.original_height(x,start+coarse)-self.original_height(x,start))*(y-start)/coarse
        if y==y0:
            coarse=max(step,self.grids.get((x0,y0-32),step));start=math.floor((x-x0)/coarse)*coarse+x0
            if x!=start:return self.original_height(start,y)+(self.original_height(start+coarse,y)-self.original_height(start,y))*(x-start)/coarse
        return self.original_height(x,y)
    def height(self,x,y):
        x0=math.floor((x-EXTENT[0])/32)*32+EXTENT[0];y0=math.floor((y-EXTENT[1])/32)*32+EXTENT[1];s=self.grids.get((x0,y0),32)
        x0+=math.floor((x-x0)/s)*s;y0+=math.floor((y-y0)/s)*s;u=(x-x0)/s;v=(y-y0)/s
        a,b,c,d=[self.terrain_height(px,py) for px,py in [(x0,y0),(x0+s,y0),(x0+s,y0+s),(x0,y0+s)]]
        if (round(x0/s)+round(y0/s))%2:return a+u*(b-a)+v*(d-a) if u+v<=1 else c+(1-v)*(b-c)+(1-u)*(d-c)
        return a+u*(b-a)+v*(c-b) if u>=v else a+u*(c-d)+v*(d-a)
    def terrain(self):
        for (cx,cy),step in self.grids.items():
            for y in range(cy,cy+32,step):
                for x in range(cx,min(cx+32,EXTENT[2]),step):
                    if ((y+1024)//8)*256+(x+1024)//8 in self.holes:continue
                    corners=[(a,b,self.terrain_height(a,b)) for a,b in [(x,y),(min(x+step,EXTENT[2]),y),(min(x+step,EXTENT[2]),y+step),(x,y+step)]]
                    for face in ([[0,1,3],[1,2,3]] if (round(x/step)+round(y/step))%2 else [[0,1,2],[0,2,3]]):
                        top=[corners[i] for i in face];n=np.cross(np.subtract(top[1],top[0]),np.subtract(top[2],top[0]));slope=abs(n[2])/np.linalg.norm(n)
                        texture=ROCK if slope<.48 else SNOW
                        # Torque terrain is a surface, with rooms beneath it.
                        # Deep solid prisms would seal the underground passages.
                        near_base=min(math.hypot(x-f[0],y-f[1]) for f in self.flags)<140
                        if near_base:
                            bottom=[(a,b,c-1) for a,b,c in top];vertices=bottom+top
                            self.convex(vertices,[[0,2,1],[0,1,4,3],[1,2,5,4],[2,0,3,5],[3,4,5]],texture)
                        else:self.triangle(top,texture)
                        self.terrain_triangles.append(top)
        x0,y0,x1,y1=EXTENT
        self.block((x0-2,y0-2,-28),(x1+2,y1+2,-24),ROCK,detail=False)
        self.block((x0-2,y0-2,360),(x1+2,y1+2,362),SKY,detail=False)
        for lo,hi in [((x0-2,y0-2,-24),(x0,y1+2,360)),((x1,y0-2,-24),(x1+2,y1+2,360)),((x0,y0-2,-24),(x1,y0,360)),((x0,y1,-24),(x1,y1+2,360))]:self.block(lo,hi,SKY,detail=False)
        self.marker('info_playable_bounds',(*CENTER,168),size='1500 384 1388')
    def material(self,name):
        n=name.upper()
        if 'SNOW' in n:return SNOW
        if 'LIG' in n or 'BOR' in n or 'COL' in n or 'THRESH' in n:return TRIM
        if 'FLO' in n or 'GRATE' in n or 'SPEC' in n:return FLOOR
        return WALL
    def building(self,row):
        if row['interiorFile']=='stowr4.dif':
            self.remote_tower(row);return
        name=Path(row['interiorFile']).stem;d=self.models[name];rotation,origin=transform(row);points=np.array(d['points']);world=points@rotation.T+origin
        first_brush=len(self.detail)
        # Convex hulls preserve passage openings and the original sloping roofs.
        # Shared/coplanar render fragments become a single brush plane.
        hulls=d['convexHulls']
        for hi,h in enumerate(hulls):
            ids=d['hullIndices'][h['hullStart']:h['hullStart']+h['hullCount']];vertices=points[ids];centre=vertices.mean(axis=0);rows=[]
            end=hulls[hi+1]['planeStart'] if hi+1<len(hulls) else len(d['hullPlaneIndices'])
            surfaces=[d['nullSurfaces'][i&0x7fffffff] if i&0x80000000 else d['surfaces'][i] for i in d['hullSurfaceIndices'][h['surfaceStart']:h['surfaceStart']+h['surfaceCount']]]
            for index in d['hullPlaneIndices'][h['planeStart']:end]:
                plane=d['planes'][index&0x7fff];normal=np.array(d['normals'][plane['normalIndex']]);dist=plane['distance']
                candidates=vertices[np.abs(vertices@normal+dist)<.003]
                if len(candidates)<3:continue
                facecentre=candidates.mean(axis=0);a=candidates[0]
                # Choose a stable non-collinear triple from the plane's hull corners.
                b=max(candidates,key=lambda p:np.linalg.norm(p-a));c=max(candidates,key=lambda p:np.linalg.norm(np.cross(b-a,p-a)))
                if np.linalg.norm(np.cross(b-a,c-a))<1e-6:continue
                poly=np.array([a,b,c]);n=np.cross(b-a,c-a)
                if n@(facecentre-centre)<0:poly=poly[::-1]
                face=next((s for s in surfaces if s['planeIndex']&0x7fff==index&0x7fff and 'textureIndex' in s),None)
                material=d['materialNames'][face['textureIndex']] if face else ''
                tex=self.material(material)
                if 'LIG' in material.upper():tex='ind_dp01_red1' if 'Team1' in row['parents'] else 'ind_dp01_blu1'
                rows.append(self.face([quake(p) for p in poly@rotation.T+origin],tex))
            if len(rows)>=4:self.detail.append('{\n'+'\n'.join(rows)+'\n}');self.interior_hulls+=1
        if name=='smisc3':
            # The original raised turret pad is only a thin cap. Adaptive
            # terrain can sit metres below it; give its entire footprint a
            # solid foundation while preserving the authored firing height.
            samples=[rotation@np.array([x,y,0])+origin for x in np.linspace(-4,4,9) for y in np.linspace(-4.5,4.5,10)]
            bottom=min(self.height(p[0],p[1]) for p in samples)-.5
            angle=math.atan2(rotation[1,0],rotation[0,0])
            self.block((-4,-4.5,bottom-origin[2]),(4,4.5,.08),WALL,origin,angle)
            corners=[rotation@np.array([x,y,.03125])+origin for x,y in [(-4,-4.5),(4,-4.5),(4,4.5),(-4,4.5)]]
            self.probes.setdefault('foundations',[]).append(dict(team=0 if 'Team1' in row['parents'] else 1,bottom=bottom,corners=[game(p) for p in corners]))
        # Separate static BSP models keep tiny indoor planes from splitting the
        # entire kilometre-wide terrain tree. This is native BSP29 func_wall.
        self.building_models.append('{\n"classname" "func_wall"\n'+'\n'.join(self.detail[first_brush:])+'\n}')
        del self.detail[first_brush:]
        # Walkable surface samples supply floor candidates and indoor nav portals.
        floor_start=len(self.building_floors)
        for surface in d['surfaces']:
            index=surface['planeIndex'];plane=d['planes'][index&0x7fff];normal=np.array(d['normals'][plane['normalIndex']])*(-1 if index&0x8000 else 1)
            if (rotation@normal)[2]<.7:continue
            winding=d['windings'][surface['windingStart']:surface['windingStart']+surface['windingCount']];polygon=world[winding]
            if len(polygon)>=3:self.building_floors.append(polygon)
        self.floor_groups.append(self.building_floors[floor_start:])
        top=max(self.building_floors[floor_start:],key=lambda p:p[:,2].mean())
        self.roofs[(name,0 if 'Team1' in row['parents'] else 1)]=top.mean(axis=0)
        team=0 if 'Team1' in row['parents'] else 1
        self.probes['landmarks'].append(dict(kind=name,team=team,position=game(origin)))
    def remote_tower(self,row):
        # The retail remote tower spends thousands of faces on inset trim.
        # Rebuild its four-pylon silhouette and two levels with broad solids;
        # retain the original transform and five-metre inventory floor.
        rotation,origin=transform(row);angle=math.atan2(rotation[1,0],rotation[0,0]);start=len(self.detail);floors=[]
        def box(lo,hi,t=WALL,floor=False):
            self.block(lo,hi,t,origin,angle)
            if floor:
                x,y,z=lo;X,Y,Z=hi;floors.append(np.array([(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)])@rotation.T+origin)
        box((-15,-38,3),(13,-10,5),FLOOR,True)
        for side in [-1,1]:
            x=-15 if side<0 else 11
            box((x,-38,5),(x+2,-29,14));box((x,-19,5),(x+2,-10,14));box((x,-29,12),(x+2,-19,14))
            y=-38 if side<0 else -12
            box((-15,y,5),(-6,y+2,14));box((4,y,5),(13,y+2,14));box((-6,y,12),(4,y+2,14))
        box((-16,-39,14),(14,-9,15),TRIM,True)
        for x in [-34,32]:
            for y in [-57,9]:
                box((x-8,y-8,-16),(x+8,y+8,28))
                box((x-11,y-11,28),(x+11,y+11,30),FLOOR,True)
                # Angular crown with clear side windows, keeping the T2 profile.
                for sx in [-1,1]:
                    for sy in [-1,1]:box((x+sx*8-1,y+sy*8-1,30),(x+sx*8+1,y+sy*8+1,37),TRIM)
                box((x-10,y-10,37),(x+10,y+10,39),WALL)
        for y in [-57,9]:
            box((-34,y-5,3),(32,y+5,5),FLOOR,True)
            box((-34,y-4,28),(32,y+4,30),FLOOR,True)
        for x in [-34,32]:
            box((x-5,-57,3),(x+5,9,5),FLOOR,True)
            box((x-4,-57,28),(x+4,9,30),FLOOR,True)
        # Lower crosswalks connect the independently powered inventory room.
        box((-34,-29,3),(32,-19,5),FLOOR,True)
        box((-6,-57,3),(4,9,5),FLOOR,True)
        box((-5,-28,15),(3,-20,32),WALL);box((-7,-30,32),(5,-18,34),TRIM,True)
        self.building_models.append('{\n"classname" "func_wall"\n'+'\n'.join(self.detail[start:])+'\n}');self.interior_hulls+=len(self.detail)-start;del self.detail[start:]
        self.building_floors.extend(floors);self.floor_groups.append(floors)
        self.probes['landmarks'].append(dict(kind='remote-tower',team=0 if 'Team1' in row['parents'] else 1,position=game(origin)))
    def floor(self,x,y,z,max_distance=8):
        candidates=[]
        for polygon in self.building_floors:
            if x<polygon[:,0].min()-.01 or x>polygon[:,0].max()+.01 or y<polygon[:,1].min()-.01 or y>polygon[:,1].max()+.01:continue
            # Plane interpolation; later compiled-collision acceptance is authoritative.
            a=polygon[0];normal=None
            for b,c in zip(polygon[1:],polygon[2:]):
                n=np.cross(b-a,c-a)
                if abs(n[2])>1e-5:normal=n;break
            if normal is None:continue
            height=a[2]-(normal[0]*(x-a[0])+normal[1]*(y-a[1]))/normal[2]
            if abs(height-z)<max_distance:candidates.append(height)
        return min(candidates,key=lambda h:abs(h-z)) if candidates else self.height(x,y)
    def equipment(self):
        for team in range(2):
            # Place marker on the physical flag stand floor rather than the T2 item's centre.
            f=self.flags[team];f=(f[0],f[1],self.floor(*f)+.06);self.flags[team]=f
            self.marker('item_flag_team'+str(team+1),f);self.probes['flags'].append(dict(team=team,position=game(f)))
            self.portal(f)
            records=[r for r in self.items if 'Team'+str(team+1) in r['parents']]
            stations=[r for r in records if r.get('dataBlock')=='StationInventory']
            for row in stations:
                x,y,z=map(float,row['position'].split());z=self.floor(x,y,z)+.06;tag=row.get('nameTag','')
                group='remote' if tag=='Remote Tower' else 'tower' if tag=='Base Tower' else 'base'
                angle=list(map(float,row.get('rotation','1 0 0 0').split()));yaw=angle[2]*angle[3]
                p=(x,y,z);self.marker('info_tribes_inventory',p,team=team,angle=yaw,power_group=group)
                self.probes['stations'].append(dict(team=team,kind='inventory',position=game(p),power_group=group));self.portal(p)
            for i,row in enumerate(r for r in records if r.get('dataBlock')=='GeneratorLarge'):
                x,y,z=map(float,row['position'].split());p=(x,y,self.floor(x,y,z)+.06)
                self.marker('info_tribes_portable_generator',p,team=team,power_group='base',targetname=f'base_{team}_{i}')
            # Broad ceiling fill inside the underground rooms, in BSP units.
            for row in stations:
                x,y,z=map(float,row['position'].split())
                self.ent('light',quake((x,y,z+4)),light=360,_color='.76 .84 1',wait='.3')
            for group in ['tower','remote']:
                station=next(r for r in self.probes['stations'] if r['team']==team and r['power_group']==group);p=station['position'];p=(p[0]+CENTER[0],-p[2],p[1])
                # Independent power on the roof, clear of the inventory landing.
                high=self.floor(p[0],p[1],p[2]+10,max_distance=18)
                solar=self.roofs[('stowr6',team)]+np.array([0,0,.06]) if group=='tower' else (p[0],p[1],high+.06)
                self.marker('info_tribes_solar',solar,team=team,power_group=group)
            for row in records:
                if row.get('dataBlock') not in ['TurretBaseLarge','SentryTurret','SensorLargePulse']:continue
                x,y,z=map(float,row['position'].split());p=(x,y,self.floor(x,y,z,max_distance=3)+.06)
                if row.get('dataBlock')=='SensorLargePulse':
                    self.marker('info_tribes_sensor',p,team=team,power_group='remote');continue
                if row.get('dataBlock')=='SentryTurret':
                    self.marker('info_tribes_turret',p,team=team,type='mini',power_group='remote');continue
                kind='missile' if row.get('initialBarrel')=='AABarrelLarge' else 'fusion'
                self.marker('info_tribes_turret',p,team=team,type=kind)
            pad=next(r for r in records if r.get('dataBlock')=='StationVehiclePad');rotation,origin=transform(pad)
            # The existing terminal places aircraft eight metres forward. Align
            # that frame with the original vehicle deck, leaving its centre clear.
            yaw=list(map(float,pad['rotation'].split()));yaw=yaw[2]*yaw[3]
            p=origin+np.array([8*math.sin(math.radians(yaw)),-8*math.cos(math.radians(yaw)),0])
            p[2]=self.floor(*origin)+.06
            self.marker('info_tribes_vehicle',p,team=team,angle=yaw)
            self.probes['stations'].append(dict(team=team,kind='vehicle',position=game(p)))
            # Original base roof landing gives all eight spawns clear outdoor exits.
            base=next(r for r in records if r.get('interiorFile')=='sbunk2.dif');rotation,origin=transform(base)
            for i,(x,y) in enumerate([(-29,-10),(-24,-10),(-19,-10),(-29,-16),(-24,-16),(-19,-16),(-24,-22),(-19,-22)]):
                p=origin+rotation@np.array([x,y,3.06]);p[2]=self.floor(*p)+.06
                self.marker('info_player_team'+str(team+1),p,angle=team*180);self.probes['spawns'].append(dict(team=team,position=game(p)))
                if team==0 and i==0:self.marker('info_player_start',p)
            for offset in [(-100,90,90),(60,-100,40)]:
                self.probes['views'].append(dict(name=f'base-{team}-{len(self.probes["views"])}',eye=game(origin+np.array(offset)),look=game(origin+np.array([-12,-10,0]))))
            gens=[np.array(list(map(float,r['position'].split()))) for r in records if r.get('dataBlock')=='GeneratorLarge'];p=np.mean(gens,axis=0)
            low=sorted(stations,key=lambda r:float(r['position'].split()[2]))[:2]
            eye=np.mean([np.array(list(map(float,r['position'].split()))) for r in low],axis=0)+np.array([0,0,2.2])
            self.probes['views'].append(dict(name=f'generator-{team}',eye=game(eye),look=game(p+np.array([0,0,2]))))
    def portals(self):
        surveyed=ROOT/'tools/katabatic/portals.json'
        if surveyed.exists():
            self.entities=[e for e in self.entities if e['classname']!='info_tribes_navigation'];self.probes['portals']=[]
            for x,y,z in json.loads(surveyed.read_text()):self.portal((x+CENTER[0],-z,y))
            return
        # Dense but bounded floor samples inside the true convex interiors.
        # Physics acceptance removes edge/ceiling candidates before cache baking.
        for group in self.floor_groups:
            candidates=[p for p in group if max(np.ptp(p[:,0]),np.ptp(p[:,1]))>=2]
            for index in np.linspace(0,len(candidates)-1,min(75,len(candidates)),dtype=int):
                centre=candidates[index].mean(axis=0)
                if self.height(centre[0],centre[1])>centre[2]+.2 and (((int((centre[1]+1024)//8)%256)*256+int((centre[0]+1024)//8)%256) not in self.holes):continue
                self.portal((centre[0],centre[1],centre[2]+.06))
    def routes(self):
        a,b=self.flags
        lanes=[('central-valley',[(a[0],a[1]),(180,-80),(30,35),(-120,130),(-300,220),(-430,320),(b[0],b[1])]),
               ('north-flank',[(a[0],a[1]),(365,45),(225,270),(45,420),(-200,520),(-400,550),(b[0],b[1])]),
               ('south-flank',[(a[0],a[1]),(190,-350),(-50,-380),(-290,-240),(-500,-70),(-680,200),(b[0],b[1])])]
        for name,points in lanes:
            samples=[]
            for a,b in zip(points,points[1:]):
                for i in range(max(1,math.ceil(math.dist(a,b)/4))):
                    t=i/max(1,math.ceil(math.dist(a,b)/4));x=a[0]+(b[0]-a[0])*t;y=a[1]+(b[1]-a[1])*t
                    if ((int((y+1024)//8)%256)*256+int((x+1024)//8)%256) in self.holes:continue
                    samples.append(game((x,y,self.height(x,y))))
            self.probes['routes'].append(dict(name=name,samples=samples,length=sum(math.dist(a,b) for a,b in zip(samples,samples[1:]))))
        self.probes['views'].append(dict(name='central-valley',eye=game((20,40,120)),look=game((-350,230,95))))
        self.probes['views'].append(dict(name='overview',eye=game((850,-1000,950)),look=game((-144,80,110))))
    def build(self):
        self.terrain()
        for row in self.items:
            if row.get('interiorFile','').removesuffix('.dif') in self.models:self.building(row)
        self.equipment();self.portals();self.routes()

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--compiler',type=Path,default=Path('/tmp/dust2-tools/ericw-tools-v0.18.1-Linux/bin'));parser.add_argument('--geometry-only',action='store_true');args=parser.parse_args()
    OUT.mkdir(exist_ok=True);(LOG/'build').mkdir(parents=True,exist_ok=True)
    arena=Katabatic();arena.build()
    world=dict(classname='worldspawn',message=arena.title,wad='katabatic.wad',_fpsloppa_bake='1',_fpsloppa_light_response='quake',_fpsloppa_atlas='4096',_lightmap_scale='32',_minlight='22',_sunlight='160',_sunlight2='65',_sun_mangle='120 -50 0',_phong='1',_phong_angle='65',worldtype='0')
    source='{\n'+fields(world)+'\n'+'\n'.join(arena.brushes)+'\n}\n{\n"classname" "func_detail"\n'+'\n'.join(arena.detail)+'\n}\n'+'\n'.join(arena.building_models)+'\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in arena.entities)+'\n'
    path=OUT/(ID+'.map');path.write_text(source);(OUT/'probes.json').write_text(json.dumps(arena.probes,indent=2)+'\n')
    bsp=ROOT/'maps'/(ID+'.bsp');bsp.with_suffix('.pts').unlink(missing_ok=True)
    commands=[('qbsp',['-noclip','-subdivide','1024','-wadpath',str(OUT),str(path),str(bsp)])]
    if not args.geometry_only:commands.extend([('vis',['-threads','3',str(bsp)]),('light',['-threads','3','-extra','-lmscale','32','-bspxlit','-dirt','1',str(bsp)])])
    for exe,flags in commands:
        print('COMPILING',exe,flush=True)
        with (LOG/'build'/(exe+'.log')).open('w') as log:subprocess.run([str(args.compiler/exe),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
    raw=bsp.read_bytes();assert struct.unpack_from('<i',raw)[0]==29 and len(raw)<25_000_000
    assert not bsp.with_suffix('.pts').exists(),'Map leaked'
    parts=[struct.unpack_from('<ii',raw,4+i*8) for i in range(15)];stats=dict(faces=parts[7][1]//20,vertices=parts[3][1]//12,nodes=parts[5][1]//24,leaves=parts[10][1]//28)
    assert stats['faces']<65536 and stats['nodes']<32768 and stats['leaves']<32768
    report=dict(id=ID,title=arena.title,bsp_sha256=sha(bsp),bytes=len(raw),bsp_version=29,terrain_steps_m=[8,16,32],terrain_extent_m=[1504,1408],detail_brushes=len(arena.detail),interior_hulls=arena.interior_hulls,full_vis=not args.geometry_only,flag_separation_m=math.dist(*arena.flags),team_spawns=[8,8],navigation_portals=len(arena.probes['portals']),**stats)
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    catalog=ROOT/'deathmatch/maps/manifest.json';rows=json.loads(catalog.read_text());rows=[r for r in rows if r['id']!=ID]
    rows.append(dict(id=ID,title=arena.title,path=f'res://maps/{ID}.bsp',scene=f'res://maps/cache/{ID}.scn',sha256=report['bsp_sha256'],size=len(raw),modes=['st'],source_name='st_katabatic',distribution='optional',experimental=True,objectives={['red','blue'][r['team']]:r['position'] for r in arena.probes['flags']}));catalog.write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
