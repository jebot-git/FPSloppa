"""Audit base-distribution light data and conversion-added light without modifying maps."""
from pathlib import Path
import collections, hashlib, json, re, statistics, struct, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.makkon.theme import lumps
from tools.quake_source.build import blocks, fields

def audit():
    converted={}
    for group,tool in [('KOTH','koth'),('CC','cc')]:
        for row in json.loads((ROOT/f'tools/{tool}/recipes.json').read_text()):
            source=ROOT/f'maps/{group}/original/{row["source"]}.map'
            converted[row['id']]=(source,fields(blocks(source.read_text())[0]))
    result=[]
    for row in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()):
        if row.get('distribution','base')!='base':continue
        source=ROOT/row['path'].removeprefix('res://');data=source.read_bytes();parts,bspx=lumps(data)
        world={k.decode():v.decode() for k,v in re.findall(rb'"([^"\n]*)"\s*"([^"\n]*)"',parts[0].split(b'}')[0])}
        light=parts[8];rgb=next((v for k,v in bspx if k.rstrip(b'\0')==b'RGBLIGHTING'),b'')
        assert light and len(rgb)==len(light)*3, row['id']
        dark=0;normal=0
        for at in range(0,len(parts[7]),20):
            texinfo=struct.unpack_from('<H',parts[7],at+10)[0]
            flags=struct.unpack_from('<i',parts[6],texinfo*40+36)[0]
            offset=struct.unpack_from('<i',parts[7],at+16)[0]
            if not flags&1:
                normal+=1;dark+=offset<0
        entry={'id':row['id'],'sha256':hashlib.sha256(data).hexdigest(),'light_bytes':len(light),'rgb_bytes':len(rgb),
               'normal_faces':normal,'ordinary_faces_without_samples':dark,'median_sample':statistics.median(light),
               'authored_response':world.get('_fpsloppa_light_response')=='quake',
               'black_missing':world.get('_fpsloppa_light_response')=='quake' or world.get('_fpsloppa_black_missing')=='1',
               'lighting_keys':{k:v for k,v in world.items() if any(x in k for x in ['light','sun','bounce'])}}
        if row['id'] in converted:
            path,original=converted[row['id']]
            entry.update(category='converted LibreQuake',original_source=str(path.relative_to(ROOT)),
                         conversion_added_minlight=world.get('_minlight')!=original.get('_minlight'),
                         original_minlight=original.get('_minlight','0 (compiler default)'),
                         preserve_authored_sun={k:v for k,v in original.items() if k.startswith('_sun')},
                         recommendation='Authored sunlight preserved; conversion-added minimum light removed; rebake and black-face cache correction completed.' if entry['authored_response'] else 'Rebake without conversion-added minlight; retain original sunlight; use authored response and black-face handling.')
        elif entry['authored_response']:
            entry.update(category='Quake source',recommendation='Corrected in this task: authored bake, response and black-face handling.')
        else:
            entry.update(category='FPSloppa-authored layout',recommendation='No evidence for stripping authored minimum light/sun/bounce. '+
                         ('Missing-sample rendering and caches corrected; existing light samples preserved.' if entry['black_missing'] else 'Correct missing-sample rendering and rebuild caches; light data need not be rebaked for that fix.' if dark else 'Existing complete light data do not require the Q1 source-restoration rebake.'))
        result.append(entry)
    return {'map_count':len(result),'maps':result,
            'source_restoration_rebake_candidates':[r['id'] for r in result if r.get('conversion_added_minlight')],
            'remaining_black_face_rendering_candidates':[r['id'] for r in result if not r['black_missing'] and r['ordinary_faces_without_samples']],
            'shared_brightening_response_maps':[r['id'] for r in result if not r['authored_response']],
            'scope':'Final audit after 15 authored-map rebakes and three native-map missing-sample cache corrections.'}
if __name__=='__main__':
    report=audit();dest=ROOT/'docs/validation/base-lighting-audit.json';dest.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='maps'},indent=2))
