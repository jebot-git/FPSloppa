"""Editable classic Dust2 layout study. BSP29; Python 3, Pillow, numpy, ericw-tools.

Plan coordinates follow Dave Johnston's published CS1.6 overview (pixels, down=Y).
These are independently placed brushes, not decompiled retail geometry.
"""
from pathlib import Path
import argparse, hashlib, json, math, struct, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_tf_maps import Arena
from texture_replacements.build import miptex
from vesper.build import polygon
from de_texturing.materials import style, write_wad, bind_hash
ID = 'de_dust2_rebuilt'
OUT = ROOT / 'maps/Dust2Rebuilt'
SCALE = 6

def xyz(u, v, z=0): return ((u-400)*SCALE, (300-v)*SCALE, z)
def bounds(u,v,U,V,z,Z): return xyz(u,V,z), xyz(U,v,Z)
def fields(d): return '\n'.join('"%s" "%s"' % (k,v) for k,v in d.items())

class Dust(Arena):
    def __init__(self):
        super().__init__(ID, 'Dust2 | Classic layout reconstruction')
        self.rooms=[]; self.landmarks=[]; self.routes=[]; self.spawns=[]; self.views=[];self.models=[]
    def model(self,attributes,start):
        self.models.append((attributes,self.brushes[start:]));del self.brushes[start:]
    def face(self,points,texture):
        base=super().face(points,texture)
        if texture.startswith('d2_sign'):
            span=[max(p[j] for p in points)-min(p[j] for p in points) for j in range(3)]
            normal=min(range(3),key=lambda j:span[j]);u=1 if normal==0 else 0;v=1 if normal==2 else 2
            us=max(span[u],1)/128;vs=max(span[v],1)/128
            outward=np.cross(np.subtract(points[1],points[0]),np.subtract(points[2],points[0]))
            # Read letters left-to-right from the exposed side of every wall.
            flip=normal==0 and outward[0]<0 or normal==1 and outward[1]>0
            if flip:us=-us
            origin=max(p[u] for p in points) if flip else min(p[u] for p in points)
            return base.rsplit(' ',5)[0]+f' {-origin/us:g} {max(p[v] for p in points)/vs:g} 0 {us:g} {vs:g}'
        return base
    def room(self,u,v,U,V,z=0,Z=640,label=''):
        self.rooms.append(bounds(u,v,U,V,z,Z))
        if label:self.landmarks.append(dict(name=label,point=[(u+U)/2,(v+V)/2,z]))
    def block(self,u,v,U,V,z,Z,t='d2_stone'):
        self.box(*bounds(u,v,U,V,z,Z),t)
    def ramp(self,u,v,U,V,z,Z,axis='u'):
        lo,hi=bounds(u,v,U,V,min(z,Z),max(z,Z)+1)
        if axis=='u':self.ramp_x(lo[0],hi[0],lo[1],hi[1],z,Z,'d2_floor')
        else:
            start=len(self.brushes)
            self.ramp_x(-hi[1],-lo[1],lo[0],hi[0],z,Z,'d2_floor')
            # Rotate a wedge 90 degrees around Z; no face winding inversion.
            import re
            self.brushes[start]=re.sub(r'\( ([^()]+) \)',lambda m:'( %g %g %g )'%tuple_rotate(tuple(map(float,m[1].split()))),self.brushes[start])
    def stairs(self,u,v,U,V,z,Z,axis='u'):
        n=math.ceil(abs(Z-z)/12)
        for i in range(n):
            a=i/n;b=(i+1)/n;top=z+(Z-z)*(b if Z>z else a)
            if axis=='u':self.block(u+(U-u)*a,v,u+(U-u)*b,V,min(z,Z)-16,top,'d2_floor')
            else:self.block(u,v+(V-v)*a,U,v+(V-v)*b,min(z,Z)-16,top,'d2_floor')
    def crate(self,u,v,w=18,h=80,z=0):
        self.block(u-w/2,v-w/2,u+w/2,v+w/2,z,z+h,'d2_crate')
        for dz in [4,h-10]:self.block(u-w/2-.2,v-w/2-.2,u+w/2+.2,v+w/2+.2,z+dz,z+dz+6,'d2_iron')
    def opening(self,u,v,width,axis='u',z=0,doors=False):
        # Semicircular masonry arch, 120-unit vertical jamb and rounded crown.
        r=width*SCALE/2;center=xyz(u,v);bottom=z+120;top=z+120+r
        for i in range(8):
            a=math.pi*i/8;b=math.pi*(i+1)/8
            p=sorted([(round(r*math.cos(a),3),round(bottom+r*math.sin(a),3)),(round(r*math.cos(b),3),round(bottom+r*math.sin(b),3))])
            # Tiny outer arch facets are kept nondegenerate at the crown.
            ring=[(p[0][0],p[0][1]),(p[1][0],p[1][1]),(p[1][0],top+20),(p[0][0],top+20)]
            start=len(self.brushes)
            polygon(self,[(center[0]+x,h) for x,h in ring],-center[1]-10,-center[1]+10,'d2_trim','x')
            import re
            # polygon axis X -> plane across plan U; (oldX,oldY,Z) -> (oldY,-oldX,Z).
            self.brushes[start]=re.sub(r'\( ([^()]+) \)',lambda m:'( %g %g %g )'%rotate_arch(tuple(map(float,m[1].split())),center,axis),self.brushes[start])
        if doors:
            # Fixed open leaves preserve the historic gate gap; no animated choke.
            if axis=='u':
                for x in [u-width/2+1,u+width/2-3]:self.block(x,v-10,x+2,v+10,z,z+116,'d2_door')
            else:
                for y in [v-width/2+1,v+width/2-3]:self.block(u-10,y,u+10,y+2,z,z+116,'d2_door')
    def framed_opening(self,name,u,v,width,axis,z,doors,low,high,ceiling):
        # The shared opening primitive supplies only a crown. Dust's frames
        # also need grounded jambs, wall returns and a solid ceiling connection.
        self.opening(u,v,width,axis,z,doors)
        center=u if axis=='u' else v
        left,right=center-width/2,center+width/2
        crown=z+120+width*SCALE/2+20
        top=max(crown,ceiling)+1
        def piece(l,r,b,t,texture):
            if axis=='u':self.block(l,v-2,r,v+2,b,t,texture)
            else:self.block(u-2,l,u+2,r,b,t,texture)
        piece(low-.2,left+2,z-8,top,'d2_trim')
        piece(right-2,high+.2,z-8,top,'d2_trim')
        if ceiling>crown:piece(left,right,crown-1,top,'d2_stone')
        if not hasattr(self,'arch_checks'):self.arch_checks=[]
        points=[]
        # Probe exposed jamb faces, away from coplanar room seams and the
        # existing ceiling solids that bury the upper part of some frames.
        for along in [(low+left+2)/2+.25,(right-2+high)/2-.25]:
            for height in [z+2,z+60,z+122]:
                points.append([along,v,height] if axis=='u' else [u,along,height])
        self.arch_checks.append(dict(name=name,axis=axis,jambs=points,
                                     crown=[u,v,(crown+ceiling)/2] if ceiling>crown else None))
    def spawn(self,u,v,z=0,angle=0):
        p=[u,v,z];self.spawns.append(p);self.ent('info_player_deathmatch',xyz(u,v,z+4),angle=angle)
    def pickup(self,kind,u,v,z=0):self.ent(kind,xyz(u,v,z+24))
    def route(self,name,points):self.routes.append(dict(name=name,points=points))
    def shell(self):
        coords=[]
        for d in range(3):
            values={v[d] for r in self.rooms for v in r};values|={min(values)-64,max(values)+64};coords.append(sorted(values))
        shape=tuple(len(c)-1 for c in coords);solid=np.ones(shape,dtype=bool)
        for lo,hi in self.rooms:
            solid[tuple(slice(coords[d].index(lo[d]),coords[d].index(hi[d])) for d in range(3))]=False
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
                    if hi[2]>448:
                        self.box((lo[0],lo[1],max(lo[2],448)),hi,'sky_d2')
                        if lo[2]>=448:continue
                        hi=(hi[0],hi[1],448)
                    self.box(lo,hi,'d2_stone')
                    lines=self.brushes[-1].splitlines();lines[2]=lines[2].replace('d2_stone','d2_floor');self.brushes[-1]='\n'.join(lines)
        # Local ambient fixtures in covered spaces; sunlight handles the courts.
        for u,v,z,power in [(375,545,200,260),(385,495,220,260),(350,405,150,220),(350,350,150,180),(220,255,150,220),(480,155,160,180)]:
            self.ent('light',xyz(u,v,z),light=power,_color='1 .83 .62',delay=2)

