"""Publish the atlas identity only after all sixteen BSPs/caches pass preparation."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'maps/CQDistricts'
rows=[]
for zone in range(16):
 folder=BASE/f'district_{zone:02d}';layout=json.loads((folder/'layout.json').read_text());build=json.loads((folder/'build.json').read_text());validation=json.loads((folder/'validation.json').read_text())
 assert build['baked'] and validation['invalid_faces']==0 and validation['connected_routes']>=54
 files={name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in ['district.bsp','presentation.scn','collision.scn','navigation.res']}
 assert files['district.bsp']==build['sha256']
 rows.append(dict(id=zone,name=layout['name'],theme=layout['style'],origin=layout['origin'],spawns=layout['spawns'],pickup_positions=layout['pickup_positions'],neighbors=[g['neighbor'] for g in layout['gates']],files=files))
for row in rows:
 for neighbor in row['neighbors']:assert row['id'] in rows[neighbor]['neighbors']
manifest=dict(profile='cq-district-bsp-1',revision=2,format='BSP29',grid=[4,4],district_width_metres=250,gate_width_metres=24,gate_height_metres=16,local_bounds_metres=[[-137,-3,-137],[137,112,137]],districts=rows)
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('CQ_ATLAS_MANIFEST',hashlib.sha256((BASE/'manifest.json').read_bytes()).hexdigest())
