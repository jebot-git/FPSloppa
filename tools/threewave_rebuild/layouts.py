"""Authored CTF spaces, in Quake units. No original BSP or reference data is read here.

Each layout specifies new room volumes and construction, inspired by observed route
relationships. Solid space is meshed into convex boxes, then detailed by hand.
"""
from pathlib import Path
import sys, math
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from generate_tf_maps import Arena
from vesper.build import column, arch, polygon

STONE='med_csl_brk15'; FLOOR='med_cobstn1_2'; TRIM='met_brn_block'; METAL='metal_iron1_07'
RED='stn_gw10_red1'; BLUE='stn_gw10_blu1'

class Map(Arena):
    def __init__(self,n,key,title,wall=STONE,floor=FLOOR):
        super().__init__('ctf_'+key,title)
        self.number=n;self.wall=wall;self.floor=floor;self.rooms=[];self.models=[];self.detail=[]
        self.flags=[];self.spawns=[];self.routes=[];self.views=[];self.landmarks=[];self.sky=False
        self.ceiling_material='med_wood4' if n in [2,4,5] else 'met_brn_block'
    def face(self,points,texture):
        # Different top surfaces make the authored masonry readable at eye level.
        base=super().face(points,texture)
        if texture.startswith(('metal_','ind_')):base=base.rsplit(' ',2)[0]+' .5 .5'
        if texture.startswith('med_rock'):base=base.rsplit(' ',2)[0]+' 2 2'
        return base
    def room(self,a,b,label=''):
        assert all(u<v for u,v in zip(a,b)),(a,b)
        self.rooms.append((a,b))
        if label:self.landmarks.append({'name':label,'center':[(u+v)/2 for u,v in zip(a,b)]})
    def mirrored_room(self,s,a,b,label=''):
        if s<0:a,b=(-b[0],-b[1],a[2]),(-a[0],-a[1],b[2])
        self.room(a,b,label)
    def block(self,s,a,b,t=None):
        if s<0:a,b=(-b[0],-b[1],a[2]),(-a[0],-a[1],b[2])
        self.box(a,b,t or self.wall)
    def slope(self,s,x0,x1,y0,y1,z0,z1,t=None):
        self.mirrored_room(s,(x0,y0,min(z0,z1)),(x1,y1,max(z0,z1)+224))
        if s>0:self.ramp_x(x0,x1,y0,y1,z0,z1,t or self.floor)
        else:self.ramp_x(-x1,-x0,-y1,-y0,z1,z0,t or self.floor)
    def model(self,fields,a,b,t='trigger'):
        start=len(self.brushes);self.box(a,b,t);self.models.append((fields,self.brushes[start:]));del self.brushes[start:]
    def tele(self,a,b,target,dest):
        self.model({'classname':'trigger_teleport','target':target},a,b)
        self.ent('info_teleport_destination',dest,targetname=target)
    def objectives(self,team,flag,spawns):
        self.flags.append(flag);self.spawns.append(spawns)
        self.ent('item_flag_team'+str(team+1),flag)
        for p in spawns:self.ent('info_player_team'+str(team+1),p,angle=0 if team==0 else 180)
        for p in spawns[::2]:self.ent('info_player_deathmatch',p)
        if team==0:self.ent('info_player_start',spawns[0])
    def pickup(self,p,kind='weapon_rocketlauncher'):self.ent(kind,p)
    def light(self,p,team=None,power=320):
        color='1 .68 .52' if team==0 else '.52 .72 1' if team==1 else '1 .9 .74'
        self.ent('light',p,light=power,_color=color,delay=0)
    def finish(self):
        # Construct the complement of authored empty rooms. Coordinate compression
        # gives exact faces; greedy cuboids avoid overlapping coplanar wall slabs.
        coords=[]
        for axis in range(3):
            values={v[axis] for r in self.rooms for v in r};values|={min(values)-64,max(values)+64};coords.append(sorted(values))
        shape=tuple(len(c)-1 for c in coords);solid=np.ones(shape,dtype=bool)
        for lo,hi in self.rooms:
            sl=tuple(slice(coords[d].index(lo[d]),coords[d].index(hi[d])) for d in range(3));solid[sl]=False
        # Merge along Z, then Y, then X. All emitted boxes are mutually disjoint.
        for i in range(shape[0]):
            for j in range(shape[1]):
                for k in range(shape[2]):
                    if not solid[i,j,k]:continue
                    K=k+1
                    while K<shape[2] and solid[i,j,K]:K+=1
                    J=j+1
                    while J<shape[1] and solid[i,J,k:K].all():J+=1
                    I=i+1
                    while I<shape[0] and solid[I,j:J,k:K].all():I+=1
                    solid[i:I,j:J,k:K]=False
                    lo=(coords[0][i],coords[1][j],coords[2][k]);hi=(coords[0][I],coords[1][J],coords[2][K])
                    if self.sky and hi[2]>256:
                        self.box((lo[0],lo[1],max(lo[2],256)),hi,'sky_star')
                        if lo[2]>=256:continue
                        hi=(hi[0],hi[1],256)
                    start=len(self.brushes);self.box(lo,hi,self.wall)
                    lines=self.brushes[start].splitlines();lines[2]=lines[2].replace(self.wall,self.floor)
                    lines[1]=lines[1].replace(self.wall,self.ceiling_material);self.brushes[start]='\n'.join(lines)
        # Room-centred fixtures; omit tiny overlaps/corridors, deduplicate lights.
        seen=set()
        for lo,hi in self.rooms:
            if hi[0]-lo[0]<128 or hi[1]-lo[1]<128:continue
            for x in range(int(lo[0]+64),int(hi[0]),320):
                for y in range(int(lo[1]+64),int(hi[1]),320):
                    p=(x,y,min(lo[2]+176,hi[2]-32))
                    if any(sum((u-v)**2 for u,v in zip(p,q))<140**2 for q in seen):continue
                    seen.add(p);self.light(p,power=230)
        return self

