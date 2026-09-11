"""Build an independently authored Frigate-inspired BSP29 with LibreQuake textures."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_tf_maps import Arena

NAME = 'as_frigate'
METAL, FLOOR, TRIM = 'met_brn_block', 'met_brn_tile2', 'met_blu_trim16'
WOOD, STONE, WATER = 'med_wood2_plk1', 'med_csl_brk14b', '*water2'


def generate():
    a = Arena(NAME, 'Frigate', 1600, 1440, 1024)
    entities = []

    def volume(kind, lo, hi, texture='trigger', **fields):
        a.box(lo, hi, texture)
        entities.append((dict(classname=kind, **fields), a.brushes.pop()))

    def light(x, y, z, strength=220, color='0.65 0.82 1'):
        a.ent('light', (x, y, z), light=strength, _color=color, delay=2)

    def pickup(kind, x, y, z=0, **fields):
        a.ent(kind, (x-16, y-16, z+20), **fields)

    def crate(x, y, w=96, h=96, z=0):
        a.box((x-w/2,y-w/2,z), (x+w/2,y+w/2,z+h), WOOD)
        for dz in [8,h-16]:
            a.box((x-w/2-1,y-w/2-1,z+dz), (x+w/2+1,y+w/2+1,z+dz+8), TRIM)

    def wall_x(x, y0, y1, z, height, opening):
        left, right = opening
        for lo, hi in [(y0,left),(right,y1)]:
            if hi>lo:a.box((x,lo,z),(x+16,hi,z+height),METAL)
        a.box((x,left,z+112),(x+16,right,z+height),TRIM)
        for y in [left-8,right]:a.box((x-2,y,z),(x+18,y+8,z+112),'aqpanl10')

    def floor_holes(x0, x1, y0, y1, z, holes):
        # Rectangular subtraction keeps every deck solid except authored stairwells.
        xs=sorted({x0,x1,*[v for h in holes for v in h[:2]]})
        ys=sorted({y0,y1,*[v for h in holes for v in h[2:]]})
        for lo, hi in zip(xs,xs[1:]):
            for near, far in zip(ys,ys[1:]):
                if not any(h[0]<=lo and hi<=h[1] and h[2]<=near and far<=h[3] for h in holes):
                    a.box((lo,near,z-16),(hi,far,z),FLOOR)

    def stairs(x0, y0, y1, z, count=10):
        for i in range(count):a.box((x0+i*32,y0,z),(x0+(i+1)*32,y1,z+(i+1)*16),FLOOR)

    def prism(points, z0, z1, texture):
        p=[(x,y,z0) for x,y in points];q=[(x,y,z1) for x,y in points]
        faces=[list(reversed(p[:3])),q[:3]]
        for i in range(len(p)):
            j=(i+1)%len(p);faces.append([p[i],p[j],q[j]])
        a.brushes.append('{\n'+'\n'.join(a.face(f,texture) for f in faces)+'\n}')

    # Enclosed rocky harbor, real water contents and an elevated masonry quay.
    a.box((-1600,-1440,-352),(1600,1440,-320),STONE)
    for lo,hi in [(-1632,-1600),(1600,1632)]:a.box((lo,-1472,-352),(hi,1472,1024),STONE)
    for lo,hi in [(-1472,-1440),(1440,1472)]:a.box((-1600,lo,-352),(1600,hi,1024),STONE)
    a.box((-1632,-1472,1024),(1632,1472,1056),'sky_star')
    a.box((-1600,-1440,-320),(1600,1440,-80),WATER)
    a.box((-1600,-1440,-320),(1280,-704,0),STONE)
    # Quay exit ramp lets swimmers recover without a precise jumping maneuver.
    a.ramp_x(1280,1536,-1040,-816,0,-224,STONE)
    a.box((1248,-1040,-32),(1280,-800,0),WOOD)
    for x in range(-1440,1280,192):
        a.box((x,-720,0),(x+24,-696,24),TRIM)
    # Tall rock buttresses and a shut harbor gate behind the bow.
    for x,y,w in [(-1512,700,176),(-1392,1248,208),(1344,1264,256),(1460,560,140)]:
        a.box((x-w/2,y-w/2,-320),(x+w/2,y+w/2,640), 'med_rock10b')
    a.box((1576,-480,-80),(1600,480,288),'met_grn_panel1')
    for y in [-456,-232,-8,216,440]:a.box((1568,y,-80),(1576,y+16,288),TRIM)
    # Warehouse with two interior rooms and a sheltered attacker assembly area.
    a.box((-1392,-1408,0),(-1368,-832,272),STONE)
    a.box((-1392,-1408,0),(224,-1384,272),STONE)
    a.box((200,-1384,0),(224,-816,272),STONE)
    for x0,x1 in [(-1392,-1120),(-928,-256),(-64,224)]:a.box((x0,-840,0),(x1,-816,272),STONE)
    for x0,x1 in [(-1120,-928),(-256,-64)]:a.box((x0,-840,144),(x1,-816,272),WOOD)
    a.box((-1392,-1408,272),(224,-816,296),WOOD)
    # Bar/canteen partition, with a broad doorway and long counter.
    wall_x(-640,-1384,-840,0,272,(-1136,-944))
    a.box((-1248,-1296,0),(-800,-1232,48),WOOD)
    for x in [-1184,-1024,-864]:a.box((x,-1176,0),(x+40,-1136,32),WOOD)
    for x,y,w,h in [(-464,-1264,128,112),(-400,-928,96,96),(-64,-1232,144,144)]:crate(x,y,w,h)
    for x in [-1152,-832,-448,-32]:light(x,-1088,224,300,'1 .76 .48')
    # Wooden gangway and ship entrance, broad enough for two VR capsules to pass.
    a.box((256,-800,-16),(448,-288,0),WOOD)
    for y in [-752,-544,-336]:
        for x in [256,432]:a.box((x,y,-240),(x+16,y+20,32),WOOD)
    # Hull: steel sides, tapered bow, aft transom; water entry in starboard forebody.
    a.box((-1088,-336,-288),(864,-304,0),METAL)
    for x0,x1 in [(-1088,544),(800,864)]:a.box((x0,304,-288),(x1,336,0),METAL)
    a.box((544,304,-112),(800,336,0),METAL)
    a.box((-1088,-304,-288),(-1056,304,0),METAL)
    a.box((-1056,-304,-288),(864,304,-224),FLOOR)
    # Convex bow forms an unmistakable pointed ship silhouette.
    prism([(864,-336),(1344,0),(864,336)],-288,0,METAL)
    floor_holes(-1056,864,-304,304,0,[(320,832,-144,272)])
    # Flooded forward intake -> broad surfaced engine-room ramp, no ladder dependency.
    a.ramp_x(320,800,112,272,0,-224,FLOOR)
    # Main deck side walls and a recessed, sheltered gangway entrance.
    for x0,x1 in [(-1056,256),(448,512)]:a.box((x0,-304,0),(x1,-288,160),METAL)
    a.box((256,-304,112),(448,-288,160),TRIM)
    a.box((-1056,288,0),(320,304,160),METAL)
    a.box((-1056,-288,0),(-1040,288,160),METAL)
    # Lower compartment route: entry, stores, machinery junction, aft compressor room.
    wall_x(160,-288,288,0,160,(-192,-48))
    wall_x(-224,-288,288,0,160,(-64,80))
    wall_x(-608,-288,288,0,160,(-192,-48))
    # Parallel service passage gives a flank around the main machinery choke.
    a.box((-592,64,0),(-496,80,128),METAL)
    a.box((-368,64,0),(-224,80,128),METAL)
    crate(-384,-208,80,80)
    a.box((-992,208,0),(-736,272,72),'comp1_6')
    a.box((-1008,96,0),(-944,192,104),'met_grn_panel1')
    # Aft machinery pipes: target is a runtime destructible compressor, not world solid.
    a.box((-920,48,64),(-904,192,80),TRIM)
    a.box((-920,176,64),(-800,192,80),TRIM)
    a.box((-920,48,0),(-904,64,80),TRIM)
    a.ent('info_as_objective',(-864,0,24),step=1,health=240,title='Destroy the aft compressor')
    # Two routes up to the mess deck. The aft stair is in a room separate from the target.
    stairs(-576,144,272,0)
    stairs(-1024,-272,-128,0)
    floor_holes(-1056,320,-304,304,160,[(-576,-256,144,272),(-1024,-704,-272,-128)])
    # Mess deck, with actual furniture and a second flight to the protected bridge.
    a.box((-1056,-304,160),(-1040,304,320),METAL)
    for y0,y1 in [(-304,-288),(288,304)]:
        a.box((-1056,y0,160),(320,y1,208),METAL)
        a.box((-1056,y0,272),(320,y1,320),METAL)
        for x in range(-1056,320,160):a.box((x,y0,208),(x+24,y1,272),TRIM)
    # Sealed glass-look bands keep scenery readable without collision loopholes.
    for y0,y1 in [(-303,-299),(299,303)]:a.box((-1040,y0,208),(320,y1,272),'met_blc_trim64')
    a.box((-704,-40,160),(-400,40,208),WOOD)
    for x in [-672,-560,-448]:
        for y in [-96,72]:a.box((x,y,160),(x+32,y+32,192),WOOD)
    stairs(-320,-192,-64,160)
    floor_holes(-1056,384,-304,304,320,[(-320,0,-192,-64)])
    # Stairwell landing joins one gated bridge entrance; all other bridge faces sealed.
    wall_x(0,-224,224,320,192,(-192,-64))
    a.box((0,-240,320),(384,-224,512),METAL)
    a.box((0,224,320),(384,240,512),METAL)
    a.box((368,-224,320),(384,224,512),METAL)
    a.box((-16,-240,512),(400,240,536),TRIM)
    # Recessed luminous panes suggest a bridge window without offering a route past lock.
    for y in [-184,-56,72]:a.box((384,y,384),(388,y+104,464),'met_blc_trim64')
    for x in [48,176,288]:
        for y in [-242,240]:a.box((x,y,384),(x+64,y+2,464),'met_blc_trim64')
    volume('func_door',(0,-192,320),(16,-64,432),TRIM,angle='90',lip='-8',as_unlock='1')
    a.box((272,-176,320),(352,176,368),'comp1_6')
    a.ent('info_as_objective',(224,0,344),step=2,title='Activate the naval guns')
    # Paired funnels, mast and twin long barrels recognizable from the dock.
    for x in [-848,-640]:
        a.box((x,-64,320),(x+96,64,608),METAL)
        a.box((x-8,-72,568),(x+104,72,608),'met_blc_trim64')
    a.box((-96,224,320),(-80,240,736),TRIM)
    a.box((-240,224,672),(64,240,688),TRIM)
    a.box((960,-128,0),(1168,128,64),TRIM)
    a.box((944,-144,64),(1136,144,144),METAL)
    for y in [-80,48]:
        a.box((1056,y,104),(1376,y+32,136),TRIM)
        a.box((1352,y-4,100),(1376,y+36,140),'met_blc_trim64')
        a.ent('info_as_cannon',(1380,y+16,144),target_x=1552,target_y=y+16,target_z=80)
    # Single sentry covers the exposed gangway without occupying a weapon pickup.
    a.box((464,-272,0),(544,-192,8),'aqpanl10')
    a.ent('info_as_sentry',(504,-232,32))
    # Lamps, strips and route-specific color cues.
    for x in [-928,-672,-416,-128,160]:
        light(x,0,116,210,'1 .66 .40')
        light(x,64,280,200,'.65 .82 1')
        a.box((x-24,282,80),(x+24,288,104),'tlight12')
    for x,y,z in [(672,96,-128),(624,224,-64)]:light(x,y,z,240,'.3 .8 1')
    light(224,0,472,240,'1 .72 .40')
    for x,y in [(640,-600),(-1024,-600),(896,640)]:light(x,y,400,380,'.52 .7 1')
    # Team spawns deliberately clear of furniture, water and objective machinery.
    for team,points in [(1,[(-1120,-960,24),(-960,-960,24),(-832,-1040,24),(-768,-928,24)]),(2,[(-512,-160,184),(-672,-160,184),(-928,64,184),(-800,144,184)])]:
        for p in points:a.ent('info_player_team'+str(team),p,angle=90 if team==1 else 0)
    a.ent('info_player_start',(-1120,-960,24),angle=90)
    for x,y,z in [(-1120,-960,0),(-832,-1040,0),(352,-672,0),(-128,0,0),(-800,96,0),(-672,-160,160),(160,96,160)]:a.ent('info_player_deathmatch',(x,y,z+24))
    # One checkpoint on the entry vestibule; forward respawns stay outside the bridge.
    a.ent('info_as_checkpoint',(288,-160,24),checkpoint=1)
    for x,y in [(256,-112),(288,0)]:a.ent('info_as_spawn',(x,y,24),checkpoint=1,role='attack')
    for x,y in [(-864,96),(-704,144)]:a.ent('info_as_spawn',(x,y,184),checkpoint=1,role='defend')
    for kind,x,y,z in [('weapon_rocketlauncher',-112,-1008,0),('weapon_supernailgun',-1200,-928,0),('weapon_supershotgun',-384,-1040,0),('weapon_nailgun',256,-64,0),('weapon_supershotgun',-800,96,160),('weapon_supernailgun',832,-240,0),('weapon_rocketlauncher',-736,160,0)]:pickup(kind,x,y,z)
    for x,y,z in [(-1200,-1040,0),(-256,-1168,0),(-528,-128,0),(-752,64,0),(-800,128,160),(64,128,160)]:pickup('item_health',x,y,z)
    for x,y,z in [(-1152,-896,0),(-192,-1008,0),(-160,160,0),(-624,96,160)]:
        pickup('item_shells',x,y,z);pickup('item_spikes',x+40,y,z)
    pickup('item_rockets',-48,-1008);pickup('item_rockets',-800,160)
    pickup('item_armor2',-64,-1232,144);pickup('item_armor2',768,-64,-224)
    pickup('item_health',-976,-64,0,spawnflags=2)
    return a, entities


def textures(path):
    data=path.read_bytes();assert struct.unpack_from('<i',data)[0]==29
    offset,length=struct.unpack_from('<ii',data,20);lump=data[offset:offset+length]
    result={}
    for i in range(struct.unpack_from('<i',lump)[0]):
        at=struct.unpack_from('<i',lump,4+i*4)[0]
        if at<0:continue
        name=lump[at:at+16].split(b'\0')[0].decode('ascii');w,h=struct.unpack_from('<II',lump,at+16)
        result[name]=lump[at:at+40+w*h*85//64]
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compiler-dir',type=Path,required=True)
    p.add_argument('--output',type=Path,default=ROOT/'test-results/frigate/build')
    p.add_argument('--fast-vis',action='store_true')
    p.add_argument('--install',action='store_true',help='Install BSP and provenance, update local map catalog; then run bake_base.gd')
    args=p.parse_args();out=args.output.resolve()
    for folder in ['maps','source','logs','licenses']:(out/folder).mkdir(parents=True,exist_ok=True)
    a,entities=generate()
    used={line.split(')')[-1].strip().split()[0] for brush in a.brushes+[b for _,b in entities] for line in brush.splitlines() if line.startswith('(')}
    donors={};sources={};old=json.loads((ROOT/'maps/HiSlop/texture-sources.json').read_text())
    for filename in ['as_hislop.bsp','lqdm1.bsp','lqdm3.bsp']:
        path=ROOT/'maps'/filename
        for name,raw in textures(path).items():
            if name not in used:continue
            if filename=='as_hislop.bsp':
                assert hashlib.sha256(raw).hexdigest()==old[name]['sha256']
            donors[name]=raw
            sources[name]=dict(source_bsp=filename,source_bsp_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),license='BSD-3-Clause',**({'original':old[name]} if filename=='as_hislop.bsp' else {}))
    wad_path=ROOT/'tools/fortressone/librequake.wad';raw_wad=wad_path.read_bytes();count,offset=struct.unpack_from('<ii',raw_wad,4)
    for i in range(count):
        at,size,_,_,_,_,name=struct.unpack_from('<iiiBBH16s',raw_wad,offset+32*i);name=name.split(b'\0')[0].decode('ascii')
        if name in used:
            donors[name]=raw_wad[at:at+size];sources[name]=dict(source_wad='tools/fortressone/librequake.wad',source_wad_sha256=hashlib.sha256(raw_wad).hexdigest(),license='BSD-3-Clause')
    donors['trigger']=donors[TRIM];sources['trigger']=dict(sources[TRIM],donor=TRIM)
    wad=bytearray(b'WAD2'+bytes(8));directory=[]
    for name in sorted(used):
        raw=struct.pack('16s',name.encode())+donors[name][16:];at=len(wad);wad.extend(raw)
        directory.append(struct.pack('<iiiBBH16s',at,len(raw),len(raw),68,0,0,name.encode()))
        sources[name]['sha256']=hashlib.sha256(raw).hexdigest()
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
    (out/'source/frigate.wad').write_bytes(wad)
    def fields(d):return '\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())
    world={'classname':'worldspawn','message':a.title,'wad':'frigate.wad','_fpsloppa_bake':'1','_fpsloppa_atlas':'2048','_minlight':'28','_sunlight':'100','_sun_mangle':'120 -65 0','_sunlight2':'30','_bounce':'1'}
    source=out/'source'/f'{NAME}.map';bsp=out/'maps'/f'{NAME}.bsp'
    source.write_text('{\n'+fields(world)+'\n'+'\n'.join(a.brushes)+'\n}\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in a.entities)+'\n'+'\n'.join('{\n'+fields(e)+'\n'+b+'\n}' for e,b in entities)+'\n')
    for tool,flags in [('qbsp',['-wadpath',str(out/'source'),str(source),str(bsp)]),('vis',['-threads','2',*(['-fast'] if args.fast_vis else []),str(bsp)]),('light',['-threads','2','-extra','-bspxlit',str(bsp)])]:
        print(tool,flush=True)
        with (out/'logs'/f'{tool}.log').open('w') as log:subprocess.run([str(args.compiler_dir.resolve()/tool),*flags],stdout=log,stderr=subprocess.STDOUT,check=True)
    log=(out/'logs/qbsp.log').read_text();assert 'LEAK' not in log.upper() and "Couldn't create brush faces" not in log
    data=bsp.read_bytes();assert struct.unpack_from('<i',data)[0]==29 and len(data)<25_000_000
    (out/'texture-sources.json').write_text(json.dumps(sources,indent=2)+'\n')
    for path in (ROOT/'maps/HiSlop').glob('LibreQuake-*.txt'):shutil.copy2(path,out/'licenses'/path.name)
    (out/'manifest.json').write_text(json.dumps(dict(id=NAME,title=a.title,format=29,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),brushes=len(a.brushes)+len(entities),entities=len(a.entities)+len(entities),textures=len(used),recommended_players=[4,8],modes=['as'],full_vis=not args.fast_vis,concept=True),indent=2)+'\n')
    print(bsp,len(data),'bytes',flush=True)
    if args.install:
        metadata=ROOT/'maps/Frigate';metadata.mkdir(exist_ok=True)
        shutil.copy2(bsp,ROOT/'maps'/bsp.name)
        for name in ['manifest.json','texture-sources.json']:shutil.copy2(out/name,metadata/name)
        for path in (out/'licenses').glob('*'):shutil.copy2(path,metadata/path.name)
        path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(path.read_text())
        catalog=[r for r in catalog if r['id']!=NAME]
        catalog.append(dict(id=NAME,title=a.title,modes=['as'],path='res://maps/'+bsp.name,scene='res://maps/cache/'+NAME+'.scn',sha256=hashlib.sha256(data).hexdigest()))
        path.write_text(json.dumps(catalog,indent=2)+'\n')


if __name__=='__main__':main()
