"""Package external maps and VRMs; pin their download for standalone installs."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
version=(ROOT/'VERSION').read_text().strip()
out=ROOT.parent/'Builds'/f'FPSloppa-{version}-Base-Assets.zip';out.parent.mkdir(exist_ok=True)
files=[]
# Select known base assets only. Never package players' downloaded/imported files.
paths=[]
for row in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()):
 paths.extend([row['path'].removeprefix('res://'),row['scene'].removeprefix('res://'),'maps/navigation/'+row['id']+'.res'])
 lit='maps/'+row['id']+'.lit'
 if (ROOT/lit).is_file():paths.append(lit)
for row in json.loads((ROOT/'deathmatch/avatars/models/manifest.json').read_text()):paths.append(row['path'].removeprefix('res://'))
paths.extend('maps/'+mode+'_maplist.txt' for mode in ['dm','tdm','ctf','koth','ig','ft','cc','tf'] if (ROOT/'maps'/(mode+'_maplist.txt')).is_file())
paths.extend(str(p.relative_to(ROOT)) for p in (ROOT/'maps').glob('LibreQuake-*.txt'))
paths.extend(['maps/README.txt','vrm/README.txt'])
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for path in sorted(set(paths)):
  data=(ROOT/path).read_bytes();archive.writestr(path,data);files.append({'path':path,'size':len(data),'sha256':sha(data)})
manifest={'version':version,'url':f'https://github.com/jebot-git/FPSloppa/releases/download/{version}/{out.name}','sha256':sha(out.read_bytes()),'files':files}
(ROOT/'deathmatch/assets/base_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out,out.stat().st_size,manifest['sha256'])