def tideworks():
    a=Map(1,'tideworks','Tideworks | McKinley Base study','ind_brk02_gry1','met_brn_tile2')
    # Water court with offset entries, a high cross-gallery and long side stairs.
    a.room((-704,-704,-192),(704,704,704),'Flood court')
    a.box((-704,-704,-192),(704,704,-96),'*water2')
    a.box((-704,-112,-24),(704,112,0),'met_brn_slat')
    a.box((-128,-704,232),(128,704,256),'met_brn_slat')
    for s in [-1,1]:
        team=0 if s<0 else 1;color=RED if team==0 else BLUE
        r=lambda p,q,label='':a.mirrored_room(s,p,q,label)
        r((704,-608,0),(1664,224,576),'Base concourse')
        r((1472,-416,256),(1856,-32,576),'Raised flag room')
        r((544,-384,0),(768,-160,256),'Main entry')
        r((256,-608,0),(768,-416,288),'Window approach')
        a.slope(s,256,704,-608,-416,256,0)
        r((128,-608,256),(320,-416,512))
        a.block(s,(128,-608,232),(256,-416,256),METAL)
        a.slope(s,832,1472,-416,-160,0,256)
        a.block(s,(1472,-416,224),(1856,-32,256),METAL)
        # A second independent stair approaches the flag from its other side.
        a.slope(s,832,1472,-32,160,0,256)
        r((1408,-160,256),(1664,160,544))
        a.block(s,(1472,-32,224),(1664,160,256),METAL)
        r((1024,-32,-192),(1248,544,0),'Service water route')
        r((544,320,-192),(1152,544,96))
        a.slope(s,1248,1600,0,192,-192,0)
        r((1152,0,-192),(1312,192,128))
        a.block(s,(704,-608,0),(832,-448,128),METAL)
        a.block(s,(1472,-416,256),(1504,-32,272),TRIM)
        a.block(s,(1824,-352,272),(1856,-96,496),color)
        # Front overhang and frame echo a workshop, without original logos.
        for y in [-608,160]:a.block(s,(736,y,0),(784,y+48,448),METAL)
        # Concrete/brick bulkheads with discrete steel ribs and inset lamps.
        for x in [928,1248,1568]:
            a.block(s,(x,-608,0),(x+24,-588,544),TRIM)
            a.block(s,(x,-596,224),(x+24,-584,288),'tlight12')
        for x in [896,1280]:a.block(s,(x,-608,544),(x+32,224,568),TRIM)
        flag=(s*1728,s*-224,280)
        spawns=[(s*x,s*y,24) for x in [1024,1216] for y in [-544,64,160,224-80]]
        # Spread in unobstructed pockets, away from ramp footprints.
        spawns=[(s*x,s*-544,24) for x in [896,992,1088,1184,1280,1376,1472,1568]]
        a.objectives(team,flag,spawns)
        a.pickup((s*800,s*-272,24),'weapon_supershotgun');a.pickup((s*1360,s*-544,24),'weapon_rocketlauncher')
        a.pickup((s*1024,s*480,-168),'weapon_lightning');a.pickup((s*1536,s*-96,280),'item_armor2')
        a.light((s*1696,s*-224,480),team)
    a.pickup((0,0,288),'weapon_grenadelauncher')
    a.routes=[{'name':'high gallery','points':[[-896,512,0],[-224,512,256],[0,512,256],[0,-512,256],[224,-512,256],[896,-512,0]]}]
    a.views=[([-600,480,360],[400,-300,64],'court'),([1300,-100,400],[1728,-224,280],'flag')]
    return a.finish()

