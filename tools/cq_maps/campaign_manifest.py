"""Publish only a fully baked, independently validated 81-map atlas."""
import collections,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from tools.district_cluster.world import atlas
from tools.makkon.theme import bsp_textures,name,sha
BASE=ROOT/'maps/CampaignDistricts'

def signature(streets):
    variants=[]
    for mirror in (-1,1):
        for turns in range(4):
            roads=[]
            for road in streets:
                line=[]
                for x,y in road:
                    x*=mirror
                    for _ in range(turns):x,y=-y,x
                    line.append((x,y))
                roads.append(min(tuple(line),tuple(reversed(line))))
            variants.append(tuple(sorted(roads)))
    return hashlib.sha256(repr(min(variants)).encode()).hexdigest()

def main():
    rows=[];seen=set();checks=[];world=atlas();materials=set();native_sources={}
    for i in range(81):
        folder=BASE/f'district_{i:02}';layout=json.loads((folder/'layout.json').read_text());build=json.loads((folder/'build.json').read_text());v=json.loads((folder/'validation.json').read_text())
        assert layout['campaign']==world[f'd{i:02}'] and layout['revision']=='campaign-city-1'
        assert layout.get('material_revision')=='makkon-expanded-1' and build.get('material_revision')=='makkon-expanded-1'
        materials.update(layout['makkon_faces'])
        for key,source in json.loads((folder/'texture-sources.json').read_text()).items():
            if source.get('author')=='Ben "Makkon" Hale':native_sources[key]=source
        sig=signature(layout['streets']);assert sig not in seen,('Mirrored or rotated street clone',i);seen.add(sig)
        assert not v['route_failures'] and v['invalid_faces']==0 and v['connected_routes']>=50 and build['baked']
        assert v['gate_rays']==3*len(world[f'd{i:02}']['links'])
        if layout['profile']!='open':
            assert v['covered_samples']/v['roof_samples']>=(.5 if layout['profile']=='mixed' else .85)
            assert v['jetpack_clearance_samples']==42 and v['open_courtyards']==3
        assert len(layout['rooms'])>=3 and len(layout['spawns'])==4 and len(layout['pickup_positions'])==8
        files={name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in ('district.bsp','presentation.scn','collision.scn','navigation.res')}
        assert files['district.bsp']==build['sha256']==v['bsp_sha256']
        sources=json.loads((folder/'texture-sources.json').read_text())
        for raw in bsp_textures((folder/'district.bsp').read_bytes()):
            if raw and name(raw) in layout['makkon_faces']:assert sha(raw)==sources[name(raw)]['sha256'],('Modified native Makkon record',i,name(raw))
        rows.append(dict(id=i,name=layout['name'],theme=layout['style'],profile=layout['profile'],origin=[0,0,0],spawns=layout['spawns'],pickup_positions=layout['pickup_positions'],neighbors=[g['neighbor'] for g in layout['gates']],files=files,campaign=layout['campaign']))
        checks.append(dict(district=i,signature=sig,bytes=build['bytes'],faces=build['faces'],vertices=build['vertices'],leaves=build['leaves'],nodes=build['nodes'],routes=v['connected_routes'],profile=layout['profile'],seed_round=layout.get('seed_round',0)))
    manifest=dict(profile='vesper-campaign-81',revision=1,format='BSP29',grid=[9,9],district_width_metres=250,gate_width_metres=24,gate_height_metres=16,local_bounds_metres=[[-137,-3,-137],[137,112,137]],districts=rows)
    (BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (ROOT/'docs/validation/campaign-81-maps.json').write_text(json.dumps(dict(districts=81,distinct_layouts=len(seen),expanded_makkon_materials=sorted(materials),all_native_makkon_materials=len(native_sources),profiles=dict(collections.Counter(r['profile'] for r in rows)),routes=sum(r['routes'] for r in checks),maps=checks),indent=2)+'\n')
    print('CAMPAIGN_ATLAS_VALIDATED',len(rows),'routes',sum(r['routes'] for r in checks))
if __name__=='__main__':main()