def tuple_rotate(p):return (p[1],-p[0],p[2])
def rotate_arch(p,c,axis):
    q=(p[1],-p[0],p[2])
    return q if axis=='u' else (c[0]+q[1]-c[1],c[1]-q[0]+c[0],q[2])

def generate():
    a=Dust()
    # Long A and the A platform, upper left in the original author's overview.
    a.room(110,42,555,76,0,label='Long A')
    a.room(220,4,295,76,224,label='A rear terrace')
    a.room(150,76,238,205,224,label='A site')
    a.room(110,76,165,115,224)
    a.room(158,192,330,231,128,label='Short A bridge')
    a.room(238,42,398,76,0);a.ramp(238,42,398,76,224,0)
    a.block(110,42,238,76,0,224,'d2_floor')
    a.block(190,192,265,231,128,224,'d2_floor')
    a.stairs(265,192,330,231,224,128)
    # CT underpass occupies the same plan as the elevated A approach.
    a.room(190,192,232,302,0,196,'CT spawn / underpass')
    a.room(190,154,220,230,0,196)
    # CT-to-A ramp emerges through the west side of the bridge.
    a.room(158,154,190,286,0)
    a.ramp(158,192,190,286,224,0,'v')
    a.block(158,154,190,192,0,224,'d2_floor')
    a.room(158,154,200,192,224)
    # Pit and the dog-leg through the two long doors.
    a.room(390,76,433,175,0,label='Long corner')
    a.room(433,80,538,126,-64,label='Long pit')
    a.ramp(433,80,474,126,0,-64)
    a.room(414,123,493,153,0,240)
    a.room(452,145,518,195,0,240,label='Long doors')
    a.room(492,157,614,214,0,label='Outside long')
    a.room(533,208,616,247,0)
    a.room(608,218,690,257,0)
    a.room(641,244,699,409,0,label='T approach')
    # T ramp down to top mid, and the eastern spawn court.
    a.room(608,408,697,572,0,label='T spawn')
    a.room(463,474,650,559,64)
    a.block(608,408,697,482,0,128,'d2_floor')
    a.block(641,313,699,409,0,128,'d2_floor')
    a.block(608,482,697,572,0,128,'d2_floor')
    a.ramp(550,474,608,559,64,128)
    # Mid slopes down toward CT doors. Catwalk is a separate raised ledge.
    a.room(326,313,654,344,0,label='Mid')
    a.ramp(326,313,570,344,0,128)
    a.block(570,313,654,344,0,128,'d2_floor')
    a.room(608,286,654,344,0)
    a.ramp(608,257,699,313,0,128,'v')
    a.room(330,284,608,313,128,label='Catwalk')
    a.room(330,192,356,313,128,label='Short stairs approach')
    a.room(294,301,330,342,0,240,label='Mid double doors')
    # CT connector follows the rock face toward B doors; no modern shortcut.
    a.room(167,288,294,344,0,label='CT mid')
    a.room(180,340,253,445,0,label='CT to B')
    a.ramp(180,370,253,445,0,64,'v')
    a.room(223,434,251,486,64,304,label='B doors')
    a.room(148,340,180,454,0)
    a.ramp(148,340,180,454,0,64,'v')
    # B site, rear platform and window. The window is an optional jump route.
    a.room(135,467,283,569,64,label='B site')
    a.room(90,532,150,569,64,label='B back platform')
    a.block(90,532,175,547,64,88,'d2_floor')
    a.room(150,445,178,477,104,276,label='B window')
    a.block(150,445,178,477,64,104,'d2_trim')
    a.block(153,435,173,445,64,84,'d2_crate')
    a.block(153,477,173,487,64,84,'d2_crate')
    # Upper tunnels T entry, offset exit into B and half-turn lower stairs.
    a.room(370,499,470,535,64,288,label='Upper tunnel entrance')
    a.room(365,476,409,579,64,288,label='Upper tunnels')
    a.room(278,548,387,579,64,288,label='B tunnel exit')
    a.room(275,497,326,531,64,288)  # B's traditional deep side recess.
    a.room(370,452,405,500,0,288,label='Tunnel stair upper flight')
    a.stairs(370,452,405,500,0,64,'v')
    a.room(344,437,405,455,0,224,label='Tunnel stair landing')
    a.room(335,340,372,438,0,224,label='Lower tunnels')
    # Doors and semi-circular arches, scaled to a standing FPSloppa capsule.
    from classic_de.restoration import dust2_mid_doors
    dust2_mid_doors(a)
    # Separate the inner Long doorway from the overlapping pit room. Its
    # north return joins the solid corner at u=493; the pit escape stays open.
    a.block(433,122,494,126,-72,448,'d2_stone')
    for row in [('B doors',237,458,28,'u',64,True,223,251,304),
                ('Long inner',433,139.5,27,'v',0,True,124,153,240),
                ('Long outer',508,177,36,'v',0,True,145,214,448),
                ('B tunnel',355,563,30,'v',64,False,548,579,288),
                ('Upper tunnel',430,517,34,'v',64,False,499,535,288),
                ('Lower tunnel',353.5,350,37,'u',0,False,335,372,224),
                ('CT underpass',211,241,40,'u',0,False,190,232,196)]:
        a.framed_opening(*row)
    # Site cover, goose corner, middle box, tunnel pillar and outside-long stack.
    from classic_de.restoration import dust2_cover
    dust2_cover(a)
    a.block(381,528,389,540,64,288,'d2_trim')
    rock=[xyz(u,v)[:2] for u,v in [(145,345),(153,358),(159,389),(154,423),(148,447),(141,418)]]
    polygon(a,list(reversed(rock)),0,365,'d2_rock')
    # Thin decorative cornices and stone buttresses against selected exterior walls.
    for u,v,U,V,z in [(150,115,153,181,392),(235,80,238,188,392),(520,157,614,160,368),(695,258,699,395,368),(135,467,138,530,352),(278,469,282,493,352)]:
        a.block(u,v,U,V,z,z+12,'d2_trim')
    # A/B markers are brush faces with original simple painted glyphs.
    a.block(148.8,115,150,139,265,337,'d2_signa')
    a.block(133.8,477,135,501,112,184,'d2_signb')
    # Cross marks on floor: callouts only, no unsupported bomb-defuse entities.
    for u,v,z in [(184,132,224),(184,531,64)]:
        a.block(u-5,v-1,u+5,v+1,z,z+.5,'d2_red')
        a.block(u-1,v-5,u+1,v+5,z,z+.5,'d2_red')
    for p in [(665,526,128),(626,543,128),(512,535,64),(475,495,64),(382,566,64),(287,563,64),(218,523,64),(151,557,64),(205,392,19),(273,321,0),(211,269,0),(180,169,224),(177,91,224),(275,58,172),(501,103,-64),(568,192,0),(674,281,55),(500,329,91),(461,297,128),(342,258,128),(350,392,0)]:a.spawn(*p)
    a.ent('info_player_start',xyz(665,526,132),angle=180)
    for kind,u,v,z in [('weapon_supershotgun',512,535,64),('weapon_nailgun',674,281,55),('weapon_rocketlauncher',177,155,224),('weapon_rocketlauncher',218,523,64),('weapon_supernailgun',350,392,0),('weapon_grenadelauncher',461,297,128),('weapon_lightning',501,103,-64),('item_armor2',184,132,224),('item_armor2',184,531,64),('item_armor1',382,566,64),('item_health',211,269,0),('item_health',568,192,0),('item_health',626,543,128),('item_health',205,392,19),('item_shells',475,495,64),('item_spikes',350,370,0),('item_rockets',273,58,175),('item_cells',522,103,-64)]:a.pickup(kind,u,v,z)
    a.route('T spawn through long doors to A',[[650,525,128],[650,485,128],[650,420,128],[650,390,128],[650,330,128],[650,280,52],[650,240,0],[627,232,0],[615,223,0],[580,223,0],[570,188,0],[480,183,0],[480,137,0],[410,137,0],[410,58,0],[275,58,172],[220,58,224],[182,100,224]])
    a.route('T spawn directly to top mid',[[650,525,128],[650,390,128],[650,329,128],[620,329,128]])
    a.route('T spawn through upper tunnels to B',[[520,520,64],[430,517,64],[387,517,64],[375,554,64],[300,563,64],[264,563,64],[218,531,64]])
    a.route('Lower tunnel half-turn stairs to upper',[[350,365,0],[350,410,0],[350,447,0],[387,447,0],[387,490,52],[387,515,64]])
    a.route('Mid slope and double doors to CT',[[620,329,128],[550,329,118],[420,329,49],[380,322,28],[342,322,8],[313,322,0],[270,322,0],[211,310,0],[211,265,0]])
    a.route('Top mid via catwalk and short stairs to A',[[600,297,128],[475,297,128],[342,297,128],[342,213,128],[308,213,164],[275,213,213],[243,213,224],[215,213,224],[215,183,224]])
    a.route('CT ramp to A',[[174,277,21],[174,237,117],[174,205,193],[174,180,224],[180,169,224]])
    a.route('CT through B doors',[[211,310,0],[207,356,0],[207,410,34],[207,440,60],[237,440,64],[237,476,64],[237,519,64]])
    a.route('Long pit escape',[[515,105,-64],[450,105,-26],[410,105,0]])
    a.views=[dict(name='a-site',eye=[176,189,278],look=[215,100,266]),dict(name='long-a',eye=[408,59,54],look=[184,65,262]),dict(name='b-site',eye=[259,525,118],look=[150,499,125]),dict(name='mid',eye=[581,332,182],look=[295,320,48]),dict(name='upper-tunnels',eye=[395,511,118],look=[373,560,115]),dict(name='short-a',eye=[342,254,182],look=[287,208,240])]
    a.views.extend([dict(name='mid-double-doors',eye=[362,321,66],look=[313,321,105]),dict(name='mid-double-doors-ct',eye=[270,321,66],look=[315,321,105])])
    a.shell();return a

