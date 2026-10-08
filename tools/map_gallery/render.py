#!/usr/bin/env python3
"""Render the 22 Classic ST adaptations and 14 retained converted DE maps."""
import argparse,json,math,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/map-gallery'
def view(name,eye,target):return {'name':name,'eye':eye,'target':target}
def add(p,q):return [a+b for a,b in zip(p,q)]
def plans():
 rows=[]
 for source in json.loads((ROOT/'tools/t2_classic/sources.json').read_text())['maps']:
  if source['existing']:continue
  key=source['id'];p=json.loads((ROOT/'maps/T2Classic'/key/'probes.json').read_text());views=[]
  for team in range(2):
   authored=p['views'][team];views.append(view(f'04-base-{team}',authored['eye'],authored['look']))
   f=p['flags'][team]['position']
   for label,direction in [('north',[0,0,-1]),('east',[1,0,0]),('south',[0,0,1]),('west',[-1,0,0])]:
    eye=add(f,[0,1.6,0]);views.append(view(f'05-flag-{team}-{label}',eye,add(eye,direction)))
   spawn=next(r['position'] for r in p['spawns'] if r['team']==team);eye=add(spawn,[0,1.6,0]);views.append(view(f'06-spawn-{team}',eye,add(f,[0,1.6,0])))
  row={'id':key,'title':source['title'],'mode':'st','views':views,**p['boundary']};rows.append(row)
 for source in json.loads((ROOT/'tools/varq_de/results.json').read_text())['maps']:
  if source['status']!='validated':continue
  key=Path(source['installed']).stem;raw=(ROOT/source['installed']).read_bytes();offset,size=struct.unpack_from('<ii',raw,4+14*8);bounds=struct.unpack_from('<6f',raw,offset)
  def game(p):return [-p[1]/32,p[2]/32,-p[0]/32]
  a=game(bounds[:3]);b=game(bounds[3:]);layout=json.loads((ROOT/'tools/varq_de/local'/source['name']/'converted'/(source['name']+'_fps.conversion.json')).read_text())['layout'];views=[]
  for team in range(2):
   eye=add(layout['starts'][team][0],[0,1.6,0]);yaw=layout['start_yaws'][team][0];views.append(view(f'04-spawn-{team}',eye,add(eye,[-math.sin(yaw),0,-math.cos(yaw)])))
  for site in range(2):
   for label,direction in [('north',[0,0,-1]),('east',[1,0,0]),('south',[0,0,1]),('west',[-1,0,0])]:
    eye=add(layout['sites'][site],[0,1.6,0]);views.append(view(f'05-site-{site}-{label}',eye,add(eye,direction)))
  rows.append({'id':key,'title':source['name'],'mode':'de','min':[min(x,y) for x,y in zip(a,b)],'max':[max(x,y) for x,y in zip(a,b)],'views':views})
 return rows

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--map');parser.add_argument('--mode',choices=['st','de']);parser.add_argument('--resume',action='store_true');args=parser.parse_args()
 rows=plans();OUT.mkdir(parents=True,exist_ok=True);(OUT/'plan.json').write_text(json.dumps(rows,indent=2)+'\n')
 failed=[]
 for row in rows:
  if args.map and row['id']!=args.map:continue
  if args.mode and row['mode']!=args.mode:continue
  folder=OUT/row['id'];folder.mkdir(exist_ok=True)
  if args.resume and (folder/'renders.json').exists():
   saved=json.loads((folder/'renders.json').read_text())
   if len(saved['captures'])==len(row['views'])+3 and all(c['width']==1920 and c['height']==1080 and (folder/(c['name']+'.png')).is_file() for c in saved['captures']) and 'ERROR:' not in (folder/'render.log').read_text():continue
  with (folder/'render.log').open('w') as log:
   try:code=subprocess.run([str(ROOT/'run.sh'),'--xr-mode','off','--audio-driver','Dummy','--rendering-method','mobile','--script','tools/map_gallery/render.gd','--',row['id'],'--no-bots'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=240).returncode
   except subprocess.TimeoutExpired:code=124
  if code or 'MAP_GALLERY_DONE' not in (folder/'render.log').read_text() or 'ERROR:' in (folder/'render.log').read_text():failed.append(row['id'])
  print(row['id'],code,flush=True)
 print('Failed:',failed);raise SystemExit(bool(failed))
if __name__=='__main__':main()
