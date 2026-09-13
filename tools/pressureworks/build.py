"""Pressureworks: original CC0 brush geometry, compiled with ericw-tools.

Makkon texture records are copied unchanged; their separate licence applies.
Run from any directory: python3 tools/pressureworks/build.py --compiler PATH
"""
from pathlib import Path
import argparse, hashlib, json, math, shutil, struct, subprocess, sys, zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from generate_tf_maps import Arena

ID = 'tf_pressureworks'
OUT = ROOT / 'maps/Pressureworks'
FLOOR = 'med_flat5a'
WALL = 'ind_brk01_brwn'
TRIM = 'metal_iron1_01'
GRATE = 'metal_iron1_07'
STONE = 'med_cobstn1_2'


class StyledArena(Arena):
    def face(self, points, texture):
        # Brush UV scale changes sampling only; original texture bytes stay intact.
        scale = .5 if texture.startswith(('ind_', 'metal_')) else 1
        if texture.startswith('med_rock'):scale=2
        return super().face(points,texture).rsplit(' ',2)[0]+f' {scale:g} {scale:g}'


def prism(a,ring,bottom,top,texture):
    low=[(*p,bottom) for p in ring];high=[(*p,top) for p in ring]
    faces=[list(reversed(low[:3])),high[:3]]
    faces += [[low[i],low[(i+1)%len(ring)],high[(i+1)%len(ring)]] for i in range(len(ring))]
    a.brushes.append('{\n'+'\n'.join(a.face(f,texture) for f in faces)+'\n}')


def pipe_y(a,x,y0,y1,z,radius,texture):
    # Rotate an eight-sided column into a real round overhead pipe.
    helper=StyledArena('pipe','pipe');column(helper,0,0,radius,y0,y1,texture)
    import re
    def point(m):
        u,v,w=map(float,m.group(1).split())
        return '( %g %g %g )'%(x+u,w,z-v)
    a.brushes.append(re.sub(r'\( ([^()]+) \)',point,helper.brushes[0]))


def column(a, x, y, radius, bottom, top, texture):
    """Eight-sided original pressure vessel; outward face order matches Arena."""
    ring=[(x+round(radius*math.cos(i*math.pi/4)),y+round(radius*math.sin(i*math.pi/4))) for i in range(8)]
    low=[(*p,bottom) for p in ring];high=[(*p,top) for p in ring]
    faces=[list(reversed(low[:3])),high[:3]]
    faces += [[low[i],low[(i+1)%8],high[(i+1)%8]] for i in range(8)]
    a.brushes.append('{\n'+'\n'.join(a.face(f,texture) for f in faces)+'\n}')


