"""Hand-authored cover/layout corrections informed by the classic BSP survey.

Reference files are study inputs only. These functions emit new editable brush
geometry with the project's licensed materials, not retail meshes or textures.
"""
import math
from dust2_rebuild.build import xyz
from vesper.build import polygon


def block(a,u,v,width,depth,height,z=0,angle=0,material='crate'):
    theta=math.radians(angle);c,s=math.cos(theta),math.sin(theta)
    points=[]
    for x,y in [(-width/2,-depth/2),(width/2,-depth/2),(width/2,depth/2),(-width/2,depth/2)]:
        points.append(xyz(u+x*c-y*s,v+x*s+y*c)[:2])
    polygon(a,list(reversed(points)),z,z+height,material)


def checked_cover(a,u,v,width,depth,height,z=0,angle=0,material='crate'):
    block(a,u,v,width,depth,height,z,angle,material)
    c,s=math.cos(math.radians(angle)),math.sin(math.radians(angle))
    # Exposed floor immediately outside each corner survives QBSP face merging.
    points=[[u+x*c-y*s,v+x*s+y*c,z] for x,y in
            [(-width/2-.35,-depth/2-.35),(width/2+.35,-depth/2-.35),
             (width/2+.35,depth/2+.35),(-width/2-.35,depth/2+.35)]]
    a.cover_checks.append(dict(name=f'Crate {u},{v},{z}',ground=points,
                               clear=[[x,y,z+height/2] for x,y,_ in points]))


def inferno_facades(a):
    # Wall coordinates refer to the union of all rooms, including connections.
    # Mount frames/boards into that solid boundary, facing the actual street.
    a.decor_checks=[]
    def panel(u,v,width,z,axis,normal,kind):
        def point(along,depth,height):
            return [u+along,v+depth*normal,height] if axis=='u' else [u+depth*normal,v+along,height]
        def piece(l,r,b,t,inset,projection,texture):
            corners=[point(l,inset,b),point(r,projection,t)]
            lo=[min(q[i] for q in corners) for i in range(3)]
            hi=[max(q[i] for q in corners) for i in range(3)]
            a.block(lo[0],lo[1],hi[0],hi[1],lo[2],hi[2],texture)
        h=82 if kind=='window' else 100
        piece(0,width,z,z+h,-.25,.35,'window' if kind=='window' else 'wood')
        for l,r in [(-1,0),(width,width+1)]:piece(l,r,z,z+h+5,-.3,.8,'trim')
        piece(-1,width+1,z+h,z+h+5,-.3,.8,'trim')
        if kind=='window':
            piece(-1,width+1,z-4,z,-.3,1.2,'trim')
            piece(width/2-.3,width/2+.3,z,z+h,.3,.7,'trim')
            piece(-1,width+1,z+h+6,z+h+14,-.3,1.5,'roof')
        backing=[]
        for along in [-.9,width/2,width+.9]:
            for height in [max(.1,z-3),z+h/2,z+h+13 if kind=='window' else z+h+4]:
                behind=point(along,-.4,height);front=point(along,1.6,height)
                def air(plan):
                    q=xyz(*plan)
                    return any(all(lo[i]<q[i]<hi[i] for i in range(3)) for lo,hi in a.rooms)
                assert not air(behind) and air(front),(kind,u,v,behind,front)
                backing.append(behind)
        rect=[u-1,u+width+1,z-4,z+h+14] if axis=='u' else [v-1,v+width+1,z-4,z+h+14]
        plane=v if axis=='u' else u
        for other in a.decor_checks:
            if other['axis']!=axis or abs(other['plane']-plane)>2:continue
            old=other['rect']
            assert min(rect[1],old[1])<=max(rect[0],old[0]) or min(rect[3],old[3])<=max(rect[2],old[2]),(kind,u,v,other)
        a.decor_checks.append(dict(kind=kind,axis=axis,plane=plane,rect=rect,backing=backing))
    for u,v,axis,normal,z in [(355,408,'u',1,92),(404,408,'u',1,92),(468,408,'u',1,92),
                             (312,28,'u',1,92),(715,160,'v',-1,92),(711,420,'v',-1,92),
                             (156,570,'v',1,92),(6,410,'v',1,92),(490,554,'u',1,168)]:
        panel(u,v,17,z,axis,normal,'window')
    for u,v,axis,normal in [(329,408,'u',1),(382,408,'u',1),(443,408,'u',1),
                            (302,80,'v',1),(156,535,'v',1),(711,455,'v',-1),
                            (715,200,'v',-1),(6,452,'v',1)]:
        panel(u,v,12,0,axis,normal,'door')


