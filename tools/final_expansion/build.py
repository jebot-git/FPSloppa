"""Package the closed expansion selection; refuse unreviewed changes after freezing."""
from pathlib import Path
import argparse, hashlib, json, struct, zipfile
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
VERSION='0.22v';NAME=f'FPSloppa-{VERSION}-Final-Expansion.zip'
MODES=['dm','tdm','ig','if','ft','cc','ctf','koth','as','tf','tb','de','st']
def read(p):return json.loads((ROOT/p).read_text())
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def selected():
 return [r['id'] for r in read('tools/expansions/catalog.json')]+[r['id'] for r in read('tools/arena_imports/conversions.json')]+[r['id'] for r in read('tools/unreal_imports/installed.json')]+[r['id'] for r in read('tools/unreal_imports/as-installed.json')]
def plan():
 ids=selected();assert len(ids)==len(set(ids))==78,'Final scope is 22 ST, 14 DE, 31 arena, 7 KOTH, 4 AS maps'
 catalog=read('deathmatch/maps/manifest.json');byid={r['id']:r for r in catalog};new=[byid[x] for x in ids]
 old=[r for r in catalog if r.get('distribution','base')=='base' and r['id'] not in ids]
 banned=set(read('deathmatch/maps/retired.json'))|set(read('tools/arena_imports/distribution-policy.json')['excluded_ids'])
 assert not banned.intersection(ids)
 paths=set();generated={};rotations={};maps=[]
 def add(path):
  path=str(path).removeprefix('res://');p=ROOT/path
  assert p.is_file(),path
  assert not p.is_symlink() and '..' not in Path(path).parts,path
  paths.add(path)
 for row in new:
  assert sha(ROOT/row['path'].removeprefix('res://'))==row['sha256'],row['id']
  add(row['path']);add('maps/navigation/'+row['id']+'.res')
  cache=row['scene'].removeprefix('res://').removesuffix('.scn')
  data=(ROOT/row['path'].removeprefix('res://')).read_bytes()
  offset,length=struct.unpack_from('<ii',data,4)
  assert b'"_fpsloppa_bake" "1"' in data[offset:offset+length].split(b'}')[0],row['id']
  # Every selected BSP uses the versioned lightmap cache. The plain scene is
  # an identical preparation copy and is never selected by this loader.
  selection=read('tools/final_expansion/cache-selection.json')[row['id']]
  assert selection['bsp_sha256']==row['sha256'],row['id']
  active=selection['active']
  assert active.startswith(cache+'-lightmap1'),active
  for suffix in ['', '-bc7','-astc4']:add(active+suffix+'.scn')
  if (ROOT/'maps'/(row['id']+'.lit')).exists():add('maps/'+row['id']+'.lit')
  maps.append({k:row[k] for k in ['id','title','author','modes','path','scene','sha256'] if k in row})
 for mode in MODES:
  eligible=lambda r:mode in r['modes'] or mode=='if' and 'ig' in r['modes']
  rotation=[r['id'] for r in old+new if eligible(r)]
  assert len(rotation)==len(set(rotation)) and len(rotation)<=128 and not banned.intersection(rotation),mode
  rotations[mode]=rotation;generated['maps/'+mode+'_maplist.txt']=('\n'.join(rotation)+'\n').encode()
 for name in ['arena_imports_bot_maplist.txt','arena_imports_maplist.txt','ut_koth_maplist.txt','ut_as_maplist.txt','varq_de_maplist.txt']:add('maps/'+name)
 # Preserve original notices and provenance; never package scratch inputs or raw source WADs.
 for folder in ['maps/ExpansionNotices','maps/UnrealImports']+['maps/ArenaImports/'+r['id'] for r in new if r['id'].startswith('dm_')]:
  for p in (ROOT/folder).rglob('*'):
   if p.is_file() and p.suffix.lower() in {'.txt','.md','.json','.html','.htm'}:add(p.relative_to(ROOT))
 for path,digest in read('tools/expansions/runtime_art.json')['resources'].items():
  add(path);assert sha(ROOT/path.removeprefix('res://'))==digest,path
 for p in (ROOT/'deathmatch/vehicles/tribes').iterdir():
  if p.is_file() and p.suffix in {'.png','.res','.scn','.md'}:add(p.relative_to(ROOT))
 for p in (ROOT/'deathmatch/maps/penetration').glob('*.json'):add(p.relative_to(ROOT))
 for path in ['ASSET_CREDITS.md','docs/ARENA-IMPORTS.md','docs/ST-T2-CLASSIC.md','docs/ST-VEHICLES.md','docs/KOTH-ROTATION.md','docs/FINAL-EXPANSION.md','tools/unreal_imports/README.md','tools/unreal_imports/live-bots.json','tools/unreal_imports/as-validation.json','tools/unreal_imports/assets.json','tools/unreal_imports/as-assets.json','tools/unreal_imports/as-live-bots.json','tools/final_expansion/cache-selection.json','tools/arena_imports/validation.json','tools/expansions/validation.json','tools/expansions/cache_validation.json','tools/expansions/runtime_art.json','tools/t2_vehicles/validation.json']:
  add(path)
 generated['maps/FinalExpansion/catalog.json']=(json.dumps(maps,indent=2)+'\n').encode()
 generated['maps/FinalExpansion/README.md']=(ROOT/'docs/FINAL-EXPANSION.md').read_bytes()
 files=[{'path':p,'size':(ROOT/p).stat().st_size,'sha256':sha(ROOT/p)} for p in sorted(paths)]
 files += [{'path':p,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()} for p,data in sorted(generated.items())]
 manifest={'schema':1,'release':VERSION,'minimum_game_version':VERSION,'status':'final; necessary fixes only','maps':maps,'base_maps_referenced':[r['id'] for r in old],'rotations':rotations,'excluded_ids':sorted(banned),'files':sorted(files,key=lambda r:r['path'])}
 return manifest,generated