def generate():
    a = StyledArena(ID, 'Pressureworks | TF 6v6', 2048, 1024, 640)
    # One sealed hull. Both playable halves are exact 180-degree rotations.
    for x0,x1 in [(-2048,-896),(896,2048)]:a.box((x0,-1024,-64),(x1,1024,0),FLOOR)
    a.box((-896,-512,-64),(896,512,0),STONE)
    # Irregular material boundaries, all at the same walkable ground elevation.
    xs=[-896,-576,-256,0,256,576,896];edges=[824,768,848,792,864,800,824]
    for side in (-1,1):
        for i in range(len(xs)-1):
            x0,x1=xs[i:i+2];y0,y1=edges[i:i+2]
            for ring,t in [([(x0,512),(x1,512),(x1,y1),(x0,y0)],'gravel2'),
                           ([(x0,y0),(x1,y1),(x1,1024),(x0,1024)],'grass1')]:
                prism(a,[(side*x,side*y) for x,y in ring],-64,0,t)
    for p, q in [((-2080,-1184,-64),(-2048,1184,640)),
                 ((2048,-1184,-64),(2080,1184,640))]:
        a.box(p, q, WALL)
    for side in (-1,1):
        def edgebox(p,q,t):
            p=(p[0]*side,p[1]*side,p[2]);q=(q[0]*side,q[1]*side,q[2])
            a.box(tuple(min(v,w) for v,w in zip(p,q)),tuple(max(v,w) for v,w in zip(p,q)),t)
        for x0,x1 in [(-2048,-896),(896,2048)]:
            edgebox((x0,1024,-64),(x1,1184,128),'med_cobstn1_2a')
            edgebox((x0,1024,128),(x1,1184,640),WALL)
        edgebox((-896,1024,-64),(896,1184,128),'med_cobstn1_2a')
        edgebox((-896,1152,128),(896,1184,640),'sky_star')
        # Uneven quarry escarpment above the retaining wall; clear at player height.
        ridge=[416,560,472,608,496,568,448]
        for i,(x0,x1) in enumerate(zip(xs,xs[1:])):
            h=512;h0,h1=ridge[i:i+2]
            helper=StyledArena('cliff','cliff')
            prism(helper,[(x0,1008),(x1,1024),(x1,1152),(x0,1152)],128,h,'med_rock5_g1' if i%2 else 'med_rock5')
            import re
            def mirror(m):
                x,y,z=map(float,m.group(1).split())
                if z==h:
                    z=h0+(h1-h0)*(x-x0)/(x1-x0)
                    if y<1100:y-=48
                return '( %g %g %g )'%(x*side,y*side,z)
            a.brushes.append(re.sub(r'\( ([^()]+) \)',mirror,helper.brushes[0]))
    a.box((-2080,-1184,640),(2080,1184,672),'sky_star')
    # Turbine island: diagonal ramps permit every class to use the upper route.
    # Underpasses at y +/- 352 and lower flank lanes stay independent.
    a.box((-256,-256,0),(256,256,128),'ind_brk02_gry1')
    a.box((-256,-512,112),(256,512,128),GRATE)
    # The machine blocks all base-to-base shots through the middle.
    column(a,0,0,144,128,384,'metal_copp_01')
    column(a,0,0,160,192,208,TRIM)
    column(a,0,0,176,368,400,TRIM)
    column(a,0,0,80,400,512,'ind_w08_grn1')
    column(a,0,0,96,496,528,TRIM)
    for side in (-1,1):
        def pos(p): return (p[0]*side,p[1]*side,p[2])
        def box(p,q,t=WALL):
            p,q=pos(p),pos(q)
            a.box(tuple(min(v,w) for v,w in zip(p,q)),tuple(max(v,w) for v,w in zip(p,q)),t)
        def ramp(x0,x1,y0,y1,z0,z1):
            if side>0:a.ramp_x(x0,x1,y0,y1,z0,z1,GRATE)
            else:a.ramp_x(-x1,-x0,-y1,-y0,z1,z0,GRATE)
        team = 'red' if side<0 else 'blue'
        paint = 'ind_w01_red1' if side<0 else 'ind_w01_blu1'
        deck = 'ind_dp01_red1' if side<0 else 'ind_dp01_blu1'
        ramp(256,768,-512,-320,128,0)
        # Short supports, edge kerbs and suspended gantry silhouette.
        box((224,-512,0),(256,-320,112),TRIM)
        box((288,80,0),(448,240,112),'ind_cont1_ylw1')
        box((416,624,0),(544,784,112),'ind_cont2_blk1')
        box((48,800,0),(240,960,160),'ind_wd01_brwn1')
        box((64,816,160),(224,944,176),TRIM)
        # Overhead pipe gantries and wall piers give the yard its scale.
        pipe_y(a,496*side,-1024,1024,352,16,'metal_copp_01')
        for y in (-768,-256,256,768):pipe_y(a,496*side,y-6,y+6,352,23,TRIM)
        for y in (-992,960):
            box((464,y,0),(528,y+32,368),TRIM)
        for x in (128,576):
            box((x,992,0),(x+48,1024,512),TRIM)
            box((x-16,976,384),(x+64,1024,416),'ind_w01_ylw1')
        # Three separated front doors: south maintenance, hall, north service.
        for y0,y1 in [(-1024,-832),(-608,-144),(144,608),(832,1024)]:
            box((896,y0,0),(944,y1,64),'ind_brk02_gry1')
            box((896,y0,64),(944,y1,320),'ind_brk02_red1')
            box((888,y0,144),(896,y1,176),paint)
        box((896,-1024,192),(944,1024,224),'ind_brk02_gry1')
        for y in (-720,0,720):
            # Tall doorway reveals; 4.5 m centre entry, 7 m outer entries.
            box((864,y-144,224),(976,y+144,256),'ind_brk02_gry1')
            for dy in (-152,144):box((864,y+dy,0),(880,y+dy+8,224),TRIM)
            a.ent('light',pos((992,y,176)),light=250,_color='1 .82 .62' if side<0 else '.65 .8 1')
            # Recessed lamps and lintel bands make the entrances read as masonry.
            box((876,y-32,240),(888,y+32,280),TRIM)
            box((872,y-24,244),(876,y+24,276),'tlight12')
        # Covered pump hall with clerestory roof. Never shoot directly into vault.
        box((944,-576,320),(2048,576,344),'ind_wd03_brwn1')
        box((928,-592,344),(2048,592,368),'ind_w02_blk1')
        for y in (-552,528):box((960,y,272),(2048,y+24,320),TRIM)
        for x in (1040,1360,1680,2000):
            box((x,-576,288),(x+24,576,320),'ind_wd01_brwn1')
        # Ventilation housings use separate machinery materials, not wall cladding.
        box((1552,536,96),(1744,544,192),'ind_ac01_grey1')
        box((1216,-160,0),(1312,160,128),'ind_dct2_red1' if side<0 else 'ind_dct2_blu1')
        # The two flag-room doors are independently exposed to each flank.
        box((1504,-192,0),(1536,192,256),'ind_brk01_gry1')
        box((1496,-192,160),(1504,192,192),paint)
        box((1504,-576,0),(1536,-448,256),'ind_brk01_gry1')
        box((1504,448,0),(1536,576,256),'ind_brk01_gry1')
        box((1536,-576,0),(2048,-544,256),WALL)
        box((1536,544,0),(2048,576,256),WALL)
        box((1504,-576,256),(2048,576,280),'ind_wd03_brwn1')
        # Upper side gallery has a continuous walking route back out.
        ramp(960,1440,-512,-288,0,128)
        box((1440,-512,112),(2016,-256,128),GRATE)
        # Low strips mark the ledge without narrow collision rails.
        box((1440,-272,128),(2016,-256,136),deck)
        # Flag dais is flush: no jump or snag at the objective.
        box((1664,-112,0),(1888,112,4),deck)
        box((2000,-128,0),(2048,128,160),'ind_ac01_grey1')
        for y in (-224,224):
            box((2000,y-16,0),(2048,y+16,256),TRIM)
        # Rear service spawn room: two screened exits, away from capture/flag.
        box((1472,704,0),(1504,896,224),'ind_brk01_gry1')
        box((1464,704,144),(1472,896,176),paint)
        box((1472,576,224),(2048,1024,256),'ind_wd03_brwn1')
        box((1680,624,0),(1840,656,160),'ind_wd01_brwn1')
        box((1680,944,0),(1840,976,160),'ind_wd01_brwn1')
        # Capture is in the pump hall, separate from the deeper flag vault.
        box((1024,288,0),(1184,448,4),deck)
        spawns=[pos((x,y,24)) for x in (1584,1712,1840,1968) for y in (736,864)]
        a.team(side,pos((1776,0,28)),spawns,pos((1968,800,24)),pos((1104,368,28)))
        a.ent('item_health',pos((672,720,24)))
        a.ent('item_shells',pos((512,-800,24)))
        # Readable repeated structural bays and industrial skyline.
        for x in (1024,1408,1920):
            for y in (-1008,992):box((x,y,0),(x+32,y+16,416),TRIM)
        box((1616,448,352),(1840,560,464),'ind_w08_grn1')
        box((1696,464,464),(1760,528,592),TRIM)
        # Roof-mounted tanks and valve wheels distinguish the pump stations.
        for x in (1120,1360):
            column(a,x*side,160*side,72,352,496,paint)
            column(a,x*side,160*side,80,368,384,TRIM)
            column(a,x*side,160*side,80,480,504,TRIM)
        for x,y,z,power in [(1760,0,224,330),(1152,0,272,300),(1808,800,192,300),
                            (1248,-704,224,200),(1248,704,224,200),(1792,-384,208,180)]:
            a.ent('light',pos((x,y,z)),light=power,_color='1 .84 .68' if side<0 else '.68 .84 1')
    a.ent('info_player_start',(-1584,-736,24),angle=0)
    for y in (-704,704):a.ent('light',(0,y,320),light=280,_color='.85 .95 1')
    a.ent('light',(0,0,592),light=400,_color='1 .9 .7')
    return a