def crucible():
    a=Map(2,'crucible','Crucible | The Kiln study','med_csl_brk11','med_wood4')
    a.room((-640,-448,-192),(640,448,384),'Divided furnace hall')
    # Low side passages, split upper galleries, and a lower grenade chamber.
    for y in [-640,448]:a.room((-704,y,-192),(704,y+192,64),'Lower flank')
    a.box((-112,-256,-192),(112,256,128),STONE)
    for y in [-448,288]:a.box((-640,y,-32),(640,y+160,0),FLOOR)
    for s in [-1,1]:
        team=int(s>0);color=BLUE if team else RED
        r=lambda p,q,label='':a.mirrored_room(s,p,q,label)
        r((640,-320,0),(1280,320,352),'Base shrine')
        r((1184,-160,64),(1408,160,352),'Flag alcove')
        a.slope(s,992,1184,-160,160,0,64)
        a.block(s,(1184,-160,32),(1408,160,64),FLOOR)
        r((512,-192,0),(704,192,256))
        for y in [-640,448]:
            a.slope(s,480,992,y,y+192,-192,0)
            r((896,y,0),(1088,640 if y>0 else -256,256)) if y>0 else r((896,-640,0),(1088,-256,256))
        a.slope(s,160,576,-112,112,-192,0)
        # Main gallery entry splits around the central divider.
        a.block(s,(576,-288,-24),(640,288,0),FLOOR)
        a.block(s,(1376,-128,64),(1408,128,288),color)
        for y in [-288,240]:a.block(s,(736,y,0),(784,y+48,288),TRIM)
        for x in [704,960,1248]:
            a.block(s,(x,-320,288),(x+32,320,320),'med_wood4')
        # Low masonry arch over the base mouth, with no intrusive centre pillar.
        first=len(a.brushes);arch(a,640,672,0,384,192,256,288,texture='med_csl_brk11')
        if s<0:
            import re
            for i in range(first,len(a.brushes)):
                a.brushes[i]=re.sub(r'\( ([^()]+) \)',lambda m:'( %g %g %g )'%tuple(float(v)*(-1 if j<2 else 1) for j,v in enumerate(m.group(1).split())),a.brushes[i])
        a.objectives(team,(s*1312,0,88),[(s*x,s*y,24) for x in [768,896,1056,1184] for y in [-240,240]])
        a.pickup((s*896,0,24),'weapon_supernailgun');a.pickup((s*1200,s*240,24),'item_armor2')
        a.pickup((s*352,s*352,24),'weapon_supershotgun');a.light((s*1248,0,272),team)
    a.pickup((0,352,24),'weapon_grenadelauncher');a.pickup((0,-544,-168),'weapon_nailgun')
    a.views=[([520,320,170],[-400,-160,40],'upper hall'),([1184,128,160],[1312,0,88],'shrine')]
    a.routes=[{'name':'lower flank','points':[[1024,544,0],[640,544,-132],[0,544,-192],[-640,544,-132],[-1024,544,0]]}]
    return a.finish()

