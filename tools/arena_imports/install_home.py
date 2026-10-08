"""Import the user's three local BSPs without changing the originals."""
from pathlib import Path
import json
from build import ROOT,HERE,adapt,sha,unpack,parse_entities
catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());reports=json.loads((HERE/'conversions.json').read_text())
for name in ['q1q3hektik','q1q3toxicity','q3dm6qwt']:
 source=Path.home()/(name+'.bsp');raw=source.read_bytes();id='dm_local_'+name;entities=parse_entities(unpack(raw)[0][0]);title=entities[0].get('message',name).replace('\n',' ')
 lit=source.with_suffix('.lit').read_bytes() if source.with_suffix('.lit').exists() else None
 data,changes=adapt(raw,lit,title+' (Arena conversion)');assert not changes['invalid_external_lit']
 (ROOT/'maps'/(id+'.bsp')).write_bytes(data);folder=ROOT/'maps/ArenaImports'/id;folder.mkdir(parents=True,exist_ok=True)
 row={'id':id,'title':title,'collection':'home','source_file':str(source),'source_sha256':sha(raw),'sha256':sha(data),'bytes':len(data),**changes};(folder/'conversion.json').write_text(json.dumps(row,indent=2)+'\n');reports=[r for r in reports if r['id']!=id]+[row]
 catalog=[r for r in catalog if r['id']!=id]+[{'id':id,'title':{'q1q3hektik':'Hektik','q1q3toxicity':'Toxicity','q3dm6qwt':'The Campgrounds'}[name]+' (Local)','modes':['dm','tdm','ig','if','ft','cc'],'path':'res://maps/'+id+'.bsp','scene':'res://maps/cache/'+id+'.scn','sha256':sha(data),'distribution':'local','recommended_players':[2,8]}]
 print(id,title,changes['source_spawns'],flush=True)
(ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(catalog,indent=2)+'\n');(HERE/'conversions.json').write_text(json.dumps(reports,indent=2)+'\n')
