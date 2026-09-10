"""Forty original Quake BSP29 arenas for FPSloppa. Geometry/generator: CC0.

Different room graphs, elevations and architecture per map; no source map is
decompiled, traced or copied. Texture pixels come from the pinned LibreQuake WADs.
"""
from pathlib import Path
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import random
import shutil
import struct
import subprocess
from generate_tf_maps import Arena

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'optional-arena-pack'
MODES = ('dm', 'tdm', 'ctf', 'koth', 'ig', 'ft', 'cc', 'tf')
THEMES = [
    ('Foundry', 'met_brn_block', 'met_brn_tile2', 'met_brn_pan1', 'met_brn_slat', 'compbase'),
    ('Abbey', 'med_csl_brk7_2', 'med_csl_flr2_2', 'med_csl_flr4_3', 'med_met_trim1', 'med_tmpl_lit1'),
    ('Reactor', 'met_grn_block', 'met_gry_sqr', 'met_gry_pan3', 'met_grn_trim32s', 'met_grn_lit4'),
    ('Relay', 't_wall1aa', 't_flor2d', 't_flat01', 't_trim1aa', 'compbase'),
    ('Citadel', 'grk_brk16', 'grk_flr4_6', 'grk_flr5_2', 'grk_trim1', 'grk_mural1'),
]
# id, title, columns, rows, half room width, corridor length, removed-link seed.
# These define independently varied footprints; team layouts retain X symmetry.
SPECS = {
 'dm': [('cindercoil','Cinder Coil',3,3,192,256,11), ('bellvault','Bell Vault',4,2,224,256,21), ('fluxring','Flux Ring',3,4,192,224,32), ('switchyard','Switchyard',4,3,176,288,43), ('ashcourt','Ash Court',3,3,256,256,54)],
 'tdm':[('smelter','Smelter Divide',4,3,208,288,65), ('crosskeep','Cross Keep',3,3,256,288,76), ('turbines','Twin Turbines',4,2,240,320,87), ('manifold','Manifold',5,3,192,256,98), ('basalt','Basalt Exchange',4,3,224,256,109)],
 'ctf':[('slagline','Slagline',5,3,224,288,120), ('vespers','Vesper Gates',5,3,256,320,131), ('coolant','Coolant Crossing',5,3,208,320,142), ('switchback','Switchback Signal',5,3,240,256,153), ('sunken','Sunken Standards',5,3,224,352,164)],
 'koth':[('crucible','Crucible',3,3,256,288,175), ('belfry','Belfry',3,5,192,256,186), ('corehold','Core Hold',5,3,192,288,197), ('uplink','Uplink',3,3,224,320,208), ('crowns','Crown Chamber',3,3,272,256,219)],
 'ig':[('sightbreak','Sightbreak',4,2,224,320,230), ('gargoyle','Gargoyle Circuit',3,3,240,288,241), ('ionfork','Ion Fork',4,3,192,320,252), ('shutters','Shutter Array',5,2,192,288,263), ('sunlance','Sunlance',3,4,224,256,274)],
 'ft':[('coldforge','Cold Forge',4,3,224,288,285), ('reliquary','Reliquary',3,3,256,320,296), ('cryoloop','Cryo Loop',4,2,256,288,307), ('rescuebay','Rescue Bay',5,3,192,256,318), ('oathstone','Oathstone',3,4,240,288,329)],
 'cc':[('meatgrinder','Meatgrinder',3,3,160,128,340), ('bonewalk','Bonewalk',4,2,176,128,351), ('razorloop','Razor Loop',3,3,176,160,362), ('shortcircuit','Short Circuit',3,2,208,160,373), ('redmaze','Red Maze',3,3,192,128,384)],
 'tf':[('kilnfront','Kilnfront',5,3,256,352,395), ('abbeyline','Abbey Line',5,3,272,320,406), ('capacitor','Capacitor Forts',5,3,240,384,417), ('lockworks','Lockworks',5,3,256,384,428), ('obsidian','Obsidian Bastions',5,3,288,320,439)],
}