def wad_records(path):
    data=path.read_bytes();count,offset=struct.unpack_from('<ii',data,4);result={}
    for i in range(count):
        p,n,_,kind,compression,_,name=struct.unpack_from('<iiiBBH16s',data,offset+32*i)
        if kind==68 and compression==0:result[name.split(b'\0')[0].decode().lower()]=data[p:p+n]
    return result


def materials(names,librequake_archive):
    # The shipped editor WAD is enough to reproduce this revision. Full original
    # archives are needed only when selecting additional texture names.
    textures={};sources={}
    if (OUT/'pressureworks.wad').exists() and (OUT/'texture-sources.json').exists():
        known=json.loads((OUT/'texture-sources.json').read_text())
        for name,data in wad_records(OUT/'pressureworks.wad').items():
            if name in known and hashlib.sha256(data).hexdigest()==known[name]['sha256']:
                textures[name]=data;sources[name]=known[name]
    if names<=textures.keys():return textures,sources
    from makkon.theme import makkon as load_makkon, wad_textures
    makkon,selection=load_makkon();textures.update(makkon);sources.update(selection)
    if names<=textures.keys():return textures,sources
    archive=librequake_archive.read_bytes();archive_hash=hashlib.sha256(archive).hexdigest()
    with zipfile.ZipFile(librequake_archive) as z:
        for name in z.namelist():
            if not name.endswith('.wad'):continue
            raw=z.read(name)
            for key,record in wad_textures(raw).items():
                if key not in textures:
                    textures[key]=record
                    sources[key]={'source':'https://github.com/lavenderdotpet/LibreQuake','archive_sha256':archive_hash,'wad':name,'wad_sha256':hashlib.sha256(raw).hexdigest(),'license':'BSD-3-Clause','sha256':hashlib.sha256(record).hexdigest(),'format':'original WAD2 miptex; all four mip levels unchanged'}
    assert names<=textures.keys(),'Missing original textures: '+str(names-textures.keys())
    return textures,sources


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--compiler',type=Path,required=True)
    parser.add_argument('--threads',type=int,default=8)
    parser.add_argument('--librequake-archive',type=Path,default=ROOT/'tools/pressureworks/local/librequake-dev.zip');args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);logs=ROOT/'test-results/pressureworks';logs.mkdir(parents=True,exist_ok=True)
    a=generate()
    world={'classname':'worldspawn','message':a.title,'wad':'pressureworks.wad','_fpsloppa_bake':'1',
           '_fpsloppa_atlas':'4096','_minlight':'28','_sunlight':'115','_sunlight2':'35',
           '_sun_mangle':'45 -65 0','_bounce':'1','worldtype':'0'}
    def entity(d):return '\n'.join('"%s" "%s"'%item for item in d.items())
    source='{\n'+entity(world)+'\n'+'\n'.join(a.brushes)+'\n}\n'+'\n'.join('{\n'+entity(e)+'\n}' for e in a.entities)+'\n'
    import re
    names=set(re.findall(r'\) (\S+) 0 0 0 [\d.]+ [\d.]+',source))
    donors,selection=materials(names,args.librequake_archive)
    wad=bytearray(b'WAD2'+bytes(8));directory=[];credits={}
    for name in sorted(names):
        record=donors[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(record),len(record),68,0,0,name.encode()));wad.extend(record)
        credits[name]=selection[name]
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
    (OUT/'pressureworks.wad').write_bytes(wad);(OUT/(ID+'.map')).write_text('// Original geometry, CC0-1.0. Textures: separate licences.\n'+source)
    (OUT/'texture-sources.json').write_text(json.dumps(credits,indent=2)+'\n')
    for old,new in [('deathmatch/maps/texture_replacements/Makkon_License.txt','Makkon_License.txt'),('maps/LibreQuake-COPYING.txt','LibreQuake-COPYING.txt'),('maps/LibreQuake-CREDITS.txt','LibreQuake-CREDITS.txt')]:shutil.copy2(ROOT/old,OUT/new)
    bsp=ROOT/'maps'/f'{ID}.bsp'
    threads=str(max(1,min(args.threads,16)))
    for binary,flags in [('qbsp',[str(OUT/(ID+'.map')),str(bsp)]),('vis',['-threads',threads,str(bsp)]),('light',['-threads',threads,'-extra','-bspxlit',str(bsp)])]:
        with (logs/(binary+'.log')).open('w') as log:
            subprocess.run([str(args.compiler.resolve()/binary),*flags],cwd=OUT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
    assert not bsp.with_suffix('.pts').exists(),'Map leaked'
    # Navigation depends on collision geometry; discard this map's generated cache.
    (ROOT/'maps/navigation'/f'{ID}.res').unlink(missing_ok=True)
    data=bsp.read_bytes()
    assert len(data)<25_000_000 and struct.unpack_from('<i',data)[0]==29
    texture_at,_=struct.unpack_from('<ii',data,20)
    count=struct.unpack_from('<i',data,texture_at)[0];audit=[]
    for i in range(count):
        at=texture_at+struct.unpack_from('<i',data,texture_at+4+i*4)[0]
        name=data[at:at+16].split(b'\0')[0].decode();record=donors[name]
        embedded=data[at:at+len(record)];assert embedded==record,'Compiler changed texture '+name
        audit.append({'texture':name,'unchanged':True,'sha256':hashlib.sha256(embedded).hexdigest()})
    (OUT/'texture-audit.json').write_text(json.dumps({'bsp_sha256':hashlib.sha256(data).hexdigest(),'textures':audit},indent=2)+'\n')
    report={'id':ID,'title':a.title,'sha256':hashlib.sha256(bsp.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((OUT/(ID+'.map')).read_bytes()).hexdigest(),'bytes':bsp.stat().st_size,'brushes':len(a.brushes),'team_spawns':[8,8],'target_players':12,'supported_players':[8,16],'geometry_license':'CC0-1.0','textures':'texture-sources.json','rotational_symmetry':True}
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

if __name__=='__main__':main()
