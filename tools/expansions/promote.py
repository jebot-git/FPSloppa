#!/usr/bin/env python3
"""Promote the verified DE/ST expansion maps into the base game catalog."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads((ROOT/p).read_text())
def main():
 retired=set(read('deathmatch/maps/retired.json'))
 catalog=[r for r in read('deathmatch/maps/manifest.json') if r['id'] not in retired];rows=[]
 for r in catalog:
  if r['id'].startswith('ctf_t2_'):
   r['distribution']='base';r.pop('experimental',None);rows.append({'id':r['id'],'mode':'st'})
 for source in read('tools/varq_de/results.json')['maps']:
  if source['status']!='validated' or Path(source.get('installed','')).stem in retired:continue
  path=ROOT/source['installed'];key=path.stem;sha=hashlib.sha256(path.read_bytes()).hexdigest();assert sha==source['sha256']
  catalog=[r for r in catalog if r['id']!=key]
  catalog.append({'id':key,'title':source['name'][3:].replace('_',' ').title()+' · DE','path':'res://'+source['installed'],'scene':'res://maps/cache/'+key+'.scn','sha256':sha,'size':path.stat().st_size,'modes':['de'],'distribution':'base'})
  rows.append({'id':key,'mode':'de'})
 assert len(rows)==36
 (ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(catalog,indent=2)+'\n')
 (ROOT/'tools/expansions/catalog.json').write_text(json.dumps(rows,indent=2)+'\n')
 rotation=ROOT/'maps/de_maplist.txt';base=[s for s in rotation.read_text().splitlines() if s and not s.startswith('de_varq_')]
 rotation.write_text('\n'.join(base+[r['id'] for r in rows if r['mode']=='de'])+'\n')
 notices=ROOT/'maps/ExpansionNotices';notices.mkdir(exist_ok=True)
 (notices/'CREDITS.txt').write_text('DE and ST base-game expansions\n\nDE maps and texture art retain their original authorship. Source downloads and exact texture donor hashes are documented in sources.json and texture-sources.json. Original archive notices are retained in the de-* subdirectories.\n\nST Classic maps adapt Tribes 2 mission/terrain/interior layouts from the pinned t2-mapper repository. Native ST vehicle geometry and bronze/gunmetal atlas are independently authored. Source mission provenance is recorded in st-sources.json.\n')
 for file,target in [('tools/varq_de/sources.json','sources.json'),('tools/varq_de/texture_validation.json','texture-sources.json'),('tools/t2_classic/sources.json','st-sources.json')]:shutil.copyfile(ROOT/file,notices/target)
 # Include donor notices too: recovered art may originate in a withheld map.
 for directory in (ROOT/'tools/varq_de/local').iterdir():
  for source in (directory/'notices').glob('*.txt'):
   target=notices/directory.name/source.name;target.parent.mkdir(exist_ok=True);shutil.copyfile(source,target)
 print('Promoted',len(rows),'maps; DE rotation',len(base)+14)
if __name__=='__main__':main()
