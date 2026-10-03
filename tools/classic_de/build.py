"""Independently brushed CS1.6 layout studies; original textures, BSP29 + VIS/RGB.

Plan coordinates use the published classic overviews, six Quake units per plan
unit. This is an editable reconstruction, not decompiled retail geometry.
"""
from pathlib import Path
import argparse, hashlib, json, math, shutil, struct, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from dust2_rebuild.build import Dust, xyz, fields
from texture_replacements.build import miptex
from de_texturing.materials import style, write_wad, bind_hash

OUT = ROOT / 'maps/ClassicDE'
REFERENCE = 'https://steamcommunity.com/sharedfiles/filedetails/?id=913388004'

def engine(p):
    u,v,z=p
    return [(v-300)*6/32,z/32+.05,(400-u)*6/32]

class Classic(Dust):
    def __init__(self, name, theme):
        super().__init__()
        self.name='de_'+name+'_rebuilt';self.title=name.title()+' | Classic layout reconstruction'
        self.theme=theme;self.site_bounds=[];self.team_starts=[[],[]];self.yaws=[0,math.pi];self.site_markings=[]
    def site(self, u,v,U,V,z,center=None,wall=None):
        self.site_bounds.append([u,v,U,V,z,z+128])
        c=center or [(u+U)/2,(v+V)/2,z]
        self.landmarks.append(dict(name='Site '+('A' if len(self.site_bounds)==1 else 'B'),point=c))
        # Surface markings, with explicit backing walls (site bounds are often
        # inside a larger room, so their edges are not necessarily walls).
        tex='d2_signa' if len(self.site_bounds)==1 else 'd2_signb'
        assert wall is not None
        a,b,A,B,normal=wall
        # Embed the back of the paint brush into the masonry/metal shell.
        if normal[0]<0:A+=.3
        elif normal[0]>0:a-=.3
        elif normal[1]<0:B+=.3
        else:b-=.3
        self.block(a,b,A,B,z+40,z+132,tex)
        x,y,height=c
        self.block(x-5,y-1,x+5,y+1,height,height+.5,'d2_red')
        self.block(x-1,y-5,x+1,y+5,height,height+.5,'d2_red')
        face=[a if normal[0]<0 else A if normal[0]>0 else (a+A)/2,b if normal[1]<0 else B if normal[1]>0 else (b+B)/2,z+86]
        self.site_markings.append(dict(site='A' if len(self.site_bounds)==1 else 'B',cross=c,wall=face,normal=normal))
        for a,b,A,B in [(u+3,v+3,U-3,v+3.5),(u+3,V-3.5,U-3,V-3)]:self.block(a,b,A,B,z,z+.4,'mark')
    def team(self,role,u,v,z=0):
        for j in range(2):
            for i in range(4):
                p=[u+i*7,v+j*9,z];self.team_starts[role].append(p);self.spawn(*p)
    def pillar(self,u,v,z=0,height=240,width=6):
        self.block(u-width,v-width,u+width,v+width,z,z+16,'trim')
        self.block(u-width+.6,v-width+.6,u+width-.6,v+width-.6,z+16,z+height-12,'wall')
        self.block(u-width,v-width,u+width,v+width,z+height-12,z+height,'trim')
    def window(self,u,v,width=18,z=72,axis='u'):
        if axis=='u':
            self.block(u,v,u+width,v+.5,z,z+82,'window')
            for x in [u-.5,u+width/2,u+width]:self.block(x,v-.2,x+.5,v+.8,z-3,z+85,'trim')
            self.block(u-.5,v-.2,u+width+.5,v+.8,z-3,z+1,'trim')
        else:
            self.block(u,v,u+.5,v+width,z,z+82,'window')
            for y in [v-.5,v+width/2,v+width]:self.block(u-.2,y,u+.8,y+.5,z-3,z+85,'trim')
    def tank(self,u,v,z=0,r=10,h=144):
        # Twelve-sided native convex column, including base and upper rim.
        from vesper.build import polygon
        for base,top,radius,tex in [(z,z+8,r+1,'trim'),(z+8,z+h-8,r,'tank'),(z+h-8,z+h,r+1,'trim')]:
            poly=[(xyz(u+math.cos(i*math.tau/12)*radius,v,0)[0],xyz(u,v+math.sin(i*math.tau/12)*radius,0)[1]) for i in range(12)]
            polygon(self,list(reversed(poly)),base,top,tex)
    def finalize(self):
        # Props and traversal surfaces remain solid collision but do not split
        # visibility portals. The room shell alone seals the BSP.
        self.detail_brushes=self.brushes;self.brushes=[]
        self.shell()
        # Reuse the convex shell writer, replacing its desert defaults per map.
        replacements={'d2_stone':'wall','d2_floor':'floor','d2_trim':'trim','d2_crate':'crate','d2_iron':'metal','d2_door':'wood','sky_d2':'sky_de'}
        self.brushes=[replace_tokens(b,replacements) for b in self.brushes]
        self.detail_brushes=[replace_tokens(b,replacements) for b in self.detail_brushes]
        # Remove Dust2-only fixtures and place fixtures in every authored room.
        self.entities=[e for e in self.entities if e['classname']!='light']
        for lo,hi in self.rooms:
            if hi[2]-lo[2]<100:continue
            self.ent('light',((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,min(lo[2]+180,hi[2]-24)),light=210,delay=2,_color='1 .88 .72' if self.theme=='village' else '.79 .88 1')
        if self.theme=='rail':
            # Freight cars shadow both markers. Bake a local site light so the
            # red paint remains readable from ordinary standing viewpoints.
            for mark in self.site_markings:
                u,v,z=mark['wall'];du,dv=mark['normal']
                self.ent('light',xyz(u+du*12,v+dv*12,mark['cross'][2]+140),light=220,delay=2,_color='1 .9 .75')
        start=self.team_starts[0][0];self.ent('info_player_start',xyz(start[0],start[1],start[2]+4))
        return self

def replace_tokens(s, replacements):
    for a,b in replacements.items():s=s.replace(' '+a+' ',' '+b+' ')
    return s

def nuke():
    a=Classic('nuke','industrial')
    # Classic canyon outside wraps the industrial core, T west, CT northeast.
    for r in [(10,305,110,365),(95,325,300,364),(265,290,354,396),(303,370,435,455),(380,425,615,545),(551,325,620,470),(603,222,815,280),(590,249,639,344)]:a.room(*r,label='Outside canyon')
    a.room(352,280,433,355,0,208,'Lobby');a.room(358,225,433,283,0,208,'Radio')
    a.room(402,155,454,244,0,256);a.room(434,75,543,229,0,320,'Ramp room')
    a.room(435,230,565,399,0,384,'Upper reactor A')
    a.room(420,285,443,344,0,150,'Hut');a.room(397,350,471,378,0,176,'Squeaky')
    a.room(550,230,605,315,0,384,'Heaven access')
    a.room(442,233,601,264,192,384,'Heaven');a.stairs(567,264,604,294,192,0,'v')
    # Continuous landing joins the high stair tread to the catwalk. The
    # access ceiling above must clear a standing capsule on the top tread.
    a.block(445,233,604,266,176,192,'metal')
    a.room(617,414,729,527,0,256,'Garage');a.room(595,435,631,490,0,240)
    # Full lower level beneath A, reached by the classic ramp and outside tunnel.
    a.room(435,261,565,399,-256,-48,'Lower reactor B')
    a.room(459,148,530,279,-256,224,'Ramp descent');a.ramp(459,148,530,269,0,-256,'v')
    a.room(535,380,620,420,-256,-48,'Lower connector')
    a.room(587,402,640,565,-256,-48);a.room(620,524,749,565,-256,-48,'Outside tunnel')
    a.room(720,440,749,556,-256,224,'Tunnel stairs')
    a.room(704,430,749,454,0,224,'Tunnel stair landing')
    # Overlapping garage/stair air volumes remove the garage floor here.
    # Author a landing across that seam and enclose the descending flight,
    # rather than leaving a lateral shaft along the upper garage floor.
    a.block(704,430,749,454,-16,0,'floor')
    a.stairs(720,452,749,547,0,-256,'v')
    a.block(718,454,721,529,-256,224,'wall')
    # A broad, crouch-height vent descent preserves the A/B shortcut without
    # requiring ladder mechanics the engine does not currently provide.
    a.room(399,379,453,410,-256,108,'Vent');a.room(399,388,428,486,-256,108)
    a.ramp(399,388,428,477,0,-256,'v');a.room(415,449,450,486,-256,-48)
    a.room(434,396,460,486,-256,-48)
    from classic_de.restoration import nuke_cover
    nuke_cover(a)
    # Probe across the top tread/landing seam, including both stair edges.
    for u in [570,585,600]:
        for v in [263.5,264,264.5,265.5]:
            a.structure_checks.append(dict(name='Heaven stair landing continuous',start=[u,v,200],end=[u,v,172],at=[u,v,192]))
    from classic_de.study_layout import nuke as study_nuke
    study_nuke(a)
    # The reference canyon/CT approaches turn around solid corners. The
    # rectangular room approximation otherwise exposes whole spawn corridors.
    for u,v,U,V in [(140,325,152,347),(214,346,226,364),
                    (700,222,712,257),(660,247,672,280)]:
        a.block(u,v,U,V,0,256,'wall')
    for side,targets in [(0,[[285,333,48],[310,350,48],[385,320,48]]),
                         (1,[[615,235,48],[615,260,48],[608,306,48]])]:
        start_u,start_v=(32,329) if side==0 else (745,240)
        for j in range(2):
            for i in range(4):
                for target in targets:
                    a.sightline_checks.append(dict(name=f'{"T" if side==0 else "CT"} spawn corner blocks lane {i},{j} to {target[:2]}',start=[start_u+i*7,start_v+j*9,48],end=target,clear=False))
    for u in [722,724,734,746,748.5]:
        for v in [438,440,450,453,454]:
            a.structure_checks.append(dict(name='Underground stair landing has no gap',start=[u,v,8],end=[u,v,-28],at=[u,v,0]))
    for v in [456,470,500,525]:
        for z in [24,60,120]:
            a.structure_checks.append(dict(name='Garage side of underground stairs is sealed',start=[712,v,z],end=[725,v,z],at=[718,v,z]))
    # Roof trusses, wall vents and riveted exterior panels.
    for v in [270,310,350,387]:a.block(435,v,565,v+2,328,342,'metal')
    for u in [444,477,510,543]:a.block(u,398.5,u+18,399.2,60,116,'vent')
    a.site(435,270,565,392,0,[478,348,0],wall=(495.5,398.6,509.5,398.8,[0,-1]))
    a.site(435,275,565,398,-256,[479,351,-256],wall=(436.2,335,436.4,357,[1,0]))
    a.team(0,32,329);a.team(1,745,240)
    t_approach=[[62,338,0],[130,356,0],[166,356,0],[180,334,0],[240,334,0],[320,340,0]]
    ct_approach=[[766,249,0],[726,268,0],[686,268,0],[684,235,0],[645,235,0],[615,249,0]]
    a.route('T lobby to A',t_approach+[[380,323,0],[427,320,0],[461,320,0],[478,348,0]])
    a.route('T radio ramp to B',t_approach+[[385,316,0],[408,278,0],[408,248,0],[418,240,0],[420,195,0],[448,195,0],[448,143,0],[490,143,0],[490,270,-256],[457,285,-256],[457,350,-256],[479,351,-256]])
    a.route('CT outside to A',ct_approach+[[608,306,0],[578,306,0],[552,306,0],[548,367,0],[478,367,0],[478,348,0]])
    a.route('CT garage tunnel to B',ct_approach+[[608,379,0],[608,480,0],[704,480,0],[706,443,0],[734,443,0],[734,550,-256],[607,548,-256],[606,408,-256],[585,408,-256],[585,484,-256],[548,484,-256],[547,372,-256],[479,372,-256],[479,351,-256]])
    for u in [724,734,746]:
        a.route(f'Underground stair landing and flight {u}',[[706,443,0],[u,443,0],[u,453,0],[u,550,-256],[734,557,-256]])
    a.route('Heaven stairs to catwalk',[[585,306,0],[585,291,19],[585,275,122],[585,260,192],[552,245,192],[458,245,192]])
    a.views=[dict(name='nuke-upper',eye=[455,380,80],look=[515,293,95]),dict(name='nuke-lower',eye=[452,383,-175],look=[525,302,-154]),dict(name='nuke-outside',eye=[575,497,75],look=[401,390,90])]
    a.views += [dict(name='nuke-underground-landing',eye=[710,437,54],look=[735,485,-65]),
                dict(name='nuke-stair-side',eye=[697,480,54],look=[725,490,45]),
                dict(name='nuke-t-spawn-corners',eye=[90,338,54],look=[230,345,54]),
                dict(name='nuke-ct-spawn-corners',eye=[756,249,54],look=[658,250,54])]
    return a.finalize()

def inferno():
    a=Classic('inferno','village')
    # CS1.6 plan: banana northwest, A/pit east, apartments on the south flank.
    for r,label in [((6,383,83,491),'T spawn'),((44,469,80,625),'T alley'),((71,414,235,452),'T ramp'),((207,374,303,439),'T slope'),((278,294,326,428),'Banana lower'),((293,255,343,314),'Banana bend'),((314,216,365,271),'Banana'),((336,172,413,237),'Car corner'),((365,123,407,203),'Banana upper'),((302,28,397,142),'B site'),((358,3,493,42),'B back'),((395,66,638,110),'CT arch'),((607,90,715,266),'CT spawn'),((545,213,635,301),'Library approach'),((493,324,700,370),'Arch lane'),((289,408,536,453),'Mid'),((492,347,540,535),'Top mid'),((536,485,699,539),'A route'),((581,398,711,489),'A site'),((616,529,713,596),'Pit')]:a.room(*r,label=label)
    a.room(156,445,195,629,0,240,'Second mid');a.room(72,595,181,630,0)
    a.room(182,511,426,556,0,240,'Alt mid');a.room(400,448,439,585,0,240)
    a.room(237,455,302,519,0,200,'T house');a.room(300,454,335,518,0,240)
    a.room(438,554,606,589,96,312,'Apartments');a.room(395,584,476,622,0,312,'Apartment stair')
    a.stairs(395,584,476,610,0,96);a.room(577,506,614,592,96,312,'Balcony')
    a.room(578,486,618,541,0,312);a.stairs(580,487,609,546,0,96,'v')
    a.room(577,361,618,410,0,240);a.room(580,265,614,345,0,240,'Library')
    from classic_de.restoration import inferno_cover
    inferno_cover(a)
    from classic_de.study_layout import inferno as study_inferno
    # Houses: plaster bands, shutters, overhanging timber balcony and tiled roofs.
    from classic_de.restoration import inferno_facades
    inferno_facades(a)
    study_inferno(a)
    a.block(613,548,615,588,96,114,'wood')
    for v in [550,562,574,586]:a.block(613,v,615,v+.7,114,154,'wood')
    for u,v in [(302,132),(394,132),(616,490),(703,490)]:a.pillar(u,v,0,200,2)
    # Site pipeline and the low masonry lip beside the classic pit.
    a.block(306,31,389,33,166,183,'metal');a.block(697,404,700,484,152,168,'metal')
    a.block(613,531,617,590,0,24,'trim')
    a.site(581,398,711,489,0,[646,452,0],wall=(710.6,436,710.8,458,[-1,0]))
    a.site(302,30,397,142,0,[372,96,0],wall=(302.2,75,302.4,97,[1,0]))
    a.team(0,25,422);a.team(1,658,171)
    a.route('T banana to B',[[46,431,0],[151,430,0],[257,423,0],[303,402,0],[303,303,0],[332,256,0],[360,230,0],[386,220,0],[387,162,0],[372,96,0]])
    a.route('T mid to A',[[46,431,0],[151,430,0],[257,423,0],[510,430,0],[510,515,0],[563,514,0],[590,479,0],[646,452,0]])
    a.route('Apartments balcony to A',[[175,579,0],[175,540,0],[407,540,0],[403,579,0],[400,596,6],[470,596,96],[458,571,96],[594,571,96],[594,493,0],[646,452,0]])
    a.route('CT to B',[[679,180,0],[675,99,0],[419,87,0],[372,96,0]])
    a.route('CT library to A',[[679,180,0],[664,249,0],[595,249,0],[595,346,0],[596,383,0],[646,452,0]])
    a.views=[dict(name='inferno-a',eye=[590,476,70],look=[675,431,74]),dict(name='inferno-banana',eye=[306,333,75],look=[365,207,84]),dict(name='inferno-apartments',eye=[546,571,172],look=[603,535,162]),dict(name='inferno-mid-facades',eye=[407,445,74],look=[412,408,112]),dict(name='inferno-b-cover',eye=[385,115,72],look=[325,66,96])]
    return a.finalize()

def aztec():
    from classic_de.restoration import aztec_layout
    return aztec_layout(Classic('aztec','ruins')).finalize()

def train():
    a=Classic('train','rail')
    for r,z,Z,label in [((8,12,94,110),0,640,'T spawn'),((74,61,245,108),0,640,'T corridor'),((204,29,560,78),0,640,'Ivy approach'),((538,64,575,238),0,640,'Ivy'),((207,104,250,220),0,288,'Main'),((173,164,250,397),0,304,'Ladder room approach'),((245,194,676,363),0,640,'Outer yard A'),((635,228,678,482),0,640,'CT alley'),((577,466,678,583),0,384,'CT spawn'),((405,356,447,461),0,240,'Connector'),((416,416,581,464),0,240,'Z connector'),((493,443,536,494),0,240,'B entry'),((241,467,584,584),0,384,'Inner yard B'),((179,585,642,616),0,240,'Back platform'),((165,447,251,600),0,288,'B halls'),((174,395,215,468),0,288,'Lower B approach')]:a.room(*r,z,Z,label)
    a.room(168,265,195,399,96,304,'Upper hall');a.stairs(168,271,194,333,0,96,'v')
    a.block(168,333,195,399,80,96,'floor')
    a.room(168,391,233,470,96,320,'Upper B ramp');a.ramp(168,391,233,468,96,0,'v')
    a.room(233,391,252,481,0,288,'Lower B bypass')
    a.room(530,441,574,507,0,240,'B entry flank')
    # Open-bottom freight cars preserve the recognizable crouch lanes; wheels
    # and chassis are all native brushes. End steps provide ladder-free access.
    def wagon(u,v,length=92,flat=False,color='wagon'):
        a.block(u,v+2,u+length,v+20,48,58,'metal')
        if not flat:a.block(u+1,v+1,u+length-1,v+21,58,146,color)
        else:
            a.block(u+15,v+5,u+length-15,v+17,58,101,'tank')
        for x in [u+9,u+length-17]:
            for y in [v+1,v+18]:a.block(x,y,x+9,y+3,0,48,'metal')
        for z in range(8,57,8):a.block(u-13+z/8,v+6,u,v+16,0,z,'metal')
    # Classic outer arrangement: one rear, two middle, two front cars.
    # Inner yard has three parallel pairs, including two low bomb/flat cars.
    for u,v,l,f,c in [(380,218,108,False,'wagon'),(320,265,104,False,'wagon2'),(447,265,104,False,'wagon'),(265,330,108,False,'wagon2'),(500,330,98,True,'wagon'),(279,475,102,False,'wagon2'),(423,475,112,False,'wagon'),(310,516,99,True,'wagon'),(432,516,105,False,'wagon2'),(277,557,105,True,'wagon'),(405,557,105,False,'wagon')]:wagon(u,v,l,f,c)
    for v in [228,276,341,486,527,568]:
        for y in [v-5,v+5]:a.block(249,y,675 if v<400 else 580,y+.6,.1,1.2,'metal')
        for u in range(253,582,10):a.block(u,v-8,u+1.5,v+8,0,.3,'wood')
    for u in [252,342,432,522,578]:
        a.block(u,468,u+2,584,308,324,'metal')
    # The B entry and CT flank remove parts of the north wall. Mount windows
    # only on its remaining solid spans, with frames embedded in the shell.
    a.structure_checks=[]
    for u in [262,342,382,432,470]:
        a.window(u,466.8,18,175)
        a.structure_checks.append(dict(name='Train window attached to north wall',start=[u+9,469,216],end=[u+9,466,216],at=[u+9,467.6,216]))
    a.crate(206,374,16,94);a.crate(600,512,15,78)
    from classic_de.restoration import train_details
    train_details(a)
    a.site(486,316,617,362,0,[558,356,0],wall=(548,362.6,570,362.8,[0,-1]))
    a.site(313,515,472,583,0,[414,546,0],wall=(392,583.6,414,583.8,[0,-1]))
    a.team(0,25,53);a.team(1,615,542)
    a.route('T main to A',[[46,62,0],[222,83,0],[227,180,0],[229,249,0],[284,249,0],[609,249,0],[609,356,0],[558,356,0]])
    a.route('T ivy to A',[[46,62,0],[227,83,0],[229,54,0],[556,54,0],[556,198,0],[607,247,0],[610,355,0],[558,356,0]])
    a.route('T upper halls to B',[[227,180,0],[182,250,0],[182,271,0],[182,333,96],[182,391,96],[182,460,10],[210,482,0],[260,546,0],[414,546,0]])
    a.route('T halls to B',[[46,62,0],[227,83,0],[227,180,0],[243,377,0],[243,413,0],[243,482,0],[260,546,0],[414,546,0]])
    a.route('CT to A',[[636,551,0],[655,475,0],[653,354,0],[558,356,0]])
    a.route('CT to B',[[636,551,0],[565,551,0],[565,546,0],[414,546,0]])
    a.route('A Z connector B',[[450,344,0],[427,378,0],[427,436,0],[560,436,0],[565,505,0],[414,505,0],[414,546,0]])
    a.views=[dict(name='train-outer',eye=[270,305,74],look=[566,319,89]),dict(name='train-inner',eye=[560,564,74],look=[331,518,96]),dict(name='train-ivy',eye=[555,187,74],look=[610,299,105])]
    return a.finalize()

def textures(theme):
    palette=(ROOT/'tools/texture_replacements/palette.lmp')
    if not palette.exists():
        from dust2_rebuild.build import textures as originals
        quant=originals()['d2_stone']
    else:
        quant=Image.new('P',(1,1));quant.putpalette(palette.read_bytes())
    rng=np.random.default_rng(1600)
    walls={'industrial':(100,114,111),'village':(177,152,116),'ruins':(95,105,76),'rail':(114,74,52)}
    bases={'wall':walls[theme],'floor':(111,107,95),'trim':(135,134,117),'crate':(116,88,48),'metal':(65,74,73),'wood':(102,74,44),'roof':(138,72,45),'window':(39,54,62),'vent':(60,70,72),'tank':(188,179,126),'wagon':(102,70,49),'wagon2':(86,113,102),'carved':(95,102,81),'moss':(63,84,39),'rope':(128,110,74),'mark':(185,148,46),'*water_de':(48,72,56),'sky_de':(97,128,147),'d2_signa':walls[theme],'d2_signb':walls[theme]}
    # Stay in the non-emissive red ramp. Rust orange quantizes to a brown ramp
    # in Quake's palette even when the RGB source looks red.
    bases['d2_red']=(160,8,8)
    result={}
    for name,base in bases.items():
        y,x=np.mgrid[:128,:128];noise=rng.normal(0,2.1,(128,128))+3*np.sin(x*.13)*np.cos(y*.17)
        im=Image.fromarray(np.uint8(np.clip(np.array(base)+noise[:,:,None],0,255)));d=ImageDraw.Draw(im)
        if name in ['wall','floor','trim','carved']:
            for yy in range(0,128,16 if theme=='rail' and name=='wall' else 32):
                d.line((0,yy,127,yy),fill=tuple(int(c*.72) for c in base),width=2)
                for xx in range(-32 if yy//32%2 else 0,128,64):d.line((xx,yy,xx,yy+32),fill=tuple(int(c*.8) for c in base),width=2)
        if name in ['metal','vent','wagon','wagon2','tank'] or name=='wall' and theme=='industrial':
            for xx in range(0,128,16 if name=='vent' else 32):
                d.line((xx,0,xx,128),fill=tuple(int(c*.7) for c in base),width=2)
                for yy in [5,122]:d.ellipse((xx+4,yy-1,xx+7,yy+2),fill=(44,47,45))
        if name in ['wood','crate','roof']:
            for xx in range(0,128,16):d.line((xx,0,xx,128),fill=(54,39,25),width=2)
            if name=='crate':d.line((0,0,127,127),fill=(152,122,76),width=12);d.line((0,127,127,0),fill=(152,122,76),width=12)
            for yy in [8,119]:d.line((0,yy,127,yy),fill=(48,43,34),width=6)
        if name=='carved':
            for xx in range(0,128,32):d.line([(xx+3,8),(xx+27,8),(xx+27,25),(xx+10,25),(xx+10,18),(xx+20,18)],fill=(42,50,32),width=4)
        if name.startswith('d2_sign'):
            ink=(160,8,8)
            if name.endswith('a'):d.line([(25,108),(64,19),(105,108)],fill=ink,width=12);d.line((41,77,87,77),fill=ink,width=11)
            else:d.line([(30,108),(30,20),(81,20),(100,39),(83,63),(31,63),(85,63),(103,84),(85,108),(30,108)],fill=ink,width=11)
        result[name]=im.quantize(palette=quant,dither=Image.Dither.NONE)
    result['de_glass']=Image.new('RGB',(32,32),(80,115,128)).quantize(palette=quant,dither=Image.Dither.NONE)
    return result

def build(a,compiler,fast=False):
    folder=OUT/a.name;folder.mkdir(parents=True,exist_ok=True)
    logs=ROOT/'test-results/classic-de'/a.name;logs.mkdir(parents=True,exist_ok=True)
    from classic_de.ballistics import capture,embed
    ballistics=capture(a)
    style(a,a.theme);write_wad(a,folder,'classic.wad',textures(a.theme))
    world=dict(classname='worldspawn',message=a.title,wad='classic.wad',_fpsloppa_bake='1',_fpsloppa_atlas='2048',_fpsloppa_light_response='quake',_minlight='32',_sunlight='125' if a.theme!='ruins' else '85',_sunlight_color='1 .92 .8',_sun_mangle='125 -58 0',_sunlight2='45',_bounce='1')
    path=folder/(a.name+'.map');bsp=folder/(a.name+'.bsp')
    path.write_text('{\n'+fields(world)+'\n'+'\n'.join(a.brushes)+'\n}\n{\n"classname" "func_detail"\n'+'\n'.join(a.detail_brushes)+'\n}\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in a.entities)+'\n'+'\n'.join('{\n'+fields(e)+'\n'+'\n'.join(parts)+'\n}' for e,parts in a.models)+'\n')
    path.write_text(path.read_text().rstrip()+'\n')
    for tool,flags in [('qbsp',['-wadpath',str(folder),str(path),str(bsp)]),('vis',['-threads','4',*(['-fast'] if fast else []),str(bsp)]),('light',['-threads','4','-extra','-bspxlit',str(bsp)])]:
        print(a.name,tool,flush=True)
        with (logs/(tool+'.log')).open('w') as log:subprocess.run([str(compiler/tool),*flags],stdout=log,stderr=subprocess.STDOUT,check=True)
    log=(logs/'qbsp.log').read_text();assert 'LEAK' not in log.upper() and "Couldn't create brush faces" not in log,log[-4000:]
    embed(bsp,ballistics)
    raw=bsp.read_bytes();assert struct.unpack_from('<i',raw)[0]==29 and len(raw)<25_000_000
    sites=[engine([(b[0]+b[2])/2,(b[1]+b[3])/2,b[4]]) for b in a.site_bounds]
    # Choose documented clear planting points, not centers occupied by a prop.
    for i in range(2):
        desired=[l['point'] for l in a.landmarks if l['name']=='Site '+('A' if i==0 else 'B')][-1]
        sites[i]=engine(desired)
    bounds=[]
    for u,v,U,V,z,Z in a.site_bounds:
        lo=engine([U,v,z]);hi=engine([u,V,Z]);bounds.append(dict(min=lo,max=hi))
    rules=dict(sha256=hashlib.sha256(raw).hexdigest(),sites=sites,bounds=bounds,starts=[[engine(p) for p in side] for side in a.team_starts],yaw=a.yaws)
    report=dict(id=a.name,title=a.title,format=29,bytes=len(raw),sha256=rules['sha256'],brushes=len(a.brushes)+len(a.detail_brushes),spawns=a.spawns,landmarks=a.landmarks,routes=a.routes,views=a.views,full_vis=not fast,reference=("https://cstake.ru/maps/de-maps/155-karta-de_aztec-dlja-cs-16.html" if a.name=="de_aztec_rebuilt" else REFERENCE),theme=a.theme,defusal=rules)
    report['site_markings']=a.site_markings
    for key in ['cover_checks','gate_checks','decor_checks','sightline_checks','structure_checks']:
        if hasattr(a,key):report[key]=getattr(a,key)
    (folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    shutil.copy2(bsp,ROOT/'maps'/bsp.name)
    bind_hash(a.name,report['sha256'])
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler-dir',type=Path,required=True);p.add_argument('--fast-vis',action='store_true');p.add_argument('--map',choices=['nuke','inferno','aztec','train']);args=p.parse_args()
    catalog_path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(catalog_path.read_text())
    rules_path=ROOT/'deathmatch/maps/defusal.json';rules=json.loads(rules_path.read_text()) if rules_path.exists() else {}
    for name,fn in [('nuke',nuke),('inferno',inferno),('aztec',aztec),('train',train)]:
        if args.map and name!=args.map:continue
        report=build(fn(),args.compiler_dir.resolve(),args.fast_vis);id=report['id'];rules[id]=report['defusal']
        catalog=[r for r in catalog if r['id']!=id];catalog.append(dict(id=id,title=report['title'],modes=['de'],path='res://maps/'+id+'.bsp',scene='res://maps/cache/'+id+'.scn',sha256=report['sha256'],distribution='base',expansion='classic-de'))
        catalog_path.write_text(json.dumps(catalog,indent=2)+'\n');rules_path.write_text(json.dumps(rules,indent=2)+'\n')
        print('BUILT',id,report['bytes'],report['brushes'],flush=True)

if __name__=='__main__':main()