def dust2_cover(a):
    # A long stack now has staggered heights/footprints and an offset rear box.
    for row in [(207,106,21,23,80,224,0),(207,130,21,23,80,224,0),
                (210,153,27,20,112,224,0),(218,97,14,14,64,304,0),
                (165,187,11,13,48,224,0),
                # B's angled central crates, low tunnel-side cover and rear box.
                (164,501,25,22,88,64,-12),(201,498,17,23,112,64,14),
                (244,541,19,27,80,64,-15),(111,555,18,18,72,88,0),
                (144,535,14,12,56,64,0),(275,517,11,18,64,64,0),
                (229,420,17,19,80,47,0),(360,332,14,16,56,18,0),
                (570,503,24,25,96,86,-8),(547,202,25,25,112,0,0),
                (557,176,12,19,64,0,0),(547,202,18,19,72,112,0),
                (599,241,18,16,80,0,0),(674,379,20,18,80,128,0)]:
        block(a,*row,material='d2_crate')
    # Shallow blind-corner masonry replaces the perfectly rectangular B edge.
    block(a,279,487,8,20,224,64,-24,'d2_stone')
    # The A corner opens into the adjoining terrace: u=150 is air here.
    # Embed its course in the actual u=110 outer wall, not the room overlap.
    # Sandstone courses and doorway lintels stay outside the walking lanes.
    for u,v,U,V,z in [(135,495,137,531,64),(109.8,78,112,112,224),(238,76,240,184,224)]:
        a.block(u,v,U,V,z+8,z+18,'d2_trim')


def dust2_mid_doors(a):
    # Classic central choke: two heavy arched timber leaves, partly open into
    # mid, with a usable centre gap. The old generic leaves were edge-on slabs.
    u,v,width=313,321,38
    a.opening(u,v,width,'v',0,False)
    a.block(u-10/6,301,u+10/6,v-width/2,0,240,'d2_stone')
    a.block(u-10/6,v+width/2,u+10/6,342,0,240,'d2_stone')
    length=width*3;angle=math.radians(36);a.door_checks=[]
    for side in [-1,1]:
        hinge=(u,v+side*width/2)
        along=(math.sin(angle),-side*math.cos(angle))
        normal=(-along[1],along[0])
        def point(s,z,t):
            return xyz(hinge[0]+(along[0]*s+normal[0]*t)/6,
                       hinge[1]+(along[1]*s+normal[1]*t)/6,z)
        def prism(ring,front,back,texture):
            front,back=sorted((front,back))
            lo=[point(s,z,front) for s,z in ring];hi=[point(s,z,back) for s,z in ring]
            faces=[list(reversed(lo[:3])),hi[:3]]
            faces += [[lo[i],lo[(i+1)%len(ring)],hi[(i+1)%len(ring)]] for i in range(len(ring))]
            # a.face writes plane equations; face winding is normalized by QBSP.
            a.brushes.append('{\n'+'\n'.join(a.face(f,texture) for f in faces)+'\n}')
        crown=[(length*(1-i/8),120+math.sqrt(max(0,length**2-(length*i/8)**2))-3) for i in range(9)]
        prism([(0,0),(length,0),*crown],-2,2,'d2_door')
        for z in [28,86,142]:prism([(8,z),(length-5,z),(length-5,z+7),(8,z+7)],-2.8,2.8,'d2_iron')
        for s in [1,length-6]:prism([(s,0),(s+5,0),(s+5,112),(s,112)],-2.5,2.5,'d2_door')
        for surface in [-1,1]:
            for i in range(8):
                a0=i*math.tau/8;a1=(i+1)*math.tau/8
                ring=[(length-15+r*math.cos(t),66+r*math.sin(t)) for r,t in [(8,a0),(8,a1),(5,a1),(5,a0)]]
                prism(ring,surface*3,surface*4,'d2_iron')
        a.door_checks.append(dict(hinge=[hinge[0],hinge[1],64],wood=[hinge[0]+along[0]*length/12,hinge[1]+along[1]*length/12,64],normal=list(normal)))