def confluence():
    a=Map(3,'confluence','Confluence | DySpHoRiA study','med_csl_brk15','med_flat5a')
    a.room((-768,-640,-320),(768,640,640),'Layered central crossing')
    a.box((-704,-576,-320),(704,576,-240),'*water2')
    a.box((-768,-112,-32),(768,112,0),FLOOR)
    a.box((-112,-640,224),(112,640,256),METAL)
    # Shallow furnace trays sit above the lower water conduit, as separate hazards.
    for y in [-272,144]:
        a.box((-320,y,-192),(320,y+128,-160),TRIM)
        a.box((-320,y,-160),(320,y+128,-128),'*lava1')
    for y in [-480,288]:a.box((-768,y,-32),(768,y+192,0),FLOOR)
    for s in [-1,1]:
        team=int(s>0);color=BLUE if team else RED;r=lambda p,q,label='':a.mirrored_room(s,p,q,label)
        r((896,-704,0),(1856,704,640),'Ring atrium')
        r((1792,-224,0),(2112,224,320),'Inner flag vault')
        r((704,-144,0),(960,144,224))
        for y in [-480,288]:r((704,y,0),(1024,y+192,256))
        # The upper horseshoe overlooks the central basin; ramps replace grapple dependence.
        for y in [-704,512]:a.block(s,(896,y,224),(1856,y+192,256),METAL)
        a.block(s,(1600,-512,224),(1856,512,256),METAL)
        for y in [-512,320]:a.slope(s,960,1600,y,y+192,0,256)
        r((384,512,256),(960,704,512))
        r((112,512,256),(640,704,512));a.block(s,(112,512,232),(640,704,256),METAL)
        # Water-level route reaches each atrium through a side ramp gallery.
        r((640,-96,-320),(1344,96,0),'Lower conduit')
        r((1184,-288,-320),(1440,288,0))
        a.slope(s,1408,2048,384,608,-320,0)
        r((1216,0,-320),(1536,608,-96));r((1856,192,0),(2112,640,256))
        a.block(s,(2080,-160,0),(2112,160,256),color)
        for y in [-640,576]:column(a,s*1088,s*(y+32),32,256,544,TRIM)
        for x in [960,1408,1792]:
            for y in [-704,672]:a.block(s,(x,y,0),(x+32,y+32,576),'med_csl_brk11')
        a.block(s,(1792,-704,576),(1824,704,608),'med_wood4')
        a.objectives(team,(s*1984,0,24),[(s*x,s*y,24) for x in [1024,1120,1600,1728] for y in [-224,224]])
        a.pickup((s*1728,0,280),'item_armor2');a.pickup((s*1088,s*-224,24),'weapon_supernailgun')
        a.pickup((s*1280,0,-296),'weapon_lightning');a.light((s*1984,0,224),team)
        a.tele((s*0+(-400 if s<0 else 352),-80,0),((-352 if s<0 else 400),80,96),'atrium'+str(team),(s*1728,0,256))
    a.pickup((0,0,24));a.pickup((0,512,280),'weapon_grenadelauncher')
    a.views=[([-640,384,400],[256,0,0],'layered crossing'),([1120,0,400],[1984,0,80],'ring atrium')]
    a.routes=[{'name':'upper atrium crossing','points':[[1728,0,256],[1728,608,256],[512,608,256],[0,512,256],[0,-512,256],[-512,-608,256],[-1728,-608,256],[-1728,0,256]]}]
    return a.finish()

def deepvault():
    a=Map(4,'deepvault','Deepvault | Forgotten Mines study','med_rock5','med_wood4')
    # Long, bent central mine; the two approaches peel off before the flag gate.
    a.room((-512,-192,-192),(512,192,128),'Central mine choke')
    a.room((-192,-384,-192),(192,384,160))
    for s in [-1,1]:
        team=int(s>0);color=BLUE if team else RED;r=lambda p,q,label='':a.mirrored_room(s,p,q,label)
        r((448,-544,-192),(1152,544,448),'Excavation chamber')
        r((256,128,-192),(576,448,128),'Choke descent')
        a.block(s,(640,-160,-192),(896,160,-112),'*slime1')
        a.block(s,(448,-128,-24),(1152,128,0),METAL)
        a.slope(s,448,1024,256,480,-192,0)
        a.block(s,(1024,256,-32),(1152,480,0),FLOOR)
        r((1024,-544,0),(1728,544,384),'Three mining galleries')
        for y in [-288,192]:a.block(s,(1152,y,0),(1600,y+96,352),STONE)
        r((1664,-320,0),(2080,320,384),'Gate approach')
        r((2048,-224,0),(2560,224,352),'Flag chamber')
        # Gate is permanently open for CTF. The actual alternate path goes over it.
        a.block(s,(2016,-320,0),(2080,-144,256),METAL);a.block(s,(2016,144,0),(2080,320,256),METAL)
        a.block(s,(2016,-144,192),(2080,144,256),METAL)
        r((1344,-736,0),(2496,-544,480),'High bypass')
        a.slope(s,1376,1952,-736,-544,0,256)
        r((1248,-736,0),(1440,-384,256))
        a.block(s,(1952,-736,224),(2496,-544,256),FLOOR)
        r((2304,-640,256),(2496,64,512))
        a.block(s,(2304,-544,224),(2496,-160,256),METAL)
        # Broad stepped descent joins the flag room without a lethal drop.
        a.slope(s,2112,2496,-160,64,0,256)
        a.block(s,(2528,-192,0),(2560,192,288),color)
        a.objectives(team,(s*2464,s*144,24),[(s*x,s*y,24) for x in [1728,1856,2240,2400] for y in [112,192]])
        a.pickup((s*1504,0,24));a.pickup((s*864,s*352,-168),'weapon_grenadelauncher')
        a.pickup((s*2048,s*-640,280),'item_armor2');a.light((s*2464,s*144,256),team)
        for x in [480,736,992]:
            for y in [-512,480]:a.block(s,(x,y,-192),(x+32,y+32,256),'med_wood4')
            a.block(s,(x,-512,256),(x+32,512,288),'med_wood4')
        # Uneven exposed rock ribs stay at chamber edges and above the walking lane.
        for x,z in [(512,256),(768,304),(1024,240)]:
            for y in [-544,496]:a.block(s,(x,y,z),(x+96,y+48,416),'med_rock3')
        for x in [1200,1504,1792,2240]:
            a.block(s,(x,-224,256),(x+24,224,288),'med_wood4')
    a.views=[([640,320,160],[1056,0,0],'excavation'),([1824,0,128],[2464,144,64],'gate')]
    a.routes=[{'name':'gate bypass','points':[[1344,-640,0],[2112,-640,256],[2400,-320,256],[2464,144,0]]}]
    return a.finish()

