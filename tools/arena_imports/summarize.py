"""Publish hash-bound asset and gameplay receipts for the local arena catalog."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'test-results/arena-imports'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=json.loads((HERE/'conversions.json').read_text());results=[];failures=[];ready=[]
for row in rows:
 name=row['id'];asset=json.loads((OUT/(name+'.json')).read_text());game=json.loads((OUT/(name+'-gameplay.json')).read_text());errors=[]
 if digest(ROOT/'maps'/(name+'.bsp'))!=row['sha256']:errors.append('BSP changed')
 for report in [asset,game]:
  if report['bsp_sha256']!=row['sha256']:errors.append('Stale receipt')
  errors+=report['failures']
 if {c['format'] for c in asset['codecs']}!={'bc7','astc4'}:errors.append('Missing codec')
 for c in asset['codecs']:
  if digest(ROOT/c['path'].removeprefix('res://'))!=c['sha256']:errors.append('Cache changed: '+c['format'])
 for suffix in ['.scn','-lightmap1.scn']:
  if not (ROOT/'maps/cache'/(name+suffix)).exists():errors.append('Missing raw cache')
 if not (ROOT/'maps/navigation'/(name+'.res')).exists():errors.append('Missing navigation')
 if not errors and game['fully_connected']:ready.append(name)
 result={'id':name,'collection':row['collection'],'sha256':row['sha256'],'baked_faces':asset['baked_faces'],'colour_texture_slots_with_full_mips':asset['colour_textures'],'light_atlases':asset['light_atlases'],'lightmaps_lossless_unmipped':True,'codecs':asset['codecs'],'safe_spawns':sum(p['safe'] for p in game['spawns']),'spawns':len(game['spawns']),'spawn_routes':[game['reachable_spawn_pairs'],game['spawn_route_pairs']],'pickup_routes':[game['reachable_pickups'],game['tested_pickups']],'fully_connected':game['fully_connected'],'failures':errors}
 results.append(result)
 if errors:failures.append({'id':name,'errors':errors})
report={'maps':len(results),'baked_faces':sum(r['baked_faces'] for r in results),'full_mip_colour_slots':sum(r['colour_texture_slots_with_full_mips'] for r in results),'fully_connected_spawn_networks':len(ready),'failures':failures,'results':results}
(HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
(ROOT/'maps/arena_imports_maplist.txt').write_text('\n'.join(r['id'] for r in results if not r['failures'])+'\n')
(ROOT/'maps/arena_imports_bot_maplist.txt').write_text('\n'.join(ready)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='results'},indent=2))
raise SystemExit(bool(failures))