def sliding_pair(a,u,v,z,name):
    # Two framed leaves with their glass panes, matching the original assembly.
    # Frame/pane share one mover per leaf to avoid duplicate collision bodies,
    # motor sounds and snapshot rows for parts with identical travel.
    # Quake angle/lip/speed semantics explicitly replace GoldSrc spawnflags.
    half=68/6;travel=64
    for side in [-1,1]:
        low=v-half if side<0 else v;high=low+half
        attrs={'classname':'func_door','targetname':name,'angle':90 if side<0 else 270,
               'spawnflags':4,'speed':50,'wait':10,'dmg':0,'lip':4,'_de_reset':1}
        start=len(a.brushes)
        for b,B,zz,ZZ in [(low,low+8/6,z+8,z+116),(high-8/6,high,z+8,z+116),
                          (low+8/6,high-8/6,z+8,z+16),(low+8/6,high-8/6,z+108,z+116)]:
            a.block(u-4/6,b,u+4/6,B,zz,ZZ,'metal')
        a.block(u-2/6,low+8/6,u+2/6,high-8/6,z+16,z+108,'de_glass')
        a.model(dict(attrs,_fps_id=name+str(side)+'leaf'),start)
    start=len(a.brushes)
    a.block(u-12,v-half-4,u+12,v+half+4,z+1,z+80,'trigger')
    a.model({'classname':'trigger_multiple','target':name,'wait':.2},start)
    # Permanent jambs close the aperture above/beside the leaves.
    a.block(u-1,v-half-3,u+1,v-half,z,z+208,'metal')
    a.block(u-1,v+half,u+1,v+half+3,z,z+208,'metal')
    a.block(u-1,v-half,u+1,v+half,z+116,z+208,'metal')


def nuke_cover(a):
    # Original lower level has front/rear chambers and four side glass doors.
    a.room(435,399,565,519,-256,-48,'Lower service chamber')
    a.room(407,300,435,519,-256,-48,'Lower west passage')
    a.room(565,300,602,519,-256,-48,'Lower east passage')
    a.room(407,499,602,529,-256,-48,'Lower back passage')
    for u in [435,565]:
        for low,high in [(300,320-68/6),(320+68/6,484-68/6),(484+68/6,519)]:
            a.block(u-1,low,u+1,high,-256,-48,'wall')
    for number,(u,v) in enumerate([(565,320),(435,320),(565,484),(435,484)],1):
        sliding_pair(a,u,v,-256,'GlassDoor'+str(number))
    for u,v in [(484,294),(523,319)]:a.tank(u,v,0,11,152)
    for u,v in [(483,310),(524,340)]:a.tank(u,v,-256,11,136)
    a.tank(493,455,-256,15,144)
    for row in [(195,349,15,18,88,0,0),(311,371,17,19,88,0,-8),
                (321,387,19,22,128,0,0),(326,387,13,13,64,128,0),
                (444,130,15,18,80,0,0),(452,120,12,12,56,80,0),
                (473,510,25,17,112,0,0),(467,493,12,13,64,0,0),
                (588,402,18,28,128,0,0),(674,455,18,20,112,0,0),
                (696,502,14,17,80,0,0),(447,365,12,14,64,0,0)]:block(a,*row)
    # Low loading-yard vehicle: chassis, cab and cargo bed are separate masses.
    a.block(632,438,660,465,0,28,'metal')
    a.block(633,439,647,455,28,96,'metal')
    a.block(647,439,659,463,28,59,'metal')
    a.block(633,439,647,440,59,82,'de_glass')
    # Radio room gets a thin timber partition with a real doorway; it can be
    # shot through without weakening the exterior structural shell.
    a.block(359,264,398,265.25,0,144,'wood')
    a.block(418,264,433,265.25,0,144,'wood')
    a.block(398,264,418,265.25,104,144,'wood')
    # Structural columns belong on the shell and reach its ceiling. The old
    # short posts sat in open floor space, including the hut's doorway.
    supports=[(434.8,273,436.5,277),(469,229.8,473,231.5),(533,229.8,537,231.5)]
    for u,v,U,V in supports:a.block(u,v,U,V,0,384,'metal')
    a.structure_checks=[]
    for u in [444,477,510,543]:
        a.structure_checks.append(dict(name='South vent backed by wall',start=[u+9,397,88],end=[u+9,400,88],at=[u+9,398.5,88]))
    for z in [32,200,376]:
        a.structure_checks.append(dict(name='West column reaches roof',start=[439,275,z],end=[434,275,z],at=[436.5,275,z]))
    for u in [471,535]:
        for z in [32,200,376]:
            a.structure_checks.append(dict(name='North column reaches roof',start=[u,232.5,z],end=[u,229.5,z],at=[u,231.5,z]))
    # Roof vents and a hut roof retain the existing open floor routes.
    a.block(420,285,443,344,150,160,'metal')