def crownreach():
    a=Map(5,'crownreach','Crownreach | Ancient War Grounds study')
    a.sky=True
    a.room((-2432,-896,-160),(2432,896,1024),'Moats and siege field')
    a.box((-2432,-896,-160),(2432,896,-80),'*water2')
    # Central island and two distinct crossings. Castle courtyards close sightlines.
    a.box((-384,-640,-160),(384,640,0),FLOOR)
    a.box((-1216,-128,-32),(1216,128,0),TRIM)
    for y in [-768,576]:a.box((-1408,y,-32),(1408,y+192,0),STONE)
    for s in [-1,1]:
        team=int(s>0);color=BLUE if team else RED
        a.block(s,(1216,-640,-160),(2304,640,0),FLOOR)
        a.block(s,(1216,-640,0),(1312,-192,384),STONE);a.block(s,(1216,192,0),(1312,640,384),STONE)
        a.block(s,(1216,-192,256),(1312,192,384),STONE)
        # Battlement walks, buttresses and newly drawn pointed gate arches.
        for y in [-640,448]:a.block(s,(1312,y,224),(2208,y+192,256),TRIM)
        a.block(s,(2208,-640,224),(2304,640,256),TRIM)
        for y in [-640,640]:
            for x in [1216,1472,1728,1984,2240]:a.block(s,(x,y-32,0),(x+64,y+32,416),STONE)
        # Projecting corner towers and crenellations make the two keeps legible.
        for y in [-592,592]:
            column(a,s*1264,s*y,104,0,416,STONE)
            column(a,s*1264,s*y,116,416,448,'med_csl_brk11')
        for y in range(-576,577,160):a.block(s,(1216,y,384),(1312,y+64,448),STONE)
        for y in [-448,256]:a.slope(s,1376,2080,y,y+192,0,256)
        for y in [-832,672]:a.slope(s,768,1280,y,y+160,-160,0)
        # A rear throne sanctuary with two flanking entrances and a raised flag.
        a.block(s,(2208,-640,0),(2304,-256,224),STONE);a.block(s,(2208,256,0),(2304,640,224),STONE)
        a.mirrored_room(s,(2304,-384,0),(2816,384,512),'Throne sanctuary')
        for y in [-384,352]:a.block(s,(2304,y,0),(2816,y+32,448),STONE)
        a.block(s,(2304,-384,448),(2816,384,480),'med_wood4')
        for x in [2336,2560,2784]:a.block(s,(x,-352,416),(x+24,352,448),'med_wood4')
        a.block(s,(2304,-384,-160),(2560,384,0),FLOOR)
        a.slope(s,2368,2560,-192,192,0,64)
        a.block(s,(2560,-256,0),(2784,256,64),FLOOR)
        a.block(s,(2784,-256,0),(2816,256,416),color)
        a.objectives(team,(s*2672,0,88),[(s*x,s*y,24) for x in [1456,1648,1840,2096] for y in [-128,128]])
        a.pickup((s*1728,0,24));a.pickup((s*2144,s*544,280),'weapon_grenadelauncher')
        a.pickup((s*2560,s*288,24),'item_health');a.pickup((s*2256,0,280),'item_armor2')
        a.light((s*2672,0,320),team)
    # Tall broken obelisk makes the central powerup island a recognisable meeting point.
    column(a,0,0,80,0,416,TRIM);column(a,0,0,112,416,448,STONE)
    a.pickup((0,384,24),'item_artifact_super_damage')
    a.views=[([-1088,-512,240],[1408,0,128],'siege field'),([2416,256,192],[2672,0,88],'sanctuary')]
    a.routes=[{'name':'battlements','points':[[1456,-128,0],[2048,-352,244],[2144,-544,256],[2240,0,256]]}]
    return a.finish()

