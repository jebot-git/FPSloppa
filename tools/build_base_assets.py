"""Build the internal offline asset installer; not a separate release download."""
from pathlib import Path
import argparse,hashlib,json,zipfile,subprocess,os,shutil
from map_distribution import tf_files, distributable, check_selection, rotation
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
version=(ROOT/'VERSION').read_text().strip()
texture_version=json.loads((ROOT/'deathmatch/maps/texture_replacements/manifest.json').read_text())['version']
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);args=parser.parse_args()
out=args.output or ROOT.parent/'Builds'/f'FPSloppa-{version}-Base-Assets.zip';out.parent.mkdir(parents=True,exist_ok=True)
files=[]
# Package only the cache variants selected by the current runtime. Plain scene
# aliases and inactive texture-dictionary aliases needlessly duplicated hundreds
# of megabytes in every download and could exceed GitHub's asset-size limit.
godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
if not godot:raise SystemExit('Set GODOT_BIN or install Godot on PATH')
subprocess.run([godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tools/audit_release_map_caches.gd'],check=True)
audit=json.loads((ROOT/'test-results'/('release-'+version)/'map-caches.json').read_text())
assert not audit['failures'],audit['failures']
active_caches={r['path'].removeprefix('res://') for r in audit['records']}
base_ids={r['id'] for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()) if r.get('distribution','base')=='base'}
maplists={'maps/'+mode+'_maplist.txt':'\n'.join(id for id in rotation(mode) if id in base_ids)+'\n' for mode in ['dm','tdm','ctf','koth','ig','ft','if','cc','tf','tb','as','de','st']}
assert all(text.strip() for text in maplists.values()),'Empty bundled rotation'
# Select known base assets only. Never package players' downloaded/imported files.
paths=[]
for row in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()):
 if row.get('distribution','base')!='base':continue
 paths.extend([row['path'].removeprefix('res://'),'maps/navigation/'+row['id']+'.res'])
 lit='maps/'+row['id']+'.lit'
 if (ROOT/lit).is_file():paths.append(lit)
paths.extend(sorted(active_caches))
for row in json.loads((ROOT/'deathmatch/avatars/models/manifest.json').read_text()):paths.append(row['path'].removeprefix('res://'))
paths.extend('maps/'+mode+'_maplist.txt' for mode in ['dm','tdm','ctf','koth','ig','ft','if','cc','tf','tb','as','de','st'] if (ROOT/'maps'/(mode+'_maplist.txt')).is_file())
# Validate TF bake/navigation lineage without shipping development receipts.
tf_files()
# Runtime assets retain notices and provenance. Editable map/WAD sources live
# in the separately published source archive, not every installed game.
for folder in ['Ashfall','Cindercoil','CC','CTFStudies','Frigate','HiSlop','KOTH','Quake','Makkon','Pressureworks','VesperAbbey','Dust2Rebuilt','ClassicDE','DEMaterials','Stonehenge','Raindance','Katabatic']:
 for p in (ROOT/'maps'/folder).rglob('*'):
  name=p.name.lower()
  if p.is_file() and (p.suffix.lower()=='.txt' and any(token in name for token in ['license','licence','copying','credits','cc0','gnu']) or name in {'texture-sources.json','sources.md','sources.json'}):
   paths.append(str(p.relative_to(ROOT)))
paths.extend(str(p.relative_to(ROOT)) for p in (ROOT/'maps').glob('LibreQuake-*.txt'))
paths.extend(str(p.relative_to(ROOT)) for p in (ROOT/'maps/ExpansionNotices').rglob('*') if p.is_file() and p.suffix in {'.txt','.json'})
paths.extend(['maps/README.txt','vrm/README.txt','vrm/SOURCES.json','maps/Dust2Rebuilt/README.md','maps/ClassicDE/README.md','maps/Cindercoil/README.md','maps/Cindercoil/layout.svg'])
paths=[p for p in paths if distributable(p)]
assert all(Path(p).parts[0] in {'maps','vrm'} for p in paths)
assert all(Path(p).suffix.lower() not in {'.log','.mp4','.png','.map','.wad'} for p in paths)
check_selection(paths)
# Base assets must be current; missing/stale expansion caches fail before writing a bundle.
from expansion_assets import verify
verify(ROOT,paths)
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for path in sorted(set(paths)):
  data=maplists[path].encode() if path in maplists else (ROOT/path).read_bytes();archive.writestr(path,data);files.append({'path':path,'size':len(data),'sha256':sha(data)})
manifest={'version':version,'delivery':'bundled','sha256':sha(out.read_bytes()),'maplists':maplists,'files':files}
(ROOT/'deathmatch/assets/base_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out,out.stat().st_size,manifest['sha256'])
