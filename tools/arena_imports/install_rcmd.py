"""Stage successfully rebuilt RCMD brush maps for runtime validation."""
from pathlib import Path
import json,sys,zipfile,shutil
from build import ROOT,HERE,adapt,sha
catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());reports=json.loads((HERE/'conversions.json').read_text());sources=json.loads((HERE/'sources.json').read_text())
for row in json.loads((HERE/'rcmd-attempts.json').read_text()):
 if row['collection']!='rcmd_quake1':continue # Distribution policy: native Quake RCMD maps only.
 if row['status']!='compiled':continue
 id=row['id'];source=ROOT/row['compiled'];raw=source.read_bytes();title=id.removeprefix('dm_rcmd_');data,changes=adapt(raw,None,title+' (RCMD)' )
 (ROOT/'maps'/(id+'.bsp')).write_bytes(data);folder=ROOT/'maps/ArenaImports'/id;folder.mkdir(parents=True,exist_ok=True)
 for f in source.parent.glob('*'):
  if f.suffix in ['.map','.wad']:shutil.copy2(f,folder/f.name)
 archive=next(r for r in sources if r['sha256']==row['archive_sha256']);z=zipfile.ZipFile(HERE/'local'/archive['archive'])
 for n in z.namelist():
  if n.lower().endswith(('.txt','.md','.license')):
   f=folder/'original'/n;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(z.read(n))
 for f in (ROOT/'maps').glob('LibreQuake-*.txt'):shutil.copy2(f,folder/f.name)
 record={**row,**changes,'title':title,'author':'spirit','sha256':sha(data),'bytes':len(data),'lighting_rebaked':True,'textures':'LibreQuake material substitutions; source texture names mapped in rcmd-attempts.json','status':'candidate'}
 (folder/'conversion.json').write_text(json.dumps(record,indent=2)+'\n');reports=[r for r in reports if r['id']!=id]+[record]
 catalog=[r for r in catalog if r['id']!=id]+[{'id':id,'title':title+' (RCMD)','author':'spirit','modes':['dm','tdm','ig','if','ft','cc'],'path':'res://maps/'+id+'.bsp','scene':'res://maps/cache/'+id+'.scn','sha256':sha(data),'distribution':'local','recommended_players':[2,8]}]
(ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(catalog,indent=2)+'\n');(HERE/'conversions.json').write_text(json.dumps(reports,indent=2)+'\n');print('Arena candidates',len(reports))