def validate_assets():
 for file in ['tools/arena_imports/validation.json','tools/unreal_imports/as-validation.json']:
  assert not read(file)['failures'],file
 for file in ['tools/unreal_imports/assets.json','tools/unreal_imports/as-assets.json']:
  for row in read(file):
   assert not row['failures'] and row['baked_faces']>0,row['id']
   assert sha(ROOT/'maps'/(row['id']+'.bsp'))==row['bsp_sha256'],row['id']
   for codec in row['codecs']:assert sha(ROOT/codec['path'].removeprefix('res://'))==codec['sha256'],row['id']
 for row in read('tools/arena_imports/validation.json')['results']:
  for codec in row['codecs']:assert sha(ROOT/codec['path'].removeprefix('res://'))==codec['sha256'],row['id']
 for row in read('tools/expansions/validation.json')['maps']:
  assert not row['failures'],row['id']
  for a in row['assets']:assert sha(ROOT/a['path'])==a['sha256'],a['path']

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--freeze',action='store_true');p.add_argument('--necessary-fix');p.add_argument('--verify-only',action='store_true');args=p.parse_args()
 validate_assets();manifest,generated=plan();lock=HERE/'manifest.json'
 if lock.exists():
  previous=json.loads(lock.read_text())
  if manifest!=previous:
   assert args.necessary_fix,'Frozen expansion changed; supply --necessary-fix with the actual repair reason'
   assert {r['id'] for r in manifest['maps']}=={r['id'] for r in previous['maps']},'Final map selection cannot grow'
   history=HERE/'fixes.json';fixes=json.loads(history.read_text()) if history.exists() else []
   fixes.append({'reason':args.necessary_fix,'previous_manifest_sha256':sha(lock)});history.write_text(json.dumps(fixes,indent=2)+'\n')
   lock.write_text(json.dumps(manifest,indent=2)+'\n')
 else:
  assert args.freeze,'Initial package requires --freeze';lock.write_text(json.dumps(manifest,indent=2)+'\n')
 out=ROOT.parent/'Builds'/NAME;out.parent.mkdir(exist_ok=True)
 if not args.verify_only:
  temporary=out.with_suffix('.tmp')
  with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for row in manifest['files']:
    path=row['path']
    if path in generated:z.writestr(path,generated[path])
    else:z.write(ROOT/path,path)
   z.writestr('maps/FinalExpansion/manifest.json',lock.read_bytes())
  temporary.replace(out)
 with zipfile.ZipFile(out) as z:
  expected={r['path'] for r in manifest['files']}|{'maps/FinalExpansion/manifest.json'}
  assert set(z.namelist())==expected and len(z.namelist())==len(expected)
  for row in manifest['files']:
   with z.open(row['path']) as f:assert hashlib.file_digest(f,'sha256').hexdigest()==row['sha256'],row['path']
  assert z.read('maps/FinalExpansion/manifest.json')==lock.read_bytes()
 assert out.stat().st_size<2_000_000_000,'GitHub release single-asset limit'
 report={'file':NAME,'release':VERSION,'bytes':out.stat().st_size,'sha256':sha(out),'manifest_sha256':sha(lock),'maps':len(manifest['maps']),'maplists':{k:len(v) for k,v in manifest['rotations'].items()},'failures':[]}
 (HERE/'package.json').write_text(json.dumps(report,indent=2)+'\n');out.with_suffix('.zip.sha256').write_text(report['sha256']+'  '+out.name+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