def edge(a, b):
    return tuple(sorted((a, b)))

def connected(nodes, links, missing=None):
    remaining = set(nodes) - ({missing} if missing is not None else set())
    if not remaining:
        return True
    seen = {next(iter(remaining))}
    todo = list(seen)
    while todo:
        node = todo.pop()
        for a, b in links:
            other = b if a == node else a if b == node else None
            if other in remaining and other not in seen:
                seen.add(other); todo.append(other)
    return seen == remaining

def graph(nx, ny, seed, symmetrical, hill):
    nodes = [(x,y) for x in range(nx) for y in range(ny)]
    links = {edge((x,y),(x+dx,y+dy)) for x,y in nodes
             for dx,dy in [(1,0),(0,1)] if (x+dx,y+dy) in nodes}
    ordered = sorted(links); random.Random(seed).shuffle(ordered)
    target = max(1, (nx*ny)//5)
    removed = 0
    for candidate in ordered:
        cuts = {candidate}
        if symmetrical:
            cuts.add(edge(*[(nx-1-x,y) for x,y in candidate]))
        if hill and any((nx//2,ny//2) in c for c in cuts):
            continue
        trial = links-cuts
        # No single room or single corridor can lock the entire map.
        if all(connected(nodes, trial, n) for n in nodes) and connected(nodes, trial):
            removed += len(links-trial); links = trial
        if removed >= target:
            break
    return nodes, links

class Circuit(Arena):
    def __init__(self, mode, index, spec):
        slug,title,nx,ny,half,gap,seed=spec
        super().__init__(mode+'_'+slug,title)
        self.mode,self.index,self.nx,self.ny,self.half,self.gap,self.seed=mode,index,nx,ny,half,gap,seed
        self.step=2*half+gap
        self.symmetrical=mode in ('tdm','ctf','ft','tf','koth')
        self.nodes,self.links=graph(nx,ny,seed,self.symmetrical,mode=='koth')
        self.theme,self.wall,self.floor,self.roof,self.trim,self.panel=THEMES[index]
        self.goals=[];self.spawn_data=[];self.loot=[];self.box_data=[]
        self.heights={node:self.elevation(*node) for node in self.nodes}
    def elevation(self,x,y):
        a=min(x,self.nx-1-x) if self.symmetrical else x
        if self.mode=='cc':return 32*((a+y+self.index)%2)
        if self.mode=='koth':
            return 0 if (x,y)==(self.nx//2,self.ny//2) else 64*((min(x,self.nx-1-x)+min(y,self.ny-1-y)+self.index)%2)
        patterns=[lambda:64*(a%2),lambda:64*(y%2),lambda:64*((a+y)%2),lambda:32*((a+2*y)%3),lambda:96*(y%2)]
        return patterns[self.index]()
    def center(self,node):
        x,y=node
        return ((x-(self.nx-1)/2)*self.step,(y-(self.ny-1)/2)*self.step,self.heights[node])
    def box(self,a,b,texture='met_brn_block'):
        super().box(a,b,texture);self.box_data.append([list(a),list(b),texture])
    def slope(self,a,b,z0,z1,axis):
        x,y=a;X,Y=b;bottom=min(z0,z1)-32
        zz=lambda xx,yy:z0+(z1-z0)*((xx-x)/(X-x) if axis==0 else (yy-y)/(Y-y))
        p=(x,y,zz(x,y));q=(X,y,zz(X,y));r=(X,Y,zz(X,Y));s=(x,Y,zz(x,Y))
        faces=[[(x,y,bottom),(x,Y,bottom),(X,Y,bottom)],[p,q,r],[(x,y,bottom),(X,y,bottom),q],[(X,y,bottom),(X,Y,bottom),r],[(X,Y,bottom),(x,Y,bottom),s],[(x,Y,bottom),(x,y,bottom),p]]
        self.brushes.append('{\n'+'\n'.join(self.face(f,self.floor) for f in faces)+'\n}')
    def local_box(self,node,a,b,tex):
        x,y,z=self.center(node)
        self.box((x+a[0],y+a[1],z+a[2]),(x+b[0],y+b[1],z+b[2]),tex)
    def room(self,node):
        x,y,z=self.center(node);h=self.half
        width=160 if self.mode=='cc' else 192 if self.mode in ('tf','ft','ctf') else 176
        d=width/2;height=352 if self.index in (0,2,3) else 416
        variant=((min(node[0],self.nx-1-node[0]) if self.symmetrical else node[0])+2*node[1]+self.seed)%3
        wall=[self.wall,self.wall,self.roof][variant]
        team_trim=('wall_red_a' if node[0]==0 else 'wall_blue_a') if self.mode in ('ctf','tf') and node[0] in (0,self.nx-1) else self.trim
        self.local_box(node,(-h,-h,-32),(h,h,0),self.floor)
        # Sky wells alternate with covered galleries; enclosing side walls stay sealed.
        ceiling='sky_star' if ((min(node[0],self.nx-1-node[0]) if self.symmetrical else node[0])+node[1]+self.index)%4==0 else self.roof
        self.local_box(node,(-h-24,-h-24,height),(h+24,h+24,height+24),ceiling)
        for axis,sign,delta in [(0,-1,(-1,0)),(0,1,(1,0)),(1,-1,(0,-1)),(1,1,(0,1))]:
            neighbor=(node[0]+delta[0],node[1]+delta[1])
            opening=edge(node,neighbor) in self.links
            spans=[(-h,-d),(d,h)] if opening else [(-h,h)]
            def wallbox(lo,hi,low,high,tex,depth=24):
                fixed=(sign*h if sign>0 else -h-depth)
                a,b=((fixed,lo,low),(fixed+depth,hi,high)) if axis==0 else ((lo,fixed,low),(hi,fixed+depth,high))
                self.local_box(node,a,b,tex)
            for lo,hi in spans:
                wallbox(lo,hi,-32,80,self.floor if variant==1 else wall)
                wallbox(lo,hi,80,224,wall)
                wallbox(lo,hi,224,height,self.roof if variant==0 else wall)
                # Inset banding gives the familiar layered masonry/metal scale.
                inset=-8 if sign>0 else 0
                fixed=sign*h+inset
                a,b=((fixed,lo,0),(fixed+8,hi,16)) if axis==0 else ((lo,fixed,0),(hi,fixed+8,16))
                self.local_box(node,a,b,team_trim)
                # A horizontal dado and cornice break up tall flat wall surfaces.
                for band in (80,216):
                    aa=list(a);bb=list(b);aa[2]=band;bb[2]=band+8
                    self.local_box(node,aa,bb,team_trim)
            if opening:
                wallbox(-d,d,224,height,wall)
                wallbox(-d,d,224,240,team_trim)
                if self.index in (1,4):
                    # Stepped stone arch above a full-height clear doorway.
                    wallbox(-d,-d+24,200,224,self.trim)
                    wallbox(d-24,d,200,224,self.trim)
            else:
                # One recognizable panel per closed wall, above the standing body.
                fixed=sign*(h-4)
                a,b=((fixed-2,-48,96),(fixed+2,48,192)) if axis==0 else ((-48,fixed-2,96),(48,fixed+2,192))
                self.local_box(node,a,b,self.panel)
        # High ceiling ribs and corner buttresses do not obstruct main movement lanes.
        for sign in (-1,1):
            self.local_box(node,(-h,sign*(h-32)-8,height-24),(h,sign*(h-32)+8,height),self.trim)
        if self.index in (1,4):
            for sx in (-1,1):
                for sy in (-1,1):
                    xx,yy=sx*(h-24),sy*(h-24)
                    self.local_box(node,(xx-16,yy-16,0),(xx+16,yy+16,height),self.trim)
        # Industrial suspended beams versus stepped masonry vault ribs.
        if ceiling!='sky_star':
            for xx in (-h*.55,h*.55):
                self.local_box(node,(xx-10,-h,height-48),(xx+10,h,height),self.trim)
            if variant==1:
                self.local_box(node,(-h,-h,height-72),(-h+40,h,height),self.trim)
                self.local_box(node,(h-40,-h,height-72),(h,h,height),self.trim)
        else:
            # Bright open courts contrast with lower, shaded connecting halls.
            for yy in (-h+16,h-16):
                self.local_box(node,(-h,yy-8,height-24),(h,yy+8,height),self.trim)
        self.feature(node)
        colours=[('1 .70 .42','.65 .80 1'),('1 .76 .46','.65 .72 1'),('.50 .85 1','1 .65 .35'),('.68 .88 1','1 .78 .5'),('1 .85 .60','.60 .85 .90')]
        for sy in (-1,1):
            color=colours[self.index][0 if sy<0 else 1]
            # Light is anchored to an actual visible wall fixture, not the room centre.
            lx=-(h-52) if self.symmetrical and node[0]>=self.nx/2 else h-52
            self.local_box(node,(lx-28,sy*(h-10)-4,144),(lx+28,sy*(h-10)+4,160),'tlight12')
            self.ent('light',(x+(h-64)*(-1 if self.symmetrical and node[0]>=self.nx/2 else 1),y+sy*(h-40),z+152),light=340,delay=0,_color=color)
        self.ent('light',(x,y,z+height-64),light=210,delay=0,_color='1 .94 .85')
    def feature(self,node):
        # Spawns use (-96,-96), pickups use the north-east recess; keep them clear.
        central=node==(self.nx//2,self.ny//2)
        flagroom=self.mode in ('ctf','tf') and node in [(0,self.ny//2),(self.nx-1,self.ny//2)]
        if self.mode=='koth' and central:
            for axis in (0,1):
                a,b=((-80,-4,0),(80,4,2)) if axis==0 else ((-4,-80,0),(4,80,2))
                self.local_box(node,a,b,'tlight12')
            return
        if flagroom:
            sign=1 if node[0]==0 else -1
            self.local_box(node,(sign*96-12,-48,0),(sign*96+12,48,128),self.trim)
            return
        style=((min(node[0],self.nx-1-node[0]) if self.symmetrical else node[0])+node[1]*2+self.index)%5
        if self.mode=='cc':
            # Low obstacle density: combat never depends on a jump or single doorway.
            if style%2==0:self.local_box(node,(24,8,0),(64,64,56),self.panel)
            return
        if style==0:
            self.local_box(node,(-32,-32,0),(32,32,192),self.trim)
            self.local_box(node,(-40,-40,176),(40,40,192),'tlight12')
        elif style==1:
            for yy in (-48,48):self.local_box(node,(-48,yy-12,0),(48,yy+12,80),self.panel)
        elif style==2:
            self.local_box(node,(-48,-24,0),(48,24,112),self.wall)
            self.local_box(node,(-48,-24,112),(48,24,120),self.trim)
        elif style==3:
            for xx in (-48,48):self.local_box(node,(xx-12,-16,0),(xx+12,48,160),self.trim)
        else:
            # Split octagonal-like plinth leaves open diagonals and both flank exits.
            self.local_box(node,(-32,-32,0),(32,32,64),self.panel)
    def corridor(self,a,b):
        x,y,z=self.center(a);X,Y,Z=self.center(b);h=self.half
        axis=0 if a[0]!=b[0] else 1
        width=160 if self.mode=='cc' else 192 if self.mode in ('tf','ft','ctf') else 176
        d=width/2
        start,end=((x+h,y-d),(X-h,y+d)) if axis==0 else ((x-d,y+h),(x+d,Y-h))
        self.slope(start,end,z,Z,axis)
        low=min(z,Z)-32;roof=max(z,Z)+224
        if axis==0:
            for yy in (y-d-24,y+d):self.box((start[0],yy,low),(end[0],yy+24,roof+24),self.wall)
        else:
            for xx in (x-d-24,x+d):self.box((xx,start[1],low),(xx+24,end[1],roof+24),self.wall)
        self.box((start[0],start[1],roof),(end[0],end[1],roof+24),self.roof)
        mx,my=(start[0]+end[0])/2,(start[1]+end[1])/2
        self.box((mx-24,my-24,roof-8),(mx+24,my+24,roof),'tlight12')
        self.ent('light',(mx,my,roof-32),light=230,delay=0,_color='1 .86 .66')
        # An overhead rib marks each connection and obscures long roof lines.
        if axis==0:self.box(((start[0]+end[0])/2-8,start[1],roof-12),((start[0]+end[0])/2+8,end[1],roof),self.trim)
        else:self.box((start[0],(start[1]+end[1])/2-8,roof-12),(end[0],(start[1]+end[1])/2+8,roof),self.trim)
    def spawn(self,node,offset=(-96,-96),team=None):
        x,y,z=self.center(node)
        if self.symmetrical and team is None:
            offset=(abs(offset[0]) if node[0]>self.nx//2 else -abs(offset[0]) if node[0]<self.nx//2 else 0,offset[1]) if self.nx%2 else (abs(offset[0]) if node[0]>=self.nx/2 else -abs(offset[0]),offset[1])
        pos=(x+offset[0],y+offset[1],z+24)
        self.ent('info_player_deathmatch',pos,angle=0 if node[0]<self.nx/2 else 180)
        if team is not None:self.ent('info_player_team'+str(team+1),pos,angle=0 if team==0 else 180)
        self.spawn_data.append({'position':list(pos),'team':team})
    def pickup(self,node,kind,offset=(96,96),**fields):
        x,y,z=self.center(node)
        if self.symmetrical and node[0]>(self.nx-1)/2:offset=(-offset[0],offset[1])
        if self.symmetrical and node[0]==(self.nx-1)/2:offset=(0,offset[1])
        pos=(x+offset[0],y+offset[1],z)
        self.ent(kind,(pos[0]-16,pos[1]-16,z+16),**fields)
        self.loot.append({'position':list(pos),'kind':kind})
    def populate(self):
        for node in self.nodes:
            # The current build chooses the hill nearest the extreme-spawn midpoint.
            # A unique center spawn makes that deterministic without a plugin/update.
            self.spawn(node,(0,0) if self.mode=='koth' and node==(self.nx//2,self.ny//2) else (-96,-96))
        if self.mode=='koth':
            # Symmetric extremes fix the midpoint at the intended central room.
            for node in [(0,0),(self.nx-1,self.ny-1),(0,self.ny-1),(self.nx-1,0)]:self.spawn(node,(96,96))
        for team in (0,1):
            col=0 if team==0 else self.nx-1
            if self.mode in ('ctf','tf'):
                for row in (0,self.ny-1):
                    self.spawn((col,row),(-80,0),team);self.spawn((col,row),(80,0),team)
                node=(col,self.ny//2);x,y,z=self.center(node)
                self.ent('item_flag_team'+str(team+1),(x,y,z+24));self.goals.append({'kind':'flag','team':team,'position':[x,y,z+24]})
                if self.mode=='tf':
                    color='red' if team==0 else 'blue'
                    for row in (0,self.ny-1):
                        xx,yy,zz=self.center((col,row));self.ent('info_tf_resupply_'+color,(xx,yy+80,zz+24))
                        self.goals.append({'kind':'resupply','team':team,'position':[xx,yy+80,zz+24]})
                    capnode=(col,0) if self.index in (1,3) else node
                    xx,yy,zz=self.center(capnode);self.ent('info_tf_capture_'+color,(xx,yy,zz+24))
                    self.goals.append({'kind':'capture','team':team,'position':[xx,yy,zz+24]})
        if self.mode=='koth':
            x,y,z=self.center((self.nx//2,self.ny//2));self.goals.append({'kind':'hill','position':[x,y,z+24]})
        # Supply circuits split strong weapons, armor and megahealth across the map.
        kinds=['weapon_shotgun','item_shells','weapon_rocketlauncher','item_health','weapon_nailgun','item_rockets','weapon_supershotgun','item_spikes','item_armor1','weapon_supernailgun','item_cells','item_health']
        for i,node in enumerate(self.nodes):
            key=min(node[0],self.nx-1-node[0])*self.ny+node[1] if self.symmetrical else i
            self.pickup(node,kinds[(key+self.index)%len(kinds)])
        self.pickup((0,0),'item_armor2',(-96,96))
        self.pickup((self.nx-1,self.ny-1),'item_health',(-96,96),spawnflags=2)
        if self.symmetrical:
            self.pickup((self.nx-1,0),'item_armor2',(-96,96));self.pickup((0,self.ny-1),'item_health',(-96,96),spawnflags=2)
        self.ent('info_player_start',tuple(self.spawn_data[0]['position']),angle=0)
    def build(self):
        for node in self.nodes:self.room(node)
        for a,b in sorted(self.links):self.corridor(a,b)
        self.populate()
    def write_source(self):
        world={'classname':'worldspawn','message':self.mode.upper()+' - '+self.title,'wad':'arena-librequake.wad','_fpsloppa_bake':'1','_sunlight':'150','_sunlight_color':'1 .88 .70','_sunlight2':'40','_dirt':'1','_dirtdepth':'96','_bounce':'1','_sun_mangle':'35 -65 0','_minlight':'28','worldtype':'0'}
        entity=lambda d:'\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
        text='{\n'+entity(world)+'\n'+'\n'.join(self.brushes)+'\n}\n'+'\n'.join('{\n'+entity(e)+'\n}' for e in self.entities)+'\n'
        path=OUT/'source'/(self.name+'.map');path.write_text(text);return path
    def report(self):
        return {'id':self.name,'title':self.title,'mode':self.mode,'theme':self.theme,'recommended_players':[2,6] if self.mode=='cc' else [4,12] if self.mode in ('ctf','tf','tdm','ft') else [2,8],
                'rooms':[{'grid':list(n),'position':list(self.center(n))} for n in self.nodes],
                'links':[[list(a),list(b)] for a,b in sorted(self.links)],'half_room':self.half,'corridor_width':160 if self.mode=='cc' else 192 if self.mode in ('tf','ft','ctf') else 176,
                'graph_has_no_articulation_room':all(connected(self.nodes,self.links,n) for n in self.nodes),
                'spawn_points':self.spawn_data,'goals':self.goals,'pickups':self.loot,'brushes':len(self.brushes),
                'original_geometry':True,'seed':self.seed,'geometry_sha256':hashlib.sha256('\n'.join(self.brushes).encode()).hexdigest()}

def wad_entries(path):
    raw=path.read_bytes();count,offset=struct.unpack_from('<ii',raw,4);out={}
    for i in range(count):
        at,size,_,kind,compression,_,name=struct.unpack_from('<iiiBBH16s',raw,offset+i*32)
        if kind==68 and compression==0:out[name.split(b'\0')[0].decode()]=raw[at:at+size]
    return out

def prepare_wad(directory):
    wanted={t for theme in THEMES for t in theme[1:]}|{'tlight12','wall_red_a','wall_blue_a','sky_star'}
    found={};sources={}
    for path in sorted(directory.glob('*.wad')):
        for name,raw in wad_entries(path).items():
            if name in wanted and name not in found:
                found[name]=raw;sources[name]={'wad':path.name,'wad_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'miptex_sha256':hashlib.sha256(raw).hexdigest()}
    assert set(found)==wanted, wanted-set(found)
    result=bytearray(b'WAD2'+bytes(8));entries=[]
    for name,raw in sorted(found.items()):
        entries.append(struct.pack('<iiiBBH16s',len(result),len(raw),len(raw),68,0,0,name.encode()));result.extend(raw)
    offset=len(result);result.extend(b''.join(entries));struct.pack_into('<ii',result,4,len(entries),offset)
    (OUT/'source/arena-librequake.wad').write_bytes(result)
    (OUT/'texture-sources.json').write_text(json.dumps({'upstream':'LibreQuake v0.09-beta developer assets','url':'https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta','textures':sources},indent=2)+'\n')
    docs=directory.parent/'docs'
    for name in ('COPYING','CREDITS','README-IMPORTANT-LICENCE-INFO'):
        shutil.copy2(docs/name,OUT/('LibreQuake-'+name+'.txt'))
    for original,name in [('COPYING.adoc','Freedoom-COPYING.txt'),('CREDITS','Freedoom-CREDITS.txt')]:
        shutil.copy2(docs/'freedoom-docs'/original,OUT/name)

def compile_map(arena,compiler):
    source=arena.write_source();row=arena.report();bsp=OUT/(arena.name+'.bsp')
    for tool,args in [('qbsp',['-wadpath',str(OUT/'source'),str(source),str(bsp)]),('vis',['-threads','2',str(bsp)]),('light',['-threads','2','-extra','-lit','-bspxlit',str(bsp)])]:
        log=ROOT/'test-results'/(arena.name+'-'+tool+'.log')
        with log.open('w') as handle:subprocess.run([str(compiler/tool),*args],stdout=handle,stderr=subprocess.STDOUT,check=True,timeout=240)
        if tool=='qbsp' and 'LEAK' in log.read_text().upper():raise RuntimeError('Leaked map: '+arena.name)
    row.update(sha256=hashlib.sha256(bsp.read_bytes()).hexdigest(),bytes=bsp.stat().st_size)
    print('COMPILED',arena.name,len(arena.brushes),'brushes',flush=True)
    return row

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--compiler-dir',type=Path,required=True)
    parser.add_argument('--wad-dir',type=Path);parser.add_argument('--only',nargs='*');args=parser.parse_args()
    OUT.mkdir(exist_ok=True);(OUT/'source').mkdir(exist_ok=True);(ROOT/'test-results').mkdir(exist_ok=True)
    (OUT/'.gdignore').touch();(OUT/'.gitignore').write_text('*.log\n*.prt\n*.pts\n*.vis\n*.texinfo\natlas/screenshots/\n')
    if args.wad_dir:prepare_wad(args.wad_dir)
    assert (OUT/'source/arena-librequake.wad').exists(),'Pass --wad-dir on the initial run'
    arenas=[]
    for mode in MODES:
        for index,spec in enumerate(SPECS[mode]):
            arena=Circuit(mode,index,spec)
            if args.only and arena.name not in args.only:continue
            arena.build();arenas.append(arena)
    with ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(lambda a:compile_map(a,args.compiler_dir),arenas))
    if args.only and (OUT/'manifest.json').exists():
        previous=json.loads((OUT/'manifest.json').read_text());rows += [r for r in previous if r['id'] not in args.only]
    rows.sort(key=lambda row:(MODES.index(row['mode']),row['seed']))
    (OUT/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
    for mode in MODES:(OUT/(mode+'_maplist.txt')).write_text(''.join(r['id']+'\n' for r in rows if r['mode']==mode))
    print('PACK',len(rows),'maps')

if __name__=='__main__':main()
