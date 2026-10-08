"""Install rebuilt emissive lighting while retaining validated runtime entities."""
from pathlib import Path
import json
from build import ROOT,HERE,unpack,pack,parse_entities,sha
rows=json.loads((HERE/'conversions.json').read_text());catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());attempts={r['id']:r for r in json.loads((HERE/'rcmd-attempts.json').read_text())}
for row in rows:
 if row.get('status')!='candidate':continue
 name=row['id'];source=attempts[name];assert source['status']=='compiled'
 path=ROOT/'maps'/(name+'.bsp');old_entities=parse_entities(unpack(path.read_bytes())[0][0]);raw=(ROOT/source['compiled']).read_bytes();parts,extra=unpack(raw);new_entities=parse_entities(parts[0])
 entities=[e for e in old_entities if not e.get('classname','').startswith('light')]
 entities[0].update(_minlight='24',_bounce='1')
 entities += [e for e in new_entities if e.get('classname','').startswith('light')]
 parts[0]=('\n'.join('{\n'+'\n'.join('"'+k+'" "'+v.replace('"',"'")+'"' for k,v in e.items())+'\n}' for e in entities)+'\n\0').encode('latin1')
 data=pack(parts,extra,raw[:4]);path.write_bytes(data)
 row.update(sha256=sha(data),bytes=len(data),surface_emitters=source.get('surface_emitters',{}),texture_mapping=source['texture_mapping'],texture_sources=source.get('texture_sources',{}),unique_colour_materials=source.get('unique_colour_materials'),lighting_rebaked=True)
 folder=ROOT/'maps/ArenaImports'/name
 (folder/'conversion.json').write_text(json.dumps(row,indent=2)+'\n')
 for suffix in ['.map']:(folder/(name+suffix)).write_bytes((ROOT/source['compiled']).with_suffix(suffix).read_bytes())
 (folder/'arena.wad').write_bytes((ROOT/source['compiled']).with_name('arena.wad').read_bytes())
 for entry in catalog:
  if entry['id']==name:entry['sha256']=row['sha256']
 print(name,'emitter materials',len(row['surface_emitters']),flush=True)
(HERE/'conversions.json').write_text(json.dumps(rows,indent=2)+'\n');(ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(catalog,indent=2)+'\n')