def skyfracture():
    a=Map(6,'skyfracture','Skyfracture | Vertigo study','ind_brk01_brwn','met_brn_tile2')
    # Intentional vertical asymmetry: lower red foundry / upper blue observatory.
    # Three exits per base, two long ascending routes and a central stepped route.
    for team,x,z in [(0,-1536,0),(1,1536,512)]:
        a.room((x-640,-576,z),(x+640,576,z+640),'Lower foundry' if team==0 else 'Upper observatory')
        a.box((x-112,-112,z),(x+112,112,z+96),METAL)
        flag=(x+(-384 if team==0 else 384),0,z+24)
        a.objectives(team,flag,[(x+dx,y,z+24) for dx in [-320,-160,160,320] for y in [-320,320]])
        a.box((x+(-624 if team==0 else 592),-160,z+64),(x+(-592 if team==0 else 624),160,z+384),RED if team==0 else BLUE)
        for y in [-544,480]:a.box((x-576,y,z+288),(x+576,y+64,z+320),TRIM)
        for dx in [-544,-192,192,512]:
            for y in [-576,552]:a.box((x+dx,y,z),(x+dx+32,y+24,z+512),TRIM)
            a.box((x+dx,-576,z+512),(x+dx+32,576,z+544),TRIM)
        for y in [-560,544]:a.box((x-96,y,z+352),(x+96,y+16,z+368),'tlight12')
        a.pickup((x,384,z+24),'weapon_supernailgun');a.pickup((x,-384,z+24),'item_armor2');a.light((flag[0],0,z+256),team)
    # Base mouths connect to both flank ramps and the three-level central nexus.
    for y in [-832,640]:
        a.room((-1152,y,0),(-896,y+192,320));a.room((896,y,512),(1152,y+192,832))
        a.room((-1152,-832,0),(-960,832,320));a.room((960,-832,512),(1152,832,832))
        a.slope(1,-896,896,y,y+192,0,512)
        # Small landings/cover bays allow passing and resting along each route.
        a.room((-160,y-96,240),(160,y+288,640))
    a.room((-896,-160,0),(-640,160,256))
    a.room((-640,-384,0),(640,384,1024),'Vertical nexus')
    a.slope(1,-640,-64,-160,64,0,192)
    a.box((-64,-160,160),(256,64,192),METAL)
    a.slope(1,64,640,160,352,192,384)
    a.box((-64,64,160),(256,352,192),METAL)
    a.box((640,-160,352),(896,352,384),METAL)
    a.slope(1,640,1024,-352,-160,384,512)
    a.room((576,-352,384),(896,352,704))
    a.room((896,-352,512),(1152,0,800))
    # Optional instantaneous routes supplement, never replace, walkable slopes.
    a.tele((-2016,384,0),(-1920,480,96),'rise',(1664,384,512))
    a.tele((1920,-480,512),(2016,-384,608),'fall',(-1664,-384,0))
    a.pickup((0,0,216));a.pickup((0,704,280),'weapon_grenadelauncher')
    a.views=[([-576,256,480],[512,-128,384],'vertical nexus'),([1152,352,720],[1920,0,560],'observatory')]
    a.routes=[{'name':'north ascent','points':[[-1088,0,0],[-1008,736,0],[0,736,256],[1008,736,512],[1152,0,512]]},
              {'name':'south ascent','points':[[-1088,0,0],[-1008,-736,0],[0,-736,256],[1008,-736,512],[1152,0,512]]}]
    return a.finish()

BUILDERS=[tideworks,crucible,confluence,deepvault,crownreach,skyfracture]
