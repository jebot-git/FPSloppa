"""Update authored TB stations/vantages without changing geometry, light or BSPX data."""
from pathlib import Path
import hashlib, json, re, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from titanball.build import City
from assault_layout_tests.update_pickups import repack, unpack
from skyboxes.audit import BSP

def main():
 out=ROOT/'test-results/titanball';out.mkdir(exist_ok=True)
 city=City();city.gameplay_markers();markers=city.entities
 bsp=ROOT/'maps/tb_ashfall.bsp';old=bsp.read_bytes()
 backup=out/'before-stations-r3.bsp'
 if not backup.exists():backup.write_bytes(old)
 kinds={'info_tb_resupply','info_tb_vantage'}
 entities=[e for e in BSP(bsp).entities if e.get('classname') not in kinds]+markers
 def serialize(rows):return '\n'.join('{\n'+'\n'.join(f'"{k}" "{v}"' for k,v in e.items())+'\n}' for e in rows)+'\n'
 new=repack(old,(serialize(entities)+'\0').encode('latin1'))
 old_lumps,old_extra=unpack(backup.read_bytes());new_lumps,new_extra=unpack(new)
 assert old_lumps[1:]==new_lumps[1:] and old_extra==new_extra
 source=ROOT/'maps/Ashfall/tb_ashfall.map';text=source.read_text()
 text=re.sub(r'\{\s*"classname" "info_tb_(?:resupply|vantage)"[^{}]*\}\s*','',text)
 source.write_text(text.rstrip()+'\n'+serialize(markers));bsp.write_bytes(new)
 digest=hashlib.sha256(new).hexdigest()
 for file in ['deathmatch/maps/manifest.json','maps/Ashfall/manifest.json','maps/Ashfall/texture-audit.json']:
  p=ROOT/file;data=json.loads(p.read_text())
  if isinstance(data,list):
   for row in data:
    if row.get('id')=='tb_ashfall':row.update(sha256=digest,size=len(new))
  elif 'textures' in data and 'bsp_sha256' in data:data['bsp_sha256']=digest
  else:data.update(sha256=digest,bytes=len(new),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),universal_resupply=6,tactical_vantages=12)
  p.write_text(json.dumps(data,indent=2)+'\n')
 sky=ROOT/'deathmatch/maps/skies/SOURCES.json';data=json.loads(sky.read_text());data['map_sources'][digest]='tb_ashfall';sky.write_text(json.dumps(data,indent=2)+'\n')
 (out/'markers-r3.json').write_text(json.dumps({'sha256':digest,'geometry_lighting_unchanged':True,'markers':markers},indent=2)+'\n')
 print(digest,'6 stations, 12 vantages; geometry/light/BSPX identical')
if __name__=='__main__':main()
