"""Fail closed on absent/stale DE/ST assets before creating a base bundle."""
import hashlib,json
from pathlib import Path
def verify(root,paths):
 names={str(p) for p in paths};catalog=json.loads((root/'tools/expansions/catalog.json').read_text())
 proof=json.loads((root/'tools/expansions/validation.json').read_text());assert proof['complete'] and len(proof['maps'])==proof['expected_maps']
 expected={r['id'] for r in json.loads((root/'deathmatch/maps/manifest.json').read_text()) if r.get('distribution','base')=='base' and any(m in ['de','st'] for m in r.get('modes',[]))}
 assert {r['id'] for r in proof['maps']}==expected
 assert {r['id'] for r in catalog}<=expected
 for row in proof['maps']:
  assert not row['failures'] and row['baked_faces']>0 and row['light_atlases']>0,row['id']
  assert {c['format'] for c in row['codecs']}=={'bc7','astc4'}
  for asset in row['assets']:
   assert asset['path'] in names,asset['path']
   assert hashlib.sha256((root/asset['path']).read_bytes()).hexdigest()==asset['sha256'],asset['path']
 caches=json.loads((root/'tools/expansions/cache_validation.json').read_text());assert not caches['failures']
 assert {(c['id'],c['codec']) for c in caches['caches']}=={(name,codec) for name in expected for codec in ['', 'bc7','astc4']}
 for c in caches['caches']:
  suffix='-'+c['codec'] if c['codec'] else ''
  path=root/('maps/cache/'+c['id']+'-lightmap1'+suffix+'.scn')
  assert hashlib.sha256(path.read_bytes()).hexdigest()==c['sha256'],path
 art=json.loads((root/'tools/expansions/runtime_art.json').read_text());assert not art['failures']
 for name,digest in art['resources'].items():assert hashlib.sha256((root/name.removeprefix('res://')).read_bytes()).hexdigest()==digest,name
 index=json.loads((root/'deathmatch/maps/penetration/index.json').read_text())
 cover=json.loads((root/'tools/de_penetration/validation.json').read_text());assert not cover['failures']
 converted={r['id'] for r in catalog if r['mode']=='de'}
 assert {r['id'] for r in cover['maps']}==converted
 assert len(index)==len(converted)
 for row in cover['maps']:
  digest=hashlib.sha256((root/'maps'/f"{row['id']}.bsp").read_bytes()).hexdigest()
  assert digest==row['bsp_sha256'] and digest in index,row['id']
  profile=index[digest];assert profile['sha256']==row['profile_sha256'],row['id']
  path=root/profile['path'].removeprefix('res://')
  assert hashlib.sha256(path.read_bytes()).hexdigest()==profile['sha256'],path
 print('Verified base DE/ST assets:',len(expected),'maps and',len(art['textures']),'runtime textures')
