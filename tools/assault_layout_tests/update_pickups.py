"""Replace only Assault pickup entities, preserving every geometry/light/BSPX payload."""
from pathlib import Path
import hashlib,json,re,struct,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from assault_layout_tests.pickups import inventory,is_pickup,counts,roof_guards
from assault_layout_tests.layouts import SCALES
from skyboxes.audit import BSP


def unpack(raw):
    lumps=[raw[o:o+n] for o,n in struct.iter_unpack('<ii',raw[4:124])]
    end=(max(o+n for o,n in struct.iter_unpack('<ii',raw[4:124]))+3)&~3
    extra=[]
    if raw[end:end+4]==b'BSPX':
        for i in range(struct.unpack_from('<I',raw,end+4)[0]):
            name,at,size=struct.unpack_from('<24sII',raw,end+8+32*i);extra.append((name,raw[at:at+size]))
    return lumps,extra


def repack(raw,entities):
    lumps,extra=unpack(raw);lumps[0]=entities
    result=bytearray(raw[:124])
    for i,data in enumerate(lumps):
        result.extend(bytes((-len(result))%4));struct.pack_into('<II',result,4+i*8,len(result),len(data));result.extend(data)
    if extra:
        result.extend(bytes((-len(result))%4));header=len(result);result.extend(b'BSPX'+struct.pack('<I',len(extra))+bytes(32*len(extra)))
        for i,(name,data) in enumerate(extra):
            result.extend(bytes((-len(result))%4));struct.pack_into('<24sII',result,header+8+32*i,name,len(result),len(data));result.extend(data)
    a,ax=unpack(raw);b,bx=unpack(result)
    assert a[1:]==b[1:] and ax==bx
    return result


def main():
    out=ROOT/'test-results/assault-pickups';out.mkdir(parents=True,exist_ok=True)
    manifest_path=ROOT/'deathmatch/maps/manifest.json';manifest=json.loads(manifest_path.read_text());report=[]
    for row in manifest:
        if row['id'] not in ['as_hislop','as_frigate','as_hislop_tiny','as_frigate_tiny']:continue
        path=ROOT/row['path'].removeprefix('res://')
        if not path.exists():continue
        raw=path.read_bytes();bsp=BSP(path);kind='hislop' if 'hislop' in row['id'] else 'frigate';tiny=row['id'].endswith('_tiny')
        picks=inventory(kind,tiny)+roof_guards(kind);sx,sy=(1,1) if tiny else SCALES[kind]
        invalid=[]
        for p in picks:
            x,y,z=map(float,p['origin'].split());offset=16 if is_pickup(p) else 0
            p['origin']='%g %g %g'%((x+offset)*sx-offset,(y+offset)*sy-offset,z)
            center=((x+offset)*sx,(y+offset)*sy,z)
            if bsp.contents(center)==-2:invalid.append(dict(entity=p,reason='solid'))
            elif bsp.trace(center,(center[0],center[1],center[2]-64))[0]!=-2:invalid.append(dict(entity=p,reason='no nearby floor'))
        if invalid:
            print(json.dumps({'map':row['id'],'invalid':invalid},indent=2));raise SystemExit(1)
        entities=[e for e in bsp.entities if not is_pickup(e) and 'fpsloppa_roof_guard' not in e]+picks
        text='\n'.join('{\n'+'\n'.join('"%s" "%s"'%(k,v) for k,v in e.items())+'\n}' for e in entities)+'\n\0'
        new=repack(raw,text.encode('latin1'));oldhash=hashlib.sha256(raw).hexdigest();newhash=hashlib.sha256(new).hexdigest()
        backup=out/(row['id']+'-before.bsp')
        if not backup.exists():backup.write_bytes(raw)
        oldhash=hashlib.sha256(backup.read_bytes()).hexdigest()
        a,ax=unpack(backup.read_bytes());b,bx=unpack(new);assert a[1:]==b[1:] and ax==bx
        path.write_bytes(new);row['sha256']=newhash;row['size']=len(new)
        metadata=ROOT/'maps'/('HiSlop' if kind=='hislop' else 'Frigate')
        if tiny:metadata/='Tiny'
        mp=metadata/'manifest.json'
        if mp.exists():
            data=json.loads(mp.read_text());data.update(sha256=newhash,bytes=len(new),entities=len(entities),pickup_revision='ut99-reference-1');mp.write_text(json.dumps(data,indent=2)+'\n')
        report.append(dict(id=row['id'],old_sha256=oldhash,sha256=newhash,geometry_lighting_unchanged=True,roof_guards=len(roof_guards(kind)),**counts(kind)))
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    # Retain old hashes for imported older maps, and add the new official aliases.
    sky=ROOT/'deathmatch/maps/skies/SOURCES.json';data=json.loads(sky.read_text())
    for row in report:
        if not row['id'].endswith('_tiny'):data['map_sources'][row['sha256']]=row['id']
    sky.write_text(json.dumps(data,indent=2)+'\n')
    (out/'update.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

if __name__=='__main__':main()