def inferno_cover(a):
    a.cover_checks=[]
    for row in [(327,65,20,24,88,0,0),(326,65,16,16,64,88,0),
                (353,107,20,21,128,0,0),(353,107,13,14,56,128,0),
                (379,39,17,16,72,0,0),(313,135,12,12,64,0,0),
                (314,115,13,17,72,0,38),(613,442,20,24,76,0,0),
                (668,475,19,23,112,0,0),(670,473,12,12,48,112,0),
                (645,412,18,18,72,0,18),(690,550,16,16,88,0,0),
                (349,190,14,22,56,0,27),(342,222,12,12,48,0,27),
                (242,385,11,14,56,0,0),(281,432,10,10,56,0,0),
                (412,553,10,12,64,0,0)]:checked_cover(a,*row)
    # Chamfer the banana bends and articulate the flat street boundaries.
    for u,v,w,d,h,z,angle in [(294,307,7,15,200,0,28),(299,259,7,15,200,0,28),
                            (363,203,7,15,200,0,28),(582,398,8,15,160,0,24)]:
        block(a,u,v,w,d,h,z,angle,'wall')
    # Balcony and pit low walls create cover rather than an empty rectangular yard.
    a.block(618,531,645,534,0,40,'wall')
    a.block(707,535,710,590,0,40,'wall')
    a.block(486,588,576,589.2,96,122,'wood')


def train_details(a):
    # Wheelsets, couplers and ladders are represented with real brush silhouette.
    # End stairs remain the existing VR-access adaptation; no ladder code added.
    for u,v,length in [(380,218,108),(320,265,104),(447,265,104),(265,330,108),
                       (500,330,98),(279,475,102),(423,475,112),(310,516,99),
                       (432,516,105),(277,557,105),(405,557,105)]:
        for x in [u+12,u+length-18]:
            for y in [v+1,v+20]:block(a,x,y,8,2,28,4,0,'metal')
        a.block(u-3,v+9,u,v+13,25,33,'metal')
        a.block(u+length,v+9,u+length+3,v+13,25,33,'metal')
    # Raised loading edge and depot pilasters along the back, away from routes.
    a.block(253,609,632,616,0,24,'floor')
    for u in [255,346,438,527,579]:
        a.block(u,581,u+2,584,0,300,'trim')
    for u,v in [(28,98),(543,64),(657,346)]:block(a,u,v,12,14,72,0,8)


