"""Build an editable BSP29 Stonehenge terrain/layout study for the Tribes loadout.

Coordinates inside this generator are Tribes XY/Z-up metres. The authoring crop
retains the original terrain orientation and asymmetric base elevations. See
maps/Stonehenge/README.md for reference provenance and reconstruction limits.
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
from generate_tf_maps import Arena
from pressureworks.build import materials, wad_records

ID = 'ctf_stonehenge'
OUT = ROOT / 'maps/Stonehenge'
LOG = ROOT / 'test-results/stonehenge'
EXTENT = (32, 64, 736, 768)
GRASS = 'grass'
ROCK = 'med_rock4'
WALL = 'ind_brk01_gry1'
TRIM = 'metal_iron1_01'
FLOOR = 'med_flat5a'
DARK = 'ind_w02_blk1'
SKY = 'sky_star'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def game(p):
    return [round(p[0] - 384, 5), round(p[2], 5), round(416 - p[1], 5)]


def quake(p):
    # Match the project's inverse BSP importer rotation, 32 Quake units / metre.
    return ((p[1] - 416) * 32, (384 - p[0]) * 32, p[2] * 32)


class Stonehenge(Arena):
    def __init__(self, step=16):
        super().__init__(ID, 'Stonehenge | Tribes CTF')
        self.detail = []
        self.step = step
        self.ref = json.loads((OUT / 'references.json').read_text())
        assert digest(OUT / 'reference-heightmap.png') == self.ref['heightmap_sha256']
        self.heightmap = np.array(Image.open(OUT / 'reference-heightmap.png'), dtype=float)
        self.probes = dict(spawns=[], flags=[], stations=[], landmarks=[], routes=[], views=[], boundary=dict(min=[-350,-24,-350],max=[350,320,350]))
        self.heights = {}

    def face(self, points, texture):
        # Broad terrain UVs also keep lightmap subdivision and BSP29 indices low.
        scale = 4 if texture in (GRASS, ROCK) else .5 if texture.startswith(('ind_', 'metal_')) else 1
        return ' '.join('( %.7f %.7f %.7f )' % p for p in reversed(points)) + f' {texture} 0 0 0 {scale} {scale}'

    def convex(self, vertices, faces, texture, detail=True):
        pts = [np.array(p) for p in vertices]
        centre = np.mean(pts, axis=0)
        rows = []
        for face in faces:
            poly = [pts[i] for i in face]
            normal = np.cross(poly[1] - poly[0], poly[2] - poly[0])
            if normal.dot(np.mean(poly, axis=0) - centre) < 0:
                poly.reverse()
            rows.append(self.face([quake(p) for p in poly[:3]], texture))
        (self.detail if detail else self.brushes).append('{\n' + '\n'.join(rows) + '\n}')

    def block(self, lo, hi, texture=WALL, origin=None, angle=0, detail=True):
        x, y, z = lo
        X, Y, Z = hi
        assert X > x and Y > y and Z > z
        pts = [(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)]
        if origin is not None:
            c, s = math.cos(angle), math.sin(angle)
            pts = [(origin[0]+c*a-s*b, origin[1]+s*a+c*b, origin[2]+h) for a,b,h in pts]
        self.convex(pts, [[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]], texture, detail)

    def triangle(self, top, texture):
        self.convex([(p[0],p[1],-24) for p in top] + top,
                    [[0,1,2],[3,4,5],[0,1,4,3],[1,2,5,4],[2,0,3,5]], texture)

    def original_height(self, x, y):
        col = ((x + 3072) / 8) % 256
        row = 256 - ((y + 3072) / 8) % 256
        i, j = int(row), int(col)
        u, v = row - i, col - j
        i, j = i % 256, j % 256
        m = self.heightmap
        value = m[i,j]*(1-u)*(1-v)+m[i+1,j]*u*(1-v)+m[i,j+1]*(1-u)*v+m[i+1,j+1]*u*v
        return value * 170 / 65535 - 6.5

    def height(self, x, y):
        # Match the exact brush triangles, including the alternating diagonal.
        x0 = math.floor((x - EXTENT[0]) / self.step) * self.step + EXTENT[0]
        y0 = math.floor((y - EXTENT[1]) / self.step) * self.step + EXTENT[1]
        u, v = (x-x0)/self.step, (y-y0)/self.step
        h00, h10, h11, h01 = [self.vertex_height(a,b) for a,b in [(x0,y0),(x0+self.step,y0),(x0+self.step,y0+self.step),(x0,y0+self.step)]]
        if ((x0-EXTENT[0])//self.step+(y0-EXTENT[1])//self.step) % 2:
            return h00+u*(h10-h00)+v*(h01-h00) if u+v<=1 else h11+(1-v)*(h10-h11)+(1-u)*(h01-h11)
        return h00+u*(h10-h00)+v*(h11-h10) if u>=v else h00+u*(h11-h01)+v*(h01-h00)

    def vertex_height(self, x, y):
        if (x,y) not in self.heights:
            # Quantized to 1/32 metre, shared by every adjacent brush.
            self.heights[x,y] = round(self.original_height(x,y)*32)/32
        return self.heights[x,y]

    def marker(self, kind, p, **props):
        self.ent(kind, quake((p[0], p[1], p[2]+.70)), **props)

    def terrain(self):
        x0,y0,x1,y1 = EXTENT
        for y in range(y0,y1,self.step):
            for x in range(x0,x1,self.step):
                corners=[(a,b,self.vertex_height(a,b)) for a,b in [(x,y),(x+self.step,y),(x+self.step,y+self.step),(x,y+self.step)]]
                faces = [[0,1,3],[1,2,3]] if ((x-x0)//self.step+(y-y0)//self.step)%2 else [[0,1,2],[0,2,3]]
                for face in faces:
                    top=[corners[i] for i in face]
                    n=np.cross(np.subtract(top[1],top[0]),np.subtract(top[2],top[0]))
                    slope=math.degrees(math.acos(abs(n[2])/np.linalg.norm(n)))
                    self.triangle(top, ROCK if slope>58 else GRASS)
        # Sealed finite world. Boundary banks retain the sampled terrain; the
        # sky hull is well beyond the 600 m mission rectangle and jet routes.
        self.block((x0-2,y0-2,-28),(x1+2,y1+2,-24),ROCK,detail=False)
        self.block((x0-2,y0-2,320),(x1+2,y1+2,322),SKY,detail=False)
        for lo,hi in [((x0-2,y0-2,-24),(x0,y1+2,320)),((x1,y0-2,-24),(x1+2,y1+2,320)),((x0,y0-2,-24),(x1,y0,320)),((x0,y1,-24),(x1,y1+2,320))]:
            self.block(lo,hi,SKY,detail=False)

        self.marker('info_playable_bounds',(384,416,148),size='700 344 700')

    def base(self, team):
        # Recovered tank3 and tank14 anchors; interior dimensions are rebuilt.
        tanks=[o for o in self.ref['objects'] if o.get('fileName','').startswith('tank3.')]
        towers=[o for o in self.ref['objects'] if o.get('fileName','').startswith('tank14.')]
        flags=[o for o in self.ref['objects'] if o.get('dataBlock')=='flag']
        main=tanks[team];tower=towers[team]
        origin=tuple(map(float,main['position'].split()));angle=float(main['rotation'].split()[2])
        paint='ind_dp01_red1' if team==0 else 'ind_dp01_blu1'
        def local(p):
            c,s=math.cos(angle),math.sin(angle);x,y,z=p
            return (origin[0]+c*x-s*y,origin[1]+s*x+c*y,origin[2]+z)
        def box(lo,hi,t=WALL):self.block(lo,hi,t,origin,angle)
        # Battered concrete bunker, walkable roof, three open upper entries.
        low=[(-21,-18,0),(21,-18,0),(21,18,0),(-21,18,0)]
        high=[(-17,-14,33.5),(17,-14,33.5),(17,14,33.5),(-17,14,33.5)]
        self.convex([local(p) for p in low+high],[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],WALL)
        box((-18,-15,33.5),(18,15,34),FLOOR)
        box((-18,-15,39.5),(18,15,40),FLOOR)
        for x in [-18,17]:
            box((x,-15,34),(x+1,-5,39.5));box((x,5,34),(x+1,15,39.5))
        for y in [-15,14]:
            box((-17,y,34),(-6,y+1,39.5));box((6,y,34),(17,y+1,39.5))
        for x in [-17.4,16.9]:box((x,-14.7,37.2),(x+.5,14.7,37.65),paint)
        for y in [-15.05,14.6]:
            box((-17.4,y,37.2),(-6,y+.45,37.65),paint);box((6,y,37.2),(17.4,y+.45,37.65),paint)
        # Recessed inventory alcoves and generator leave a wide through route.
        for x in [-12,12]:
            box((x-2,8,34),(x+2,11,36),TRIM)
            box((x-1.6,7.85,34.8),(x+1.6,8,35.7),paint)
            p=local((x,6,34.05));self.marker('info_tribes_inventory',p,team=team,angle=math.degrees(angle)+180)
            self.probes['stations'].append(dict(team=team,position=game(p)))
        box((-3,-11,34),(3,-8,37),TRIM);box((-2.7,-11.15,35), (2.7,-11,36),paint)
        self.marker('info_tribes_generator',local((0,-9,34.05)),team=team)
        for i,(x,y,h) in enumerate([(-10,-5,34),(-10,0,34),(10,-5,34),(10,0,34),(-11,-8,40),(11,-8,40),(-11,8,40),(11,8,40)]):
            p=local((x,y,h+.06));self.marker('info_player_team'+str(team+1),p,angle=math.degrees(angle)-(90 if x>0 else -90))
            self.probes['spawns'].append(dict(team=team,position=game(p)))
            if team==0 and i==0:self.marker('info_player_start',p)
        self.ent('light',quake(local((0,0,37))),light=360,_color='.80 .87 1',delay=2)
        # Separate open flag gantry with roof sensor. Keep flag level free of
        # rails/steps: incoming cappers need a clear airborne interception path.
        t=tuple(map(float,tower['position'].split()));ta=float(tower['rotation'].split()[2])
        f=tuple(map(float,flags[team]['position'].split()));deck=f[2]-.05
        def tb(lo,hi,tex=WALL):self.block(lo,hi,tex,t,ta)
        for x in [-10,7]:
            for y in [-8,5]:tb((x,y,0),(x+3,y+3,39),WALL)
        tb((-11,-9,deck-t[2]-.6),(11,9,deck-t[2]),FLOOR)
        tb((-11,-9,39),(11,9,40),WALL)
        for y in [-9.1,8.7]:tb((-11,y,36.5),(11,y+.4,38),paint)
        tb((-2.3,-2.3,40),(2.3,2.3,42),TRIM)
        tb((-.45,-.45,42),(.45,.45,45),TRIM)
        tb((-3.7,-.6,44),(3.7,.6,46),paint)
        self.marker('info_tribes_sensor',(t[0],t[1],t[2]+40),team=team,angle=math.degrees(ta))
        p=(f[0],f[1],deck+.05);self.marker('item_flag_team'+str(team+1),p)
        self.probes['flags'].append(dict(team=team,position=game(p),reference=list(f)))
        self.probes['landmarks'].append(dict(kind='base',team=team,position=game(origin),flag=game(p)))
        self.probes['views'].append(dict(name=('red' if team==0 else 'blue')+'-base',eye=game(local((65,-85,65))),look=game(local((0,0,32)))))

    def monuments(self):
        tanks=[o for o in self.ref['objects'] if o.get('fileName','').startswith('tank7.')]
        for team,o in enumerate(tanks):
            p=tuple(map(float,o['position'].split()));a=float(o['rotation'].split()[2])
            for lo,hi in [((-9,-9,0),(9,9,65)),((-12,-12,64),(12,12,66))]:self.block(lo,hi,WALL,p,a)
            self.block((-4,-4,66),(4,4,68),TRIM,p,a)
            self.marker('info_tribes_turret_socket',(p[0],p[1],p[2]+68),team=team)
            self.probes['landmarks'].append(dict(kind='side-tower',position=game(p)))
        o=next(o for o in self.ref['objects'] if o.get('fileName','').startswith('tank18.'))
        p=tuple(map(float,o['position'].split()));a=float(o['rotation'].split()[2])
        # Stonehenge's dominant neutral lintel silhouette. Broad lanes continue
        # around both sides; the arch itself is intentionally jet-accessible.
        for lo,hi in [((-43,-9,-22),(-29,9,64)),((29,-9,-22),(43,9,64)),((-43,-10,55),(43,10,64))]:self.block(lo,hi,WALL,p,a)
        for x in [-43,29]:
            for z in [12,34,54]:self.block((x,-9.4,z),(x+14,-9,z+.5),TRIM,p,a)
        self.probes['landmarks'].append(dict(kind='central-monolith',position=game(p),top=p[2]+64))
        self.probes['views'].append(dict(name='central-arch',eye=game((p[0]+110,p[1]-125,p[2]+45)),look=game((p[0],p[1],p[2]+28))))

    def routes(self):
        # Planning corridors, not claims of original competitive ski routes.
        lanes=[('western-valley',[(210,270),(240,330),(262,402),(285,470),(350,540),(460,580),(550,553)]),
               ('eastern-valley',[(211,266),(300,212),(415,250),(520,300),(590,390),(590,480),(552,555)]),
               ('midfield-run',[(241,305),(292,349),(339,367),(425,390),(480,460),(530,508)])]
        for name,waypoints in lanes:
            samples=[]
            for start,end in zip(waypoints,waypoints[1:]):
                n=math.ceil(math.dist(start,end)/2)
                for k in range(n):
                    t=k/n;x=start[0]+(end[0]-start[0])*t;y=start[1]+(end[1]-start[1])*t
                    samples.append(game((x,y,self.height(x,y))))
            x,y=waypoints[-1];samples.append(game((x,y,self.height(x,y))))
            self.probes['routes'].append(dict(name=name,samples=samples,length=sum(math.dist(a,b) for a,b in zip(samples,samples[1:]))))
        self.probes['views'] += [dict(name='overview',eye=game((800,-50,580)),look=game((384,416,75))),dict(name='ski-valley',eye=game((285,355,self.height(285,355)+4)),look=game((395,390,110))),dict(name='western-approach',eye=game((315,560,self.height(315,560)+160)),look=game((550,555,140)))]

    def build(self):
        self.terrain()
        self.base(0);self.base(1);self.monuments();self.routes()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler',type=Path,required=True)
    parser.add_argument('--step',type=int,choices=[8,16],default=16)
    parser.add_argument('--geometry-only',action='store_true')
    args=parser.parse_args()
    OUT.mkdir(exist_ok=True);LOG.mkdir(parents=True,exist_ok=True)
    arena=Stonehenge(args.step);arena.build()
    world=dict(classname='worldspawn',message=arena.title,wad='stonehenge.wad',_fpsloppa_bake='1',_fpsloppa_atlas='4096',_minlight='40',_sunlight='100',_sunlight2='65',_sun_mangle='120 -50 0',_phong='1',_phong_angle='75',worldtype='0')
    def fields(d):return '\n'.join(f'"{k}" "{v}"' for k,v in d.items())
    source='{\n'+fields(world)+'\n'+'\n'.join(arena.brushes)+'\n}\n{\n"classname" "func_detail"\n'+'\n'.join(arena.detail)+'\n}\n'
    source+='\n'.join('{\n'+fields(e)+'\n}' for e in arena.entities)+'\n'
    names=set(re.findall(r'\) (\S+) 0 0 0 [\d.]+ [\d.]+',source))
    # Retain self-contained original miptex records after the first generation.
    if (OUT/'stonehenge.wad').exists() and names<=wad_records(OUT/'stonehenge.wad').keys():
        donors=wad_records(OUT/'stonehenge.wad');credits=json.loads((OUT/'texture-sources.json').read_text())
    else:donors,credits=materials(names,ROOT/'tools/pressureworks/local/librequake-dev.zip')
    wad=bytearray(b'WAD2'+bytes(8));directory=[]
    for name in sorted(names):
        raw=donors[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(raw),len(raw),68,0,0,name.encode()));wad.extend(raw)
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at);(OUT/'stonehenge.wad').write_bytes(wad)
    (OUT/'texture-sources.json').write_text(json.dumps({n:credits[n] for n in sorted(names)},indent=2)+'\n')
    for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt']:shutil.copyfile(ROOT/'maps/Pressureworks'/name,OUT/name)
    path=OUT/(ID+'.map');path.write_text(source)
    (OUT/'probes.json').write_text(json.dumps(arena.probes,indent=2)+'\n')
    bsp=ROOT/'maps'/(ID+'.bsp');bsp.with_suffix('.pts').unlink(missing_ok=True)
    commands=[('qbsp',['-noclip','-subdivide','512','-wadpath',str(OUT),str(path),str(bsp)])]
    if not args.geometry_only:commands += [('vis',['-threads','4',str(bsp)]),('light',['-threads','4','-extra','-bspxlit','-dirt','1',str(bsp)])]
    for exe,flags in commands:
        print('COMPILING',exe,flush=True)
        with (LOG/(exe+'.log')).open('w') as f:subprocess.run([str(args.compiler/exe),*flags],cwd=OUT,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=1800)
    raw=bsp.read_bytes();assert struct.unpack_from('<i',raw)[0]==29 and len(raw)<25_000_000
    assert not bsp.with_suffix('.pts').exists(),'Map leaked'
    assert "Couldn't create brush faces" not in (LOG/'qbsp.log').read_text()
    parts=[struct.unpack_from('<ii',raw,4+i*8) for i in range(15)]
    stats=dict(faces=parts[7][1]//20,vertices=parts[3][1]//12,nodes=parts[5][1]//24,leaves=parts[10][1]//28)
    report=dict(id=ID,title=arena.title,bsp_sha256=digest(bsp),bytes=len(raw),bsp_version=29,terrain_step_m=args.step,terrain_extent_m=[704,704],terrain_elevation_m=[min(arena.heights.values()),max(arena.heights.values())],terrain_brushes=2*(704//args.step)**2,detail_brushes=len(arena.detail),structural_brushes=len(arena.brushes),full_vis=not args.geometry_only,flag_separation_m=math.dist(*[r['position'] for r in arena.probes['flags']]),team_spawns=[8,8],expected_loadout='tribes',inventory_stations=[2,2],playable_boundary=arena.probes['boundary'],reference='references.json',**stats)
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    catalog=ROOT/'deathmatch/maps/manifest.json';rows=json.loads(catalog.read_text());rows=[r for r in rows if r['id']!=ID]
    rows.append(dict(id=ID,title=arena.title,path=f'res://maps/{ID}.bsp',scene=f'res://maps/cache/{ID}.scn',sha256=report['bsp_sha256'],size=len(raw),modes=['st'],source_name='st_stonehenge',distribution='optional',experimental=True,objectives={['red','blue'][r['team']]:r['position'] for r in arena.probes['flags']}))
    catalog.write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
