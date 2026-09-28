#!/usr/bin/env python3
"""Rebuild Raindance's terrain and landmarks as editable BSP29 brushes.

Shared brush/WAD implementation: tools/stonehenge/build.py. Mission anchors and
heightfield are study inputs, not shipped original Tribes interior assets.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import shutil
import struct
import subprocess
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from stonehenge.build import Stonehenge, Arena, quake as stone_quake, wad_records
from stonehenge.build import GRASS, ROCK, WALL, TRIM, FLOOR, DARK, SKY
WALL = 'ind_w02_grey1'
FLOOR = 'ind_dp01_grey1'
ID = 'ctf_raindance'
OUT = ROOT / 'maps/Raindance'
LOG = ROOT / 'test-results/st-raindance/build'
EXTENT = (-720, -128, 144, 800)
CENTER = (-288, 336)
BASES = [(-256, 24, 19), (-344, 611.397, 26.4375)]
FLAGS = [(-221.812, 21.7952, 38.7137), (-379.16, 640.783, 52.8173)]
TOWERS = [(-221.813, 14.9913, 15.6663), (-379.024, 648.392, 29.7689)]

def game(p): return [round(p[0]-CENTER[0],5), round(p[2],5), round(CENTER[1]-p[1],5)]
def quake(p): return ((p[1]-CENTER[1])*32,(CENTER[0]-p[0])*32,p[2]*32)
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def local(p,team):
    x,y,z=p;o=BASES[team];sign=1 if team==0 else -1
    return (o[0]+sign*x,o[1]+sign*y,o[2]+z)

class Raindance(Stonehenge):
    def __init__(self,step=16):
        Arena.__init__(self,ID,'Raindance | Tribes CTF')
        self.detail=[];self.step=step;self.heights={}
        self.heightmap=np.array(Image.open(OUT/'reference-heightmap.png'),dtype=float)
        assert self.heightmap.shape==(257,257)
        self.probes=dict(spawns=[],flags=[],stations=[],landmarks=[],routes=[],views=[],portals=[],boundary=dict(min=[-428,-24,-460],max=[428,320,460]))
    def convex(self,vertices,faces,texture,detail=True):
        # Reuse Stonehenge's convex brush writer with a translated authoring origin.
        super().convex([(x-CENTER[0]+384,y-CENTER[1]+416,z) for x,y,z in vertices],faces,texture,detail)
    def block(self,lo,hi,texture=WALL,origin=None,angle=0,detail=True):
        super().block(lo,hi,texture,origin,angle,detail)
    def marker(self,kind,p,**props):self.ent(kind,quake((p[0],p[1],p[2]+.70)),**props)
    def original_height(self,x,y):
        col=((x+3072)/8)%256;row=(256-((y+3072)/8)%256)%256
        i,j=int(row),int(col);u,v=row-i,col-j;m=self.heightmap
        value=m[i,j]*(1-u)*(1-v)+m[i+1,j]*u*(1-v)+m[i,j+1]*(1-u)*v+m[i+1,j+1]*u*v
        h=value*70/65535+6.5
        # Original bases cut the terrain. Leave a dry, traversable indoor floor
        # and blend to the source terrain outside the bunker footprint.
        for team,o in enumerate(BASES):
            sign=1 if team==0 else -1;lx=(x-o[0])*sign;ly=(y-o[1])*sign
            d=max(abs(lx)-22,abs(ly+20)-32,0)
            if d<16:
                floor=o[2]-2
                h=min(h,floor+(max(h,floor)-floor)*d/16)
        return h
    def height(self,x,y):
        x0=math.floor((x-EXTENT[0])/self.step)*self.step+EXTENT[0]
        y0=math.floor((y-EXTENT[1])/self.step)*self.step+EXTENT[1]
        u,v=(x-x0)/self.step,(y-y0)/self.step
        a,b,c,d=[self.vertex_height(px,py) for px,py in [(x0,y0),(x0+self.step,y0),(x0+self.step,y0+self.step),(x0,y0+self.step)]]
        if ((x0-EXTENT[0])//self.step+(y0-EXTENT[1])//self.step)%2:return a+u*(b-a)+v*(d-a) if u+v<=1 else c+(1-v)*(b-c)+(1-u)*(d-c)
        return a+u*(b-a)+v*(c-b) if u>=v else a+u*(c-d)+v*(d-a)
    def portal(self,p):
        self.marker('info_tribes_navigation',p);self.probes['portals'].append(game(p))
    def terrain(self):
        x0,y0,x1,y1=EXTENT
        for y in range(y0,y1,self.step):
            for x in range(x0,x1,self.step):
                corners=[(a,b,self.vertex_height(a,b)) for a,b in [(x,y),(x+self.step,y),(x+self.step,y+self.step),(x,y+self.step)]]
                for face in ([[0,1,3],[1,2,3]] if ((x-x0)//self.step+(y-y0)//self.step)%2 else [[0,1,2],[0,2,3]]):
                    top=[corners[i] for i in face];n=np.cross(np.subtract(top[1],top[0]),np.subtract(top[2],top[0]))
                    self.triangle(top,ROCK if abs(n[2])/np.linalg.norm(n)<.53 else GRASS)
        self.block((x0-2,y0-2,-28),(x1+2,y1+2,-24),ROCK,detail=False)
        self.block((x0-2,y0-2,320),(x1+2,y1+2,322),SKY,detail=False)
        for lo,hi in [((x0-2,y0-2,-24),(x0,y1+2,320)),((x1,y0-2,-24),(x1+2,y1+2,320)),((x0,y0-2,-24),(x1,y0,320)),((x0,y1,-24),(x1,y1+2,320))]:self.block(lo,hi,SKY,detail=False)
        self.marker('info_playable_bounds',(*CENTER,148),size='856 344 920')
    def base(self,team):
        o=BASES[team];a=team*math.pi;paint='ind_dp01_red1' if team==0 else 'ind_dp01_blu1'
        def box(lo,hi,t=WALL):self.block(lo,hi,t,o,a)
        # Low, wide, single-room bunker with large front entry and sloped roof.
        box((-19,-46,-2),(19,5,-1),FLOOR)
        box((-19,-46,-1),(-17,1,15));box((17,-46,-1),(19,1,15));box((-17,-46,-1),(17,-44,15))
        box((-17,-1,-1),(-7,1,10));box((7,-1,-1),(17,1,10));box((-7,-1,8.5),(7,1,10))
        # Sloping outer roof strip joins the flat spawn/sensor platform.
        box((-19,-46,15),(19,-10,16))
        verts=[(-19,-10,15),(19,-10,15),(19,5,9.5),(-19,5,9.5),(-19,-10,16),(19,-10,16),(19,5,10.5),(-19,5,10.5)]
        self.convex([local(p,team) for p in verts],[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],WALL)
        for side in [-1,1]:
            for y in [-42,-28,-14]:
                pts=[(side*17,y-1,-1),(side*23,y-1,-1),(side*18,y-1,14),(side*17,y-1,14)]
                self.convex([local(p,team) for p in pts+[(x,yy+2,z) for x,yy,z in pts]],[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],TRIM)
        for y in [-45.9,-.9]:
            box((-17,y,8),(-7,y+.18,8.45),paint);box((7,y,8),(17,y+.18,8.45),paint)
        for x in [-16.9,16.7]:
            box((x,-44,2),(x+.2,-1,2.4),TRIM);box((x,-44,8),(x+.2,-1,8.4),TRIM)
        # Equipment pads have open approach space; generator is a shootable brush.
        for kind,x in [('inventory',10),('ammo',-10)]:
            p=local((x,-29,-.94),team);self.marker('info_tribes_'+kind,p,team=team,angle=team*180)
            self.probes['stations'].append(dict(team=team,kind=kind,position=game(p)))
        box((-3,-40,-1),(3,-38,2),TRIM)
        self.marker('info_tribes_generator',local((0,-39,-.94),team),team=team)
        # Indoor portal chains keep graph sampling from choosing the roof.
        for p in [(0,-34,-.94),(5,-35,-.94),(-10,-20,-.94),(10,-20,-.94),(0,-20,-.94),(0,-7,-.94),(0,3,-.94),(0,12,-.94)]:self.portal(local(p,team))
        for x,y in [(-10,-37),(0,-37),(10,-37),(-10,-26),(0,-26),(10,-26),(-10,-16),(10,-16)]:
            p=local((x,y,16.06),team);self.marker('info_player_team'+str(team+1),p,angle=team*180)
            self.probes['spawns'].append(dict(team=team,position=game(p)))
            if team==0 and x==-10 and y==-37:self.marker('info_player_start',p)
        self.ent('light',quake(local((0,-22,9),team)),light=440,_color='.77 .86 1',delay=2)
        self.marker('info_tribes_sensor',local((-11,-35,16),team),team=team)
        self.marker('info_tribes_turret',local((11,-13,16),team),team=team,type='fusion')
        # Narrow tapered tower with an open shelf; the shaft remains behind
        # the flag, so a skier can sweep through without colliding with it.
        t=TOWERS[team];f=FLAGS[team];ta=a;deck=f[2]-.05-t[2]
        def tb(lo,hi,tex=WALL):self.block(lo,hi,tex,t,ta)
        shaft=[(-5,-5,-8),(5,-5,-8),(5,3,-8),(-5,3,-8),(-3.4,-3.4,42),(3.4,-3.4,42),(3.4,1.4,42),(-3.4,1.4,42)]
        c,s=math.cos(ta),math.sin(ta)
        self.convex([(t[0]+c*x-s*y,t[1]+s*x+c*y,t[2]+z) for x,y,z in shaft],[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],WALL)
        tb((-9,3,deck-.6),(9,12,deck),FLOOR);tb((-9,2.8,deck+6),(9,12,deck+6.5))
        for x in [-9,8.3]:tb((x,3,deck),(x+.7,4,deck+6))
        tb((-9,11.8,deck-.55),(9,12.05,deck-.15),paint)
        tb((-3.6,-3.6,38),(3.6,1.6,38.45),paint)
        self.marker('item_flag_team'+str(team+1),f)
        self.probes['flags'].append(dict(team=team,position=game(f)))
        self.probes['landmarks'].append(dict(kind='base',team=team,position=game(o)))
        for x in [-7,0,7]:
            p=(t[0]+c*x-s*8,t[1]+s*x+c*8,t[2]+deck+.06);self.portal(p)
        self.probes['views'].append(dict(name=('red' if team==0 else 'blue')+'-base',eye=game(local((80,100,65),team)),look=game(local((10,-6,15),team))))
        self.probes['views'].append(dict(name=('red' if team==0 else 'blue')+'-bunker',eye=game(local((0,-2,3),team)),look=game(local((0,-34,2),team))))
        # Retain vehicle pad landmark; vehicle spawning is deliberately deferred.
        vp=[(-289.067,29.9708,22.5064),(-285.722,618.696,35.1526)][team]
        self.block((-10,-10,-14),(10,10,0),WALL,vp,a);self.block((-10,-10,0),(10,10,.4),TRIM,vp,a)
    def landmarks(self):
        # Original expbridge anchor, spanning the central gulch. Open below.
        p=(-291.563,296.679,41);a=-.279231
        self.block((-7,-106,-1.2),(7,106,0),FLOOR,p,a)
        for y in [-76,76]:self.block((-6,y-4,-34),(6,y+4,-1.2),WALL,p,a)
        for x in [-7,6.5]:self.block((x,-106,0),(x+.5,106,.8),TRIM,p,a)
        self.probes['landmarks'].append(dict(kind='central-bridge',position=game(p)))
        self.probes['views'].append(dict(name='central-bridge',eye=game((-135,165,110)),look=game(p)))
        # Forward missile pedestals and bridge plasma turrets, from mission data.
        for team,p in [(0,(-320.75,130.918,43.6798)),(1,(-318.084,494.067,37.051)),(0,(-258.322,190.093,55.5015)),(1,(-317.667,385.235,52.9242))]:
            ground=self.height(p[0],p[1]);top=max(p[2],ground+2)
            self.block((p[0]-6,p[1]-6,ground-3),(p[0]+6,p[1]+6,top),WALL)
            self.marker('info_tribes_turret',(p[0],p[1],top),team=team,type='missile' if p[1] in [130.918,494.067] else 'fusion')
        self.probes['views'].append(dict(name='overview',eye=game((270,-200,650)),look=game((*CENTER,35))))
    def routes(self):
        lanes=[('west-valley',[(-340,30),(-400,180),(-440,300),(-430,420),(-420,560),(-385,625)]),('east-valley',[(-190,45),(-200,200),(-150,320),(-170,450),(-270,560),(-320,610)]),('midfield',[(-260,80),(-280,180),(-320,260),(-340,350),(-330,460),(-340,550)])]
        for name,waypoints in lanes:
            samples=[]
            for start,end in zip(waypoints,waypoints[1:]):
                n=math.ceil(math.dist(start,end)/2)
                for k in range(n):
                    t=k/n;x=start[0]+(end[0]-start[0])*t;y=start[1]+(end[1]-start[1])*t;samples.append(game((x,y,self.height(x,y))))
            self.probes['routes'].append(dict(name=name,samples=samples,length=sum(math.dist(a,b) for a,b in zip(samples,samples[1:]))))
    def build(self):self.terrain();self.base(0);self.base(1);self.landmarks();self.routes()

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--compiler',type=Path,required=True);parser.add_argument('--geometry-only',action='store_true');args=parser.parse_args()
    OUT.mkdir(exist_ok=True);LOG.mkdir(parents=True,exist_ok=True)
    arena=Raindance();arena.build()
    world=dict(classname='worldspawn',message=arena.title,wad='raindance.wad',_fpsloppa_bake='1',_fpsloppa_atlas='4096',_minlight='40',_sunlight='95',_sunlight2='65',_sun_mangle='120 -50 0',_phong='1',_phong_angle='75',worldtype='0')
    def fields(d):return '\n'.join(f'"{k}" "{v}"' for k,v in d.items())
    source='{\n'+fields(world)+'\n'+'\n'.join(arena.brushes)+'\n}\n{\n"classname" "func_detail"\n'+'\n'.join(arena.detail)+'\n}\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in arena.entities)+'\n'
    names=set(re.findall(r'\) (\S+) 0 0 0 [\d.]+ [\d.]+',source));assert names<=wad_records(OUT/'raindance.wad').keys()
    for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt']:shutil.copyfile(ROOT/'maps/Pressureworks'/name,OUT/name)
    path=OUT/(ID+'.map');path.write_text(source);(OUT/'probes.json').write_text(json.dumps(arena.probes,indent=2)+'\n')
    bsp=ROOT/'maps'/(ID+'.bsp');bsp.with_suffix('.pts').unlink(missing_ok=True)
    commands=[('qbsp',['-noclip','-subdivide','512','-wadpath',str(OUT),str(path),str(bsp)])]
    if not args.geometry_only:commands += [('vis',['-threads','4',str(bsp)]),('light',['-threads','4','-extra','-bspxlit','-dirt','1',str(bsp)])]
    for exe,flags in commands:
        print('COMPILING',exe,flush=True)
        with (LOG/(exe+'.log')).open('w') as log:subprocess.run([str(args.compiler/exe),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
    raw=bsp.read_bytes();assert struct.unpack_from('<i',raw)[0]==29 and len(raw)<25_000_000
    assert not bsp.with_suffix('.pts').exists(),'Map leaked'
    parts=[struct.unpack_from('<ii',raw,4+i*8) for i in range(15)]
    stats=dict(faces=parts[7][1]//20,vertices=parts[3][1]//12,nodes=parts[5][1]//24,leaves=parts[10][1]//28)
    assert stats['faces']<65536 and stats['nodes']<32768 and stats['leaves']<32768
    report=dict(id=ID,title=arena.title,bsp_sha256=digest(bsp),bytes=len(raw),bsp_version=29,terrain_step_m=16,terrain_extent_m=[864,928],terrain_elevation_m=[min(arena.heights.values()),max(arena.heights.values())],detail_brushes=len(arena.detail),full_vis=not args.geometry_only,flag_separation_m=math.dist(*[r['position'] for r in arena.probes['flags']]),team_spawns=[8,8],navigation_portals=len(arena.probes['portals']),**stats)
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    catalog=ROOT/'deathmatch/maps/manifest.json';rows=json.loads(catalog.read_text());rows=[r for r in rows if r['id']!=ID]
    rows.append(dict(id=ID,title=arena.title,path=f'res://maps/{ID}.bsp',scene=f'res://maps/cache/{ID}.scn',sha256=report['bsp_sha256'],size=len(raw),modes=['st'],source_name='st_raindance',distribution='optional',experimental=True,objectives={['red','blue'][r['team']]:r['position'] for r in arena.probes['flags']}));catalog.write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