def aztec_layout(a):
    # Coordinates are a hand-measured plan study of the classic BSP overview.
    # Horizontal dimensions use 0.75 of GoldSrc units to retain arena traversal
    # scale; elevations remain in the project's BSP units. No faces are copied.
    ramps=[]
    def p(x,y,z=0):return [400+x/8,300-y/8,z]
    def room(x,y,X,Y,z=64,Z=640,label=''):
        u,v,_=p(x,Y);U,V,_=p(X,y);a.room(u,v,U,V,z,Z,label)
    def box(x,y,X,Y,z,Z,t='wall'):
        u,v,_=p(x,Y);U,V,_=p(X,y);a.block(u,v,U,V,z,Z,t)
    def ramp(x,y,X,Y,z,Z,axis='x'):
        u,v,_=p(x,Y);U,V,_=p(X,y)
        a.ramp(u,v,U,V,z if axis=='x' else Z,Z if axis=='x' else z,'u' if axis=='x' else 'v')
        if max(z,Z)==64:ramps.append((xyz(u,V)[0],xyz(u,V)[1],xyz(U,v)[0],xyz(U,v)[1]))
    def route(label,points):a.route(label,[p(*q) for q in points])
    # East T ruins to the north bridge approach and southern double-door route.
    for q,label in [((1920,-384,2560,512),'T ruins'),((2496,-128,3072,128),'T rear'),
                    ((1696,-384,1984,-128),'T south'),((1280,-384,1760,192),'East dogleg')]:room(*q,0,label=label)
    room(0,0,1408,448,64,label='Central raised approach')
    room(-128,-384,256,128,64,label='Central A turn')
    room(1408,-64,1696,192,0);ramp(1408,-64,1696,192,64,0)
    room(1728,448,2048,1408,0,label='T north')
    room(1840,320,2048,512,0,label='T north turn')
    room(1472,1216,1920,1408,0,label='North ruins recess')
    room(0,512,1792,960,64,label='Bridge approach')
    room(1728,448,2048,704,0);ramp(1728,448,2048,704,0,64,'y')
    box(1728,704,2048,1408,0,64,'floor')
    # CT spawn on the west, with stairs to B and the southern A approach.
    room(-3328,-416,-2688,640,-48,label='CT ruins')
    room(-3840,0,-3200,704,-48,label='CT back recess')
    room(-3264,448,-2688,704,-48);ramp(-3264,448,-2688,704,-48,64,'y')
    room(-3072,512,-1792,1280,64,label='B court')
    room(-2208,128,-1952,576,64,label='B steps approach')
    room(-2304,-640,-1728,192,64,label='CT central turn')
    room(-2816,0,-2176,256,-48);ramp(-2816,0,-2176,256,-48,64)
    room(-1792,576,-1280,896,64,label='Bridge west gate')
    room(-1664,128,-1344,640,64,label='West bridge stairs')
    room(-1728,-512,256,-256,64,label='A raised lane')
    # Southern A court and its flanking galleries surround the lower canal.
    room(-3328,-1344,-2688,-288,-48,label='CT south lane')
    room(-3328,-1344,-2432,-896,-48,label='CT south stairs')
    ramp(-2944,-1344,-2432,-896,-48,64)
    room(-2560,-1344,-1536,-960,64,label='Double-door approach')
    room(-1536,-1600,-1152,-928,64,label='A west gallery')
    room(-1152,-1664,256,-1280,64,label='A court')
    room(-128,-1408,256,-256,64,label='A east gallery')
    # Riverbed is continuous beneath the raised central lane and bridge.
    room(-1024,-1664,-384,640,-256,label='Lower canal')
    room(-1280,512,0,768,-256,label='Under bridge')
    # A 512-unit run keeps the west canal climb below the bot slope limit.
    # The previous 320-unit run was walkable-looking but absent from navigation.
    room(-1536,384,-1024,640,-256);ramp(-1536,384,-1024,640,64,-256)
    # Level turning landing clears the fixed gate leaf before the bridge.
    box(-1536,512,-1344,640,-256,64,'floor')
    room(-384,320,256,576,-256);ramp(-384,320,256,576,-256,64)
    room(256,384,384,576,64,label='Canal east landing')
    box(-1024,-1656,-384,632,-256,-246,'*water_de')
    box(-1280,520,0,760,-256,-246,'*water_de')
    # The bridge crosses east/west, matching the reference's actual route.
    box(-1600,640,0,768,48,64,'wood')
    for x in range(-1600,0,64):box(x,640,x+5,768,64,65,'wood')
    for y in [640,764]:
        # Leave the west stair landing open on the south side of the bridge.
        # A continuous chest-height rail let nav paths through but stopped bodies.
        spans=[(-1600,-1536),(-1344,0)] if y==640 else [(-1600,0)]
        for lo,hi in spans:box(lo,y,hi,y+4,108,112,'rope')
        for x in range(-1600,1,160):
            if y==640 and -1536<x<-1344:continue
            box(x-4,y,x+4,y+4,64,112,'wood')
    a.gate_checks=[]
    for x,y,low,high in [(-1600,704,128,896),(-2160,-1152,-1344,-960)]:
        # Complete the arch back to the actual corridor boundaries. The generic
        # opening only builds the crown; it does not supply supporting jambs.
        u,v,_=p(x,y);a.opening(u,v,28,'v',64,False)
        for b,t in [(low,y-112),(y+112,high)]:
            box(x-14,b,x+14,t,64,288,'wall')
        for hinge in [y-112,y+112]:
            # Open leaves begin at their hinges, embedded into the jamb edge.
            box(x-8,hinge-8,x+104,hinge+8,64,180,'wood')
            for z in [84,148]:box(x-9,hinge-9,x+10,hinge+9,z,z+8,'metal')
            a.gate_checks.append(dict(hinge=p(x,hinge,120),wall=p(x,low if hinge<y else high,120)))
    # Original ruin cover uses irregular stone masses, not a scatter of crates.
    a.cover_checks=[]
    for x,y,w,d,h,z,angle in [(-2960,1152,144,144,176,64,12),(-1888,1088,128,128,160,64,-12),
                          (-2272,656,176,176,112,64,18),(-2960,900,112,160,136,64,-8),
                          (-1440,-1456,112,160,160,64,0),(-384,-1568,224,160,96,64,0),
                          (96,-1536,160,160,160,64,12),(160,-576,112,160,144,64,0),
                          (-512,-472,104,64,72,64,0),(-3200,-1120,144,144,128,-48,-15),
                          (-3472,560,128,128,144,-48,24),(368,320,176,160,128,64,-8),
                          (576,304,128,176,112,64,0),(2368,-256,144,160,112,0,14)]:
        # Explicit floor elevations: location-only guesses put cover on ramps.
        u,v,_=p(x,y);block(a,u,v,w/8,d/8,h,z,angle,'carved')
        c,s=math.cos(math.radians(angle)),math.sin(math.radians(angle))
        ground=[];clear=[]
        # Sample just outside the footprint: QBSP removes shared/internal floor
        # faces beneath grounded solid cover, so an interior ray has no surface.
        for dx,dy in [(-w/2-3,-d/2-3),(w/2+3,-d/2-3),(w/2+3,d/2+3),(-w/2-3,d/2+3)]:
            ground.append([u+(dx*c-dy*s)/8,v+(dx*s+dy*c)/8,z])
        for dx,dy in [(-w/2-3,-d/2-3),(w/2+3,-d/2-3),(w/2+3,d/2+3),(-w/2-3,d/2+3)]:
            clear.append([u+(dx*c-dy*s)/8,v+(dx*s+dy*c)/8,z+h/2])
        a.cover_checks.append(dict(name=f'Ruin cover {x},{y}',ground=ground,clear=clear))
    # Broken wall teeth, buttresses and recessed moss follow court boundaries.
    for x,y,X,Y in [(-3060,1264,-1792,1280),(-1140,-1664,-752,-1648),
                    (-528,-1664,240,-1648),
                    (1932,496,2548,512),(2544,-368,2560,480)]:
        box(x,y,X,Y,144,176,'carved')
    for x in [-2936,-2680,-2416,-2144,-1888]:box(x,1240,x+72,1280,64,232,'carved')
    for x,y,z in [(-2880,960,64),(-1760,736,64),(-1328,-1456,64),(2256,384,0)]:
        box(x,y,x+112,y+80,z,z+4,'moss')
        a.cover_checks.append(dict(name=f'Moss {x},{y}',ground=[p(x-3,y-3,z),p(x+115,y+83,z)],clear=[]))
    # Site paint is grounded and wall-backed in both reconstructed courts.
    for x,y,X,Y,center,wallx in [(-1024,-1664,128,-1280,(-608,-1464,64),-1152),
                                (-2816,704,-1792,1280,(-2064,960,64),-1792)]:
        u,v,_=p(x,Y);U,V,_=p(X,y);wu,wv,_=p(wallx,(y+Y)/2)
        # Paint existing perimeter masonry; do not put a new wall in the entry.
        wall=(308,507.8,332,508.0,[0,-1]) if wallx==-1152 else (175.8,wv-10,176.0,wv+10,[-1,0])
        a.site(u,v,U,V,64,p(*center),wall=wall)
    a.team(0,*p(2096,96)[:2],0);a.team(1,*p(-3152,224)[:2],-48)
    route('T bridge to B',[(2200,160,0),(1984,160,0),(1984,384,0),(1904,448,0),(1904,736,64),(1216,800,64),(160,704,64),(-960,704,64),(-1536,704,64),(-1728,704,64),(-1728,864,64),(-2064,960,64)])
    route('T central lane to A',[(2200,160,0),(2200,-240,0),(1728,-240,0),(1728,96,0),(1536,96,36),(1344,192,64),(512,192,64),(128,128,64),(-32,-352,64),(-32,-1120,64),(-32,-1440,64),(-608,-1464,64)])
    route('CT to B', [(-3000,160,-48),(-3000,448,-48),(-3000,736,64),(-2768,864,64),(-2480,864,64),(-2064,960,64)])
    route('CT doors to A',[(-3000,160,-48),(-3000,-640,-48),(-3000,-1152,-48),(-2480,-1152,64),(-2160,-1152,64),(-1376,-1152,64),(-1376,-1472,64),(-1088,-1472,64),(-608,-1464,64)])
    route('B central turn to A',[(-2064,960,64),(-2064,384,64),(-2064,-384,64),(-1200,-384,64),(-32,-384,64),(-32,-1120,64),(-32,-1440,64),(-608,-1464,64)])
    route('Canal west ramp to B', [(-704,448,-256),(-1024,448,-256),(-1536,448,64),(-1536,560,64),(-1408,560,64),(-1408,704,64),(-1728,704,64),(-1728,864,64),(-2064,960,64)])
    route('Canal escape to east', [(-704,-1120,-256),(-704,448,-256),(-224,448,-176),(192,448,32),(224,448,48),(320,448,64)])
    a.views=[dict(name='aztec-bridge',eye=p(80,704,144),look=p(-1500,704,100)),
             dict(name='aztec-a',eye=p(-896,-1328,144),look=p(-288,-1552,120)),
             dict(name='aztec-canal',eye=p(-704,-1056,-176),look=p(-704,400,-176)),
             dict(name='aztec-b',eye=p(-2700,1100,144),look=p(-2100,760,120))]
    a.views.extend([dict(name='aztec-double-doors',eye=p(-2464,-1152,140),look=p(-2160,-1152,148)),
                    dict(name='aztec-ct-cover',eye=p(-3264,288,32),look=p(-3500,560,16)),
                    dict(name='aztec-b-stairs',eye=p(-2944,592,100),look=p(-2880,1040,124))])
    # BSP room union does not retain a floor where the canal passes underneath.
    # Explicit decks preserve the stacked walking surfaces above those voids.
    for low,high in a.rooms:
        if low[2]!=64:continue
        decks=[(low[0],low[1],high[0],high[1])]
        # Slabs cannot cap a descending ramp partway through its rise.
        for x,y,X,Y in ramps:
            next_decks=[]
            for l,b,r,t in decks:
                L,B,R,T=max(l,x),max(b,y),min(r,X),min(t,Y)
                if L>=R or B>=T:next_decks.append((l,b,r,t));continue
                for rect in [(l,b,L,t),(R,b,r,t),(L,b,R,B),(L,T,R,t)]:
                    if rect[0]<rect[2] and rect[1]<rect[3]:next_decks.append(rect)
            decks=next_decks
        for l,b,r,t in decks:a.box((l,b,48),(r,t,64),'floor')
    return a
