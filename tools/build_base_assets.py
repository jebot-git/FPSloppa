"""Build the internal offline asset installer; not a separate release download."""
from pathlib import Path
import argparse,hashlib,json,zipfile
from map_distribution import tf_files, distributable, check_selection
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
version=(ROOT/'VERSION').read_text().strip()
texture_version=json.loads((ROOT/'deathmatch/maps/texture_replacements/manifest.json').read_text())['version']
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);args=parser.parse_args()
out=args.output or ROOT.parent/'Builds'/f'FPSloppa-{version}-Base-Assets.zip';out.parent.mkdir(parents=True,exist_ok=True)
files=[]
# Select known base assets only. Never package players' downloaded/imported files.
paths=[]
for row in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()):
 if row.get('distribution','base')!='base':continue
 paths.extend([row['path'].removeprefix('res://'),row['scene'].removeprefix('res://'),'maps/navigation/'+row['id']+'.res'])
 cache=row['scene'].removeprefix('res://').removesuffix('.scn')+'-lightmap1.scn'
 if (ROOT/cache).is_file():paths.append(cache)
 # Missing-texture maps use this exact dictionary-versioned cache at runtime.
 # Include only the active version, not arbitrary older cache files.
 texture_cache=cache.removesuffix('.scn')+'-textures-'+str(texture_version)+'.scn'
 if (ROOT/texture_cache).is_file():paths.append(texture_cache)
 for active in [cache,texture_cache]:
  for codec in ['bc7','astc4']:
   candidate=active.removesuffix('.scn')+'-'+codec+'.scn'
   if (ROOT/candidate).is_file():paths.append(candidate)
 lit='maps/'+row['id']+'.lit'
 if (ROOT/lit).is_file():paths.append(lit)
for row in json.loads((ROOT/'deathmatch/avatars/models/manifest.json').read_text()):paths.append(row['path'].removeprefix('res://'))
paths.extend('maps/'+mode+'_maplist.txt' for mode in ['dm','tdm','ctf','koth','ig','ft','if','cc','tf','tb','as'] if (ROOT/'maps'/(mode+'_maplist.txt')).is_file())
# Validate TF bake/navigation lineage without shipping development receipts.
tf_files()
# Runtime assets retain notices and provenance. Editable map/WAD sources live
# in the separately published source archive, not every installed game.
for folder in ['Ashfall','CC','CTFStudies','Frigate','HiSlop','KOTH','Quake','Makkon','Pressureworks','VesperAbbey']:
 for p in (ROOT/'maps'/folder).rglob('*'):
  name=p.name.lower()
  if p.is_file() and (p.suffix.lower()=='.txt' and any(token in name for token in ['license','licence','copying','credits','cc0','gnu']) or name in {'texture-sources.json','sources.md','sources.json'}):
   paths.append(str(p.relative_to(ROOT)))
paths.extend(str(p.relative_to(ROOT)) for p in (ROOT/'maps').glob('LibreQuake-*.txt'))
paths.extend(['maps/README.txt','vrm/README.txt'])
paths=[p for p in paths if distributable(p)]
assert all(Path(p).parts[0] in {'maps','vrm'} for p in paths)
assert all(Path(p).suffix.lower() not in {'.log','.mp4','.png','.map','.wad'} for p in paths)
check_selection(paths)
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for path in sorted(set(paths)):
  data=(ROOT/path).read_bytes();archive.writestr(path,data);files.append({'path':path,'size':len(data),'sha256':sha(data)})
manifest={'version':version,'delivery':'bundled','sha256':sha(out.read_bytes()),'files':files}
(ROOT/'deathmatch/assets/base_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out,out.stat().st_size,manifest['sha256'])
