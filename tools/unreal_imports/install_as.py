"""Install only hash-bound AS builds whose full runtime route checks pass."""
from pathlib import Path
import json,hashlib,shutil,sys
from attempt import members,LOCAL
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
rows=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());installed=json.loads((HERE/'as-installed.json').read_text()) if len(sys.argv)>1 and (HERE/'as-installed.json').exists() else []
for folder in sorted((HERE/'local/candidates').glob('as_ut_*')):
 if len(sys.argv)>1 and folder.name.removeprefix('as_ut_') not in sys.argv[1:]:continue
 name=folder.name;path=folder/(name+'.bsp');receipt=json.loads((folder/'runtime-validation.json').read_text());conversion=json.loads((folder/'conversion.json').read_text());sha=hashlib.sha256(path.read_bytes()).hexdigest()
 assert receipt['bsp_sha256']==sha,(name,'stale runtime validation')
 assert not receipt['failures'] and not conversion['blockers'],(name,receipt['failures'],conversion['blockers'])
 assert receipt['baked_faces']>0 and receipt['invalid_light_faces']==0,name
 assert receipt['routes']>0,name # Mandatory attack sequence and at least one defense route per start are gated above.
 dest=ROOT/'maps/UnrealImports'/name;dest.mkdir(parents=True,exist_ok=True)
 for file in [path.with_suffix('.map'),folder/'textures.wad',folder/'conversion.json',folder/'runtime-validation.json']:shutil.copy2(file,dest/file.name)
 shutil.copy2(ROOT/'tools/makkon/Makkon_License.txt',dest/'Makkon_License.txt')
 for file in (ROOT/'maps').glob('LibreQuake-*.txt'):shutil.copy2(file,dest/file.name)
 shutil.copy2(path,ROOT/'maps'/path.name)
 shutil.copy2(folder/'navigation.res',ROOT/'maps/navigation'/(name+'.res'))
 source=conversion['source']
 actors=json.loads((HERE/'local/converted'/source['archive_sha1'][:12]/'actors.json').read_text())
 info=next(a['properties'] for a in actors if a['class_path'].endswith('LevelInfo'))
 author=info.get('Author','Unknown original ChaosUT map author')
 files=members((LOCAL/'archives'/source['archive_sha1']).read_bytes())
 for member,data in files.items():
  if Path(member).suffix.lower() not in ['.txt','.md','.htm','.html']:continue
  relative=Path(member.replace('\\','/'))
  if relative.is_absolute() or '..' in relative.parts:continue
  notice=dest/'original'/relative;notice.parent.mkdir(parents=True,exist_ok=True);notice.write_bytes(data)
 row={'id':name,'title':source['name']+' (UT AS)','author':author,'modes':['as'],'path':'res://maps/'+path.name,'scene':'res://maps/cache/'+name+'.scn','sha256':sha,'distribution':'local','recommended_players':[2,max(8,min(16,receipt['spawns']))]}
 rows=[r for r in rows if r['id']!=name]+[row];installed=[r for r in installed if r['id']!=name];installed.append({**row,'runtime':receipt,'conversion':conversion})
(ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
p=ROOT/'maps/as_maplist.txt';names=p.read_text().splitlines();names+=[r['id'] for r in installed if r['id'] not in names];p.write_text('\n'.join(names)+'\n')
(ROOT/'maps/ut_as_maplist.txt').write_text('\n'.join(r['id'] for r in installed)+'\n')
(HERE/'as-installed.json').write_text(json.dumps(installed,indent=2)+'\n');print('Installed',len(installed),'validated AS maps')

(HERE/"as-builds.json").write_text(json.dumps([r["conversion"] for r in installed],indent=2)+"\n")