def textures():
    rng=np.random.default_rng(1602); palette=(ROOT/'deathmatch/maps/palette.lmp').read_bytes()
    quant=Image.new('P',(1,1));quant.putpalette(palette[:224*3]+palette[:3]*32)
    out={}
    for name,base in [('d2_stone',(176,145,101)),('d2_floor',(167,145,109)),('d2_trim',(111,88,58)),('d2_crate',(113,91,56)),('d2_door',(88,68,40)),('d2_iron',(55,49,40)),('d2_signa',(176,145,101)),('d2_signb',(176,145,101)),('d2_red',(160,8,8)),('d2_rock',(128,107,78)),('sky_d2',(99,124,149))]:
        # Periodic multiscale relief gives worn plaster/stone instead of white noise.
        y,x=np.mgrid[:128,:128];noise=rng.normal(0,2,(128,128))
        for freq,amp in [(1,7),(2,4),(5,3),(13,1.5)]:
            phase=rng.uniform(0,math.tau,2)
            noise+=amp*np.sin(x*math.tau*freq/128+phase[0])*np.cos(y*math.tau*(freq+1)/128+phase[1])
        if name=='d2_rock':noise+=12*np.sin(y*.19+4*np.sin(x*.049))+5*np.sin(y*.65+x*.15)
        im=Image.fromarray(np.clip(np.array(base)+noise[:,:,None],0,255).astype('uint8'));d=ImageDraw.Draw(im)
        if name in ['d2_stone','d2_trim','d2_floor']:
            height=32 if name!='d2_floor' else 64
            for y in range(0,128,height):
                d.line((0,y,127,y),fill=tuple(int(c*.82) for c in base),width=1)
                d.line((0,y+2,127,y+2),fill=tuple(min(255,int(c*1.05)) for c in base))
                for x in range(-32 if y//height%2 else 0,128,64):d.line((x,y,x,y+height),fill=tuple(int(c*.88) for c in base))
        if name in ['d2_crate','d2_door']:
            for x in range(0,128,16):d.line((x,0,x,128),fill=(56,43,25),width=2)
            for y in [5,116]:d.rectangle((0,y,127,y+8),fill=(49,43,33))
            if name=='d2_crate':
                for pts in [(0,0,127,127),(0,127,127,0)]:d.line(pts,fill=(145,114,65),width=10)
            for y in [9,120]:
                for x in [8,36,90,119]:d.ellipse((x-2,y-2,x+2,y+2),fill=(30,28,23))
        if name.startswith('d2_sign'):
            ink=(160,8,8)
            if name.endswith('a'):
                d.line([(28,106),(64,20),(102,106)],fill=ink,width=11);d.line((44,76,85,76),fill=ink,width=10)
            else:
                d.line((33,22,33,106),fill=ink,width=11);d.line([(33,25),(78,25),(96,39),(96,53),(78,65),(33,65),(80,65),(98,81),(98,94),(80,106),(33,106)],fill=ink,width=10)
        out[name]=im.quantize(palette=quant,dither=Image.Dither.NONE)
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler-dir',type=Path,required=True);p.add_argument('--fast-vis',action='store_true');p.add_argument('--install',action='store_true');args=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);logs=ROOT/'test-results/dust2';logs.mkdir(parents=True,exist_ok=True)
    from classic_de.ballistics import capture,embed
    a=generate();ballistics=capture(a);style(a,'desert')
    tiles=textures()
    write_wad(a,OUT,'dust2.wad',tiles)
    world=dict(classname='worldspawn',message=a.title,wad='dust2.wad',_fpsloppa_bake='1',_fpsloppa_atlas='2048',_fpsloppa_light_response='quake',_minlight='28',_sunlight='135',_sunlight_color='1 .91 .76',_sun_mangle='125 -58 0',_sunlight2='35',_sunlight2_color='.68 .79 1',_bounce='1')
    source=OUT/(ID+'.map');bsp=OUT/(ID+'.bsp')
    source.write_text('{\n'+fields(world)+'\n'+'\n'.join(a.brushes)+'\n}\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in a.entities)+'\n')
    for tool,flags in [('qbsp',['-wadpath',str(OUT),str(source),str(bsp)]),('vis',['-threads','4',*(['-fast'] if args.fast_vis else []),str(bsp)]),('light',['-threads','4','-extra','-bspxlit',str(bsp)])]:
        print(tool,flush=True)
        with (logs/(tool+'.log')).open('w') as log:subprocess.run([str(args.compiler_dir.resolve()/tool),*flags],stdout=log,stderr=subprocess.STDOUT,check=True)
    log=(logs/'qbsp.log').read_text();assert 'LEAK' not in log.upper() and "Couldn't create brush faces" not in log,log[-3000:]
    embed(bsp,ballistics)
    raw=bsp.read_bytes();assert struct.unpack_from('<i',raw)[0]==29 and len(raw)<25_000_000
    report=dict(id=ID,title=a.title,format=29,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),brushes=len(a.brushes),entities=len(a.entities),spawns=a.spawns,landmarks=a.landmarks,routes=a.routes,views=a.views,full_vis=not args.fast_vis,reconstruction=True,reference='https://www.johnsto.co.uk/design/making-dust2/',modes=['dm','tdm','ig','ft','if','de'],textures='texture-sources.json; shared art pass in tools/de_texturing/materials.py',scale='6 Quake units per reference-plan unit; 32 Quake units per Godot metre')
    report['door_checks']=a.door_checks
    report['arch_checks']=a.arch_checks
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('BUILT',len(raw),'bytes;',len(a.brushes),'brushes;',len(a.spawns),'spawns',flush=True)
    if args.install:
        import shutil
        shutil.copy2(bsp,ROOT/'maps'/bsp.name)
        path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(path.read_text());catalog=[r for r in catalog if r['id']!=ID]
        catalog.append(dict(id=ID,title=a.title,modes=report['modes'],path='res://maps/'+bsp.name,scene='res://maps/cache/'+ID+'.scn',sha256=report['sha256'],distribution='base',expansion='dust2-rebuilt'))
        path.write_text(json.dumps(catalog,indent=2)+'\n')
        bind_hash(ID,report['sha256'])
if __name__=='__main__':main()
