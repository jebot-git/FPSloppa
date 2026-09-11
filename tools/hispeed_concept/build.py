"""Build a reference-inspired HiSpeed concept, using only LibreQuake miptex.

No UT packages, geometry, textures, music or screenshots are build inputs.
Requires the project's generator helpers, LibreQuake textures and ericw-tools 0.18.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, struct, subprocess, sys
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_tf_maps import Arena
sys.path.insert(0, str(ROOT / 'tools/texture_replacements'))
from build import wad_read, miptex

NAME = 'as_hislop'
METAL = 'hs_wall'
FLOOR = 'met_blu_tile'
TRIM = 'met_blu_trim16'
HAZARD = 'aqpanl10'


def generate():
    a = Arena(NAME, 'HiSlop', 2880, 704, 768)
    brush_entities = []
    def volume(kind, lo, hi, texture='trigger', **fields):
        at = len(a.brushes)
        a.box(lo, hi, texture)
        brush_entities.append((dict(classname=kind, **fields), a.brushes.pop(at)))
    def light(p, strength=220, color='0.65 0.85 1'):
        a.ent('light', p, light=strength, _color=color, delay=2)
    def pickup(kind, p, **fields):
        # Runtime applies Quake's half-box offset to pickup entities.
        a.ent(kind, (p[0]-16, p[1]-16, p[2]+20), **fields)
    def stairs(x, y0, y1, base=0):
        for i in range(9):
            a.box((x+24*i, y0, base), (x+24*(i+1), y1, base+16*(i+1)), FLOOR)
    def pad(x, y, z=0):
        a.box((x-32,y-32,z), (x+32,y+32,z+4), HAZARD)
        volume('trigger_push', (x-30,y-30,z+4), (x+30,y+30,z+24), angle='-1', speed='850', fpsloppa_push_scale='1')
        light((x,y,z+72), 150, '0.3 1 0.6')
    def crate(x,y,z=0,w=96,h=112):
        a.box((x-w/2,y-w/2,z),(x+w/2,y+w/2,z+h),'met_grn_panel1')
        a.box((x-w/2-2,y-w/2-2,z+8),(x+w/2+2,y+w/2+2,z+16),HAZARD)
        a.box((x-w/2-2,y-w/2-2,z+h-16),(x+w/2+2,y+w/2+2,z+h-8),TRIM)
    def mount(x,y,z):
        # A clear, level build location for the existing TF engineer sentry.
        a.box((x-40,y-40,z-8),(x+40,y+40,z),HAZARD)
        a.ent('info_tf_resupply_blue',(x,y,z+24))
        a.ent('info_as_sentry',(x,y,z+24))
    # Sealed rail cutting under a star sky; the train is the stationary play frame.
    a.box((-2880,-704,-192),(2880,704,-160),'hs_track')
    for y0,y1 in [(-736,-704),(704,736)]:
        a.box((-2880,y0,-192),(2880,y1,768),'hs_cutting')
    for x0,x1 in [(-2912,-2880),(2880,2912)]:
        a.box((x0,-736,-192),(x1,736,768),'met_blc_trim64')
    a.box((-2912,-736,768),(2912,736,800),'sky_star')
    # Long raised rails and repeating ties convey the rail corridor without moving collision.
    for y in [-150,150]:
        a.box((-2880,y-8,-152),(2880,y+8,-140),'hs_rail')
    start_ties=len(a.brushes)
    for x in range(-3072,3073,128):
        a.box((x,-224,-160),(x+20,224,-152),FLOOR)
    brush_entities.append(({'classname':'func_illusionary','train_loop':'128'},'\n'.join(a.brushes[start_ties:])))
    del a.brushes[start_ties:]
    volume('trigger_hurt',(-2872,-696,-144),(2872,696,-96),dmg='100000')
    start_posts=len(a.brushes)
    for x in range(-3072,3073,512):
        for y in [-680,680]:
            a.box((x-20,y-16,-160),(x+20,y+16,512),METAL)
            a.box((x-12,y-20,200),(x+12,y+20,280),'tlight12')
    brush_entities.append(({'classname':'func_illusionary','train_loop':'512'},'\n'.join(a.brushes[start_posts:])))
    del a.brushes[start_posts:]
    a.ent('info_train_motion',(0,0,24),speed=640)
    centers = [-2080,-1440,-800,-160,480,1120,1760]
    for i,c in enumerate(centers):
        start,end=c-304,c+304
        a.box((start,-304,-32),(end,304,0),FLOOR)
        a.box((start+32,-200,-72),(end-32,200,-32),TRIM)
        # Bogies and inset wheels, below all playable decks.
        for xx in [c-192,c+192]:
            a.box((xx-64,-240,-88),(xx+64,240,-64),'met_blc_trim64')
            for yy in [-246,222]:
                a.box((xx-48,yy,-88),(xx+48,yy+24,-40),'met_blu_trim16s')
        if i<6:
            a.box((end,-80,-16),(end+32,80,0),HAZARD)
        # Low edge beams keep the dangerous edges readable without fencing them off.
        for yy in [-304,296]:
            a.box((start,yy,0),(end,yy+8,12),TRIM)
        light((c,0,440),350,'0.70 0.78 1')
    # Side-on transport helicopter: open troop bay faces the train, cockpit
    # projects toward the cutting, and a long tapered tail opposes the nose.
    # Convex lofts keep this genuine BSP29 brush geometry, including collision.
    def loft_y(y0, y1, r0, r1, texture):
        # Rings ordered around X/Z, with opposite end-cap winding.
        p=[(x,y0,z) for x,z in r0];q=[(x,y1,z) for x,z in r1]
        faces=[list(reversed(p[:3])),q[:3]]
        for i in range(len(p)):
            j=(i+1)%len(p);faces.append([p[i],p[j],q[j]])
        a.brushes.append('{\n'+'\n'.join(a.face(list(reversed(f)),texture) for f in faces)+'\n}')
    def ring(x0,x1,z0,z1):return [(x0,z0),(x1,z0),(x1,z1),(x0,z1)]
    a.box((-2768,-136,-16),(-2400,136,0),FLOOR)
    a.box((-2400,-80,-16),(-2384,80,0),HAZARD)
    # Hollow cabin retains the tested troop spawns and level loading ramp.
    for yy in [-144,128]:a.box((-2768,yy,0),(-2432,yy+16,144),METAL)
    a.box((-2768,-128,0),(-2752,128,144),METAL)
    a.box((-2752,-128,144),(-2432,128,168),TRIM)
    # Sloping shoulders, broad canopy and pointed lower nose, facing -Y.
    loft_y(-144,-128,ring(-2768,-2432,120,144),ring(-2752,-2448,144,168),METAL)
    loft_y(128,144,ring(-2752,-2448,144,168),ring(-2768,-2432,120,144),METAL)
    loft_y(-304,-144,ring(-2704,-2496,8,72),ring(-2768,-2432,-16,88),METAL)
    loft_y(-288,-148,ring(-2696,-2504,72,88),ring(-2744,-2456,88,160),'met_blc_trim64')
    # Windshield centre mullion over the sloped dark canopy.
    loft_y(-290,-146,ring(-2606,-2594,72,92),ring(-2606,-2594,88,166),TRIM)
    # Tapered high tail boom and large vertical/horizontal stabilizers.
    loft_y(144,528,ring(-2664,-2536,64,128),ring(-2616,-2584,128,152),METAL)
    loft_y(488,560,ring(-2612,-2588,136,232),ring(-2608,-2592,144,280),TRIM)
    a.box((-2712,472,144),(-2488,504,156),TRIM)
    # Rotor mast / engine nacelles and four long blades: instantly readable silhouette.
    a.box((-2664,-64,168),(-2536,88,200),METAL)
    for xx in [-2696,-2536]:a.box((xx,-48,168),(xx+32,104,200),TRIM)
    a.box((-2616,-16,200),(-2584,16,252),TRIM)
    a.box((-2640,-40,244),(-2560,40,260),METAL)
    a.box((-2848,-18,260),(-2272,18,268),'met_blc_trim64')
    a.box((-2618,-368,260),(-2582,368,268),'met_blc_trim64')
    # Yellow blade tips and a separate vertical tail rotor on the port side.
    for xx in [-2848,-2312]:a.box((xx,-18,260),(xx+40,18,268),HAZARD)
    for yy in [-368,328]:a.box((-2618,yy,260),(-2582,yy+40,268),HAZARD)
    a.box((-2640,516,116),(-2632,528,240),'met_blc_trim64')
    a.box((-2640,464,172),(-2632,580,184),'met_blc_trim64')
    a.box((-2648,508,164),(-2600,536,192),TRIM)
    # Long parallel landing skids with visible upright supports.
    for xx in [-2736,-2464]:
        a.box((xx,-256,-56),(xx+16,184,-40),TRIM)
        for yy in [-88,88]:a.box((xx,yy,-40),(xx+16,yy+16,-8),TRIM)
    light((-2600,0,120),180,'1 0.7 0.5')
    # Four containers alternate left/right to produce the documented double-S route.
    for xx,yy in [(-1664,-40),(-1520,40),(-1376,-40),(-1232,40)]:
        crate(xx,yy,w=112,h=160)
    # Beam wagon: posts, overhead longitudinal beams, elevated health reward.
    for xx in [-992,-800,-608]:
        for yy in [-120,120]:
            a.box((xx-16,yy-16,0),(xx+16,yy+16,176),METAL)
    for yy in [-136,120]:a.box((-1056,yy,176),(-544,yy+16,200),TRIM)
    a.box((-1008,-136,176),(-976,136,200),TRIM)
    pad(-1088,224)
    pickup('item_health',(-800,-120,200),spawnflags=2)
    # Open acid tank, with continuous 144-unit side catwalks and a rim/roof reward.
    a.box((-400,-144,0),(80,144,16),METAL)
    for y0,y1 in [(-144,-128),(128,144)]:a.box((-400,y0,16),(80,y1,176),HAZARD)
    for x0,x1 in [(-400,-384),(64,80)]:a.box((x0,-128,16),(x1,128,176),METAL)
    a.box((-384,-128,16),(64,128,144),'*slime1')
    a.box((-192,-144,176),(-128,144,192),FLOOR)
    pickup('item_armor2',(-160,0,192))
    light((-160,0,232),240,'0.5 1 0.25')
    pad(112,-224)
    for car,c in [(3,480),(2,1120),(1,1760)]:
        start,end=c-304,c+304
        # Two-storey car, inset side windows and an exterior service catwalk.
        for y0,y1 in [(-200,-184),(184,200)]:
            a.box((start,y0,0),(end,y1,40),METAL)
            a.box((start,y0,104),(end,y1,304),METAL)
            for xx in range(start,end,128):a.box((xx,y0,40),(xx+32,y1,104),TRIM)
            for xx in range(start+32,end,128):
                a.box((xx,y0-2,264),(xx+64,y1+2,280),'tlight12')
        for xx in [start,end-16]:
            for y0,y1 in [(-184,-80),(80,184)]:a.box((xx,y0,0),(xx+16,y1,304),METAL)
            a.box((xx,-80,112),(xx+16,80,304),TRIM)
        # Stair ascent is off the lower corridor; middle car forces this upper route.
        stairs(start+48,-176,-64)
        a.box((start+264,-184,128),(end if car==1 else end-96,184,144),FLOOR)
        if car==2:a.box((c-16,-184,0),(c+48,184,128),'met_grn_panel1')
        # Front car hatch gives a direct roof-to-access-token route.
        if car==1:
            for lo,hi in [(start,c+32),(c+160,end)]:a.box((lo,-200,304),(hi,200,320),TRIM)
            for lo,hi in [(-200,-80),(80,200)]:a.box((c+32,lo,304),(c+160,hi,320),TRIM)
        else:a.box((start,-200,304),(end,200,320),TRIM)
        # Shallow roof ridges and yellow end strips provide cover / gap cues.
        for yy in [-192,176]:a.box((start+32,yy,320),(end-32,yy+16,336),METAL)
        for xx in [start,end-16]:a.box((xx,-200,320),(xx+16,200,328),HAZARD)
        for xx in [start+112,end-128]:
            light((xx,40,92),230,'0.55 0.85 1')
            light((xx,0,240),230,'0.65 0.9 1')
        # Number of yellow stripes denotes CAR 3 / 2 / 1 at every entrance.
        for n in range(car):a.box((start-4,-60+n*40,160),(start, -36+n*40,224),HAZARD)
        if car<3:pad(start+24,248)
    # Interior bulkheads create rooms and offset doorways instead of one open tube.
    def bulkhead(x, z0, z1, opening, top=112):
        left,right=opening
        for y0,y1 in [(-184,left),(right,184)]:
            a.box((x,y0,z0),(x+16,y1,z1),METAL)
        a.box((x,left,z0+top),(x+16,right,z1),TRIM)
        for y in [left-8,right]:
            a.box((x-2,y,z0),(x+18,y+8,z0+top),HAZARD)
    bulkhead(512,0,128,(-112,0))           # CAR 3 supply compartment.
    bulkhead(1216,144,304,(0,112))         # CAR 2 upper passenger compartment.
    bulkhead(1704,0,128,(-32,80))          # CAR 1 lower entrance vestibule.
    a.box((1744,16,0),(1840,32,128),METAL) # Equipment room off the service passage.
    bulkhead(1808,144,304,(-112,0))        # CAR 1 upper switch room.
    bulkhead(1904,0,128,(-128,-16))        # Enclosed control cabin, one real doorway.
    # Continuous upper floor seals the cabin from the roof hatch. Close lower
    # windows and the locomotive-end opening so catwalks cannot bypass its door.
    for y0,y1 in [(-200,-184),(184,200)]:
        a.box((1904,y0,40),(2064,y1,104),METAL)
    a.box((2048,-80,0),(2064,80,112),METAL)
    # Distinct machinery, switch station and driving console provide room identity.
    a.box((1776,112,0),(1824,168,72),'comp1_6')
    a.box((1840,144,144),(1904,176,208),'comp1_6')
    a.box((2032,-160,0),(2048,-64,64),'comp1_6')
    light((1832,96,240),210,'0.4 0.85 1')
    light((1984,-96,88),190,'1 0.65 0.25')
    # Supply/defensive alcoves in CAR 3; CAR 1's objective console and guard pads.
    crate(640,120,w=80,h=80)
    light((1968,-96,224),180,'1 0.65 0.25')
    mount(640,-120,144)
    mount(1632,120,0)
    mount(1840,120,0)
    # A sloped locomotive nose, headlights and exhausts finish the front silhouette.
    a.ramp_x(2064,2240,-184,184,176,48,METAL)
    a.box((2208,-168,56),(2240,168,88),HAZARD)
    for yy in [-128,96]:
        a.box((2240,yy,88),(2248,yy+32,112),'tlight12')
    a.box((2112,-40,120),(2160,40,240),TRIM)
    # Native TF objectives: upper access token -> lower cabin capture.
    a.team(-1,(-2656,0,24),[(-2528,y,24) for y in [-72,72]]+[(-2192,y,24) for y in [-112,112]],(-2688,64,24),(2016,-112,24))
    a.team(1,(1856,112,168),[(x,y,24) for x in [432,688] for y in [-32,64]],(688,80,24),(688,-80,24))
    a.ent('info_player_start',(-2528,0,24),angle=0)
    for x,y,z in [(-1824,224,0),(-800,0,0),(-288,224,0),(1152,64,144),(1776,64,144)]:
        a.ent('info_player_deathmatch',(x,y,z+24),angle=0)
    for kind,p in [('weapon_rocketlauncher',(-2256,0,0)),('weapon_supernailgun',(-2560,0,0)),('weapon_supershotgun',(-1440,224,0)),('weapon_nailgun',(-608,0,0)),('weapon_supernailgun',(64,224,0)),('weapon_rocketlauncher',(1056,48,144)),('weapon_supershotgun',(1312,0,0))]:pickup(kind,p)
    for x,y,z in [(-1984,112,0),(-640,224,0),(304,96,0),(1264,96,144),(1952,64,0)]:pickup('item_health',(x,y,z))
    for x,y,z in [(-2336,112,0),(-944,0,0),(624,40,144),(1280,96,144)]:pickup('item_shells',(x,y,z));pickup('item_cells',(x+40,y,z))
    pickup('item_armor2',(752,0,0))
    pickup('item_health',(1168,0,144),spawnflags=2)
    pickup('item_spikes',(1280,0,144))
    pickup('weapon_nailgun',(1552,0,0))
    pickup('item_spikes',(1584,0,0))
    a.ent('info_koth_control',(1856,112,168))
    a.ent('info_as_objective',(1856,112,168),step=1,title='Unlock control cabin')
    a.ent('info_as_objective',(2016,-112,24),step=2,title='Override train controls')
    for index,x in [(1,256),(2,1504)]:
        a.ent('info_as_checkpoint',(x,0,24),checkpoint=index)
    for index,attack,defend in [(1,432,1280),(2,1584,1880)]:
        for y in [-24,64]:
            a.ent('info_as_spawn',(attack,y,24),checkpoint=index,role='attack')
            a.ent('info_as_spawn',(defend,y,24),checkpoint=index,role='defend')
    # The cabin door slides sideways into the bulkhead, clear of the upper room.
    # The AS switch unlocks it; in TF it is proximity-operated.
    volume('func_door',(1904,-128,0),(1920,-16,112),TRIM,angle='90',as_unlock='1',lip='-8')
    return a,brush_entities


def main():
    p=argparse.ArgumentParser(description=__doc__)
    textures=p.add_mutually_exclusive_group(required=True)
    textures.add_argument('--wad-dir',type=Path)
    textures.add_argument('--reuse-textures',type=Path,help='Existing HiSlop BSP; requires its sibling HiSlop license/provenance directory')
    p.add_argument('--compiler-dir',type=Path,required=True)
    p.add_argument('--output',type=Path,default=ROOT.parent/'Builds/HiSpeed-Concept')
    p.add_argument('--fast-vis',action='store_true',help='Iteration only: conservative visibility, more rendered faces')
    args=p.parse_args(); out=args.output.resolve()
    for sub in ['maps','source','licenses','logs']:(out/sub).mkdir(parents=True,exist_ok=True)
    a,brush_entities=generate()
    used={line.split(')')[-1].strip().split()[0] for brush in a.brushes+[b for _,b in brush_entities] for line in brush.splitlines() if line.startswith('(')}
    # Compiler trigger texture need not be shipped, but give it a real licensed miptex.
    donors={};sources={}
    if args.reuse_textures:
        data=args.reuse_textures.read_bytes()
        assert struct.unpack_from('<i',data)[0]==29, 'Texture source must be BSP29'
        offset,length=struct.unpack_from('<ii',data,4+2*8)
        lump=data[offset:offset+length];count=struct.unpack_from('<i',lump)[0]
        metadata=args.reuse_textures.parent/'HiSlop'
        sources=json.loads((metadata/'texture-sources.json').read_text())
        for index in range(count):
            at=struct.unpack_from('<i',lump,4+4*index)[0]
            if at<0:continue
            name=lump[at:at+16].split(b'\0')[0].decode('ascii')
            w,h=struct.unpack_from('<II',lump,at+16)
            raw=lump[at:at+40+w*h*85//64]
            assert name in sources and hashlib.sha256(raw).hexdigest()==sources[name]['sha256'], 'Texture provenance mismatch: '+name
            donors[name]=raw
        donors['trigger']=donors['met_blc_trim64'];sources['trigger']=dict(sources['met_blc_trim64'],donor='met_blc_trim64')
    else:
        for path in sorted(args.wad_dir.glob('*.wad')):
            wad_hash=hashlib.sha256(path.read_bytes()).hexdigest()
            for name,tile in wad_read(path).items():donors[name]=tile;sources[name]={'wad':path.name,'wad_sha256':wad_hash}
        donors['trigger']=donors['met_blc_trim64'];sources['trigger']=dict(sources['met_blc_trim64'],donor='met_blc_trim64')
        for alias,donor in [('hs_track','met_blc_trim64'),('hs_cutting','med_flat9'),('hs_rail','met_blu_trim16')]:
            donors[alias]=donors[donor];sources[alias]=dict(sources[donor],donor=donor,license='BSD-3-Clause')
        # Same licensed panel detail, shifted to the cool steel palette of the reference.
        raw=donors['aqconc04'];w,h,at=struct.unpack_from('<III',raw,16)
        palette=(ROOT/'deathmatch/maps/palette.lmp').read_bytes()
        panel=Image.frombytes('P',(w,h),raw[at:at+w*h]);panel.putpalette(palette)
        panel=ImageOps.colorize(ImageOps.grayscale(panel), '#102531', '#a9c9d5')
        quant=Image.new('P',(1,1));quant.putpalette(palette[:224*3]+palette[:3]*32)
        donors[METAL]=miptex(METAL,panel.quantize(palette=quant,dither=Image.Dither.NONE))
        sources[METAL]=dict(sources['aqconc04'],donor='aqconc04',edit='cool steel recolor; geometry/detail preserved',license='BSD-3-Clause')
    wad=bytearray(b'WAD2'+bytes(8));directory=[];provenance={}
    for name in sorted(used):
        raw=donors[name];raw=struct.pack('16s',name.encode())+raw[16:]
        at=len(wad);wad.extend(raw);directory.append(struct.pack('<iiiBBH16s',at,len(raw),len(raw),68,0,0,name.encode()))
        provenance[name]=dict(sources[name],sha256=hashlib.sha256(raw).hexdigest())
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
    (out/'source/hispeed.wad').write_bytes(wad)
    def fields(d):return '\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
    world={'classname':'worldspawn','message':a.title,'wad':'hispeed.wad','_fpsloppa_bake':'1','_fpsloppa_atlas':'2048','_minlight':'32','_sunlight':'90','_sun_mangle':'0 -70 0','_sunlight2':'25','_bounce':'1'}
    text='{\n'+fields(world)+'\n'+'\n'.join(a.brushes)+'\n}\n'
    text+='\n'.join('{\n'+fields(e)+'\n}' for e in a.entities)+'\n'
    text+='\n'.join('{\n'+fields(e)+'\n'+brush+'\n}' for e,brush in brush_entities)+'\n'
    source=out/'source'/f'{NAME}.map';source.write_text(text)
    bsp=out/'maps'/f'{NAME}.bsp'
    for tool,flags in [('qbsp',['-wadpath',str(out/'source'),str(source),str(bsp)]),('vis',['-threads','2',*(['-fast'] if args.fast_vis else []),str(bsp)]),('light',['-threads','2','-extra','-bspxlit',str(bsp)])]:
        print(tool,flush=True)
        with (out/'logs'/f'{tool}.log').open('w') as log:subprocess.run([str(args.compiler_dir.resolve()/tool),*flags],stdout=log,stderr=subprocess.STDOUT,check=True)
    data=bsp.read_bytes();assert struct.unpack_from('<i',data)[0]==29
    assert len(data)<=25*1024*1024
    compiler_log=(out/'logs/qbsp.log').read_text()
    assert 'LEAK' not in compiler_log.upper()
    assert "Couldn't create brush faces" not in compiler_log, 'Invalid brush discarded by QBSP'
    (out/'texture-sources.json').write_text(json.dumps(provenance,indent=2)+'\n')
    for name in ['COPYING','CREDITS','README-IMPORTANT-LICENCE-INFO']:
        source_license=(metadata/('LibreQuake-'+name+'.txt') if args.reuse_textures else args.wad_dir.parent/'docs'/name)
        shutil.copy2(source_license,out/'licenses'/('LibreQuake-'+name+'.txt'))
    shutil.copy2(Path(__file__).with_name('README.md'),out/'README.md')
    (out/'tf_maplist.txt').write_text(NAME+'\n')
    (out/'as_maplist.txt').write_text(NAME+'\n')
    (out/'hispeed-as.cfg').write_text('set sv_hostname \"FPSloppa Experimental Assault\"\nset sv_gametype \"as\"\nset sv_maxclients \"10\"\nset timelimit \"7\"\nset map \"'+NAME+'\"\nset as_maplist \"'+NAME+'\"\n')
    (out/'hispeed.cfg').write_text('set sv_hostname "FPSloppa HiSpeed concept"\nset sv_gametype "tf"\nset sv_maxclients "10"\nset timelimit "7"\nset capturelimit "1"\nset map "'+NAME+'"\nset tf_maplist "'+NAME+'"\n')
    (out/'manifest.json').write_text(json.dumps({'id':NAME,'format':29,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'brushes':len(a.brushes)+len(brush_entities),'entities':len(a.entities)+len(brush_entities),'textures':len(used),'recommended_players':[4,10],'concept':True,'modes':['as','tf'],'objective_adapter':'native paired AS; optional TF flag-and-capture concept','scenery_motion':True,'full_vis':not args.fast_vis},indent=2)+'\n')
    print(bsp,len(data),'bytes',flush=True)

if __name__=='__main__':main()
