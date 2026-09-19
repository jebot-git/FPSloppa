"""Add three authored hill sites to existing KOTH sources and fully compile/light them."""
from pathlib import Path
import argparse,concurrent.futures,hashlib,json,math,re,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/koth'))
from build import Shape,blocks,fields,setkey,entity,point
OUT=ROOT/'test-results/koth-rotation'
# Godot floor coordinates, surveyed against existing collision and routes.
SITES={
 'koth_solstice':[(26,.3125,4.75),(32.75,0,-44.375)],
 'koth_torture':[(-5.125,0,-7.125),(25.5,5,23.875)],
 'koth_hyperborea':[(-47.5,1,60.25),(-5,0,63.25)],
 'koth_alichar':[(-32.5,6,7.625),(31.375,6,8.75)],
}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--map',action='append');parser.add_argument('--compiler',type=Path,default=Path('/tmp/fpsloppa-ericw/ericw-tools-v0.18.1-Linux/bin'));args=parser.parse_args()
 OUT.mkdir(exist_ok=True,parents=True);(OUT/'baseline').mkdir(exist_ok=True)
 catalog_path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(catalog_path.read_text());recipes=json.loads((ROOT/'tools/koth/recipes.json').read_text());jobs=[]
 for recipe in recipes:
  name=recipe['id']
  if args.map and name not in args.map:continue
  source=ROOT/'maps/KOTH/source'/f'{name}.map';baseline=OUT/'baseline'/source.name
  if not baseline.exists():shutil.copyfile(source,baseline)
  text=source.read_text();ents=blocks(text);world=ents.pop(0)
  marker='// Rotating-hill scoring decks and four-way approaches.'
  if marker in world:world=world[:world.index(marker)].rstrip()+'\n}'
  shape=Shape(name,recipe['title']);row=next(r for r in catalog if r['id']==name)
  mapping=json.loads((ROOT/'maps/KOTH/BUILD.json').read_text())['maps'];mapping=next(r for r in mapping if r['id']==name)['texture_mapping']
  floor=mapping.get(recipe['floor'],recipe['floor']);trim=mapping.get(recipe['trim'],recipe['trim'])
  old=next(e for e in ents if fields(e).get('classname')=='info_koth_control');origin=list(map(float,fields(old)['origin'].split()));hills=[[-origin[1]/32,origin[2]/32-.7,-origin[0]/32]]
  if name=='koth_alichar':hills[0]=[0,18.8,-6.75]
  for x,y,z in SITES[name]:
   cx,cy=-z*32,-x*32;top=math.ceil(y*32)+4
   # A marked, level 6.5 m deck, with shallow ramps on all four sides.
   shape.box((cx-104,cy-104,top-20),(cx+104,cy+104,top-2),trim)
   shape.box((cx-100,cy-100,top-2),(cx+100,cy+100,top),floor)
   for axis in range(4):
    ramp=Shape('','');ramp.ramp_x(100,128,-64,64,top,top-16,floor)
    angle=axis*math.pi/2
    def rotate(m):
     a,b,c=map(float,m[1].split());return '( '+point([round(cx+a*math.cos(angle)-b*math.sin(angle),5),round(cy+a*math.sin(angle)+b*math.cos(angle),5),c])+' )'
    shape.brushes += [re.sub(r'\(\s*([^()]+)\)',rotate,b) for b in ramp.brushes]
   hills.append([x,top/32+.05,z])
  world=world.rstrip()[:-1]+'\n// Rotating-hill scoring decks and four-way approaches.\n'+'\n'.join(shape.brushes)+'\n}'
  world=re.sub(r'^"_fpsloppa_light_response"[^\n]*\n','',world,flags=re.M)
  world=setkey(world,'_fpsloppa_light_response','quake')
  result=[world];removed=[]
  for ent in ents:
   data=fields(ent);kind=data.get('classname','')
   if kind=='info_koth_control' or data.get('_koth_site_light')=='1':continue
   if 'origin' in data:
    p=list(map(float,data['origin'].split()));position=(-p[1]/32,p[2]/32-.7,-p[0]/32)
    if any(math.hypot(position[0]-h[0],position[2]-h[2])<4 and abs(position[1]-h[1])<2 for h in hills[1:]):
     if kind.startswith(('item_','weapon_','info_player_')):removed.append(data);continue
   result.append(ent)
  for index,hill in enumerate(hills):
   result.append(entity({'classname':'info_koth_control','hill_index':str(index),'origin':point([-hill[2]*32,-hill[0]*32,(hill[1]+.7)*32])}))
   result.append(entity({'classname':'light','_koth_site_light':'1','origin':point([-hill[2]*32,-hill[0]*32,(hill[1]+2.25)*32]),'light':'250','_color':'1 0.9 0.75'}))
  source.write_text('// LibreQuake derivative; see ../README.md and licence files.\n'+'\n'.join(result)+'\n')
  jobs.append({'id':name,'hills':hills,'source_sha256':sha(source),'added_brushes':len(shape.brushes),'removed_near_hill_entities':removed})
 def compile(job):
  name=job['id'];folder=OUT/name;folder.mkdir(exist_ok=True);bsp=folder/(name+'.bsp');source=ROOT/'maps/KOTH/source'/(name+'.map');start=time.monotonic()
  commands=[('qbsp',['-nodetail',str(source),str(bsp)]),('vis',['-threads','16',*(['-fast'] if name=='koth_hyperborea' else []),str(bsp)]),('light',['-novisapprox','-threads','4','-extra4','-bspxlit','-bounce','1','-bouncecolorscale','0.25','-sunlight_penumbra','4','-dirt','1','-dirtdepth','32','-dirtscale','0.5','-minlight_dirt','1',str(bsp)])]
  for executable,flags in commands:
   print(name,executable,flush=True)
   with (folder/(executable+'.log')).open('w') as log:subprocess.run([str(args.compiler/executable),*flags],cwd=source.parent,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
  job.update(sha256=sha(bsp),seconds=round(time.monotonic()-start,2),size=bsp.stat().st_size,commands=commands)
  return job
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:jobs=list(pool.map(compile,jobs))
 sky_path=ROOT/'deathmatch/maps/skies/SOURCES.json';sky=json.loads(sky_path.read_text())
 for job in jobs:
  name=job['id'];row=next(r for r in catalog if r['id']==name);shutil.copyfile(OUT/name/(name+'.bsp'),ROOT/'maps'/(name+'.bsp'))
  lit=OUT/name/(name+'.lit')
  if lit.exists():shutil.copyfile(lit,ROOT/'maps'/lit.name)
  row.update(sha256=job['sha256'],size=job['size']);row['objectives'].update(hill=job['hills'][0],hills=job['hills'])
  sky['map_sources'][job['sha256']]=name
 catalog_path.write_text(json.dumps(catalog,indent=2)+'\n');sky_path.write_text(json.dumps(sky,indent=2)+'\n')
 receipt={'hill_seconds':30,'compiler':str(args.compiler),'maps':jobs}
 if args.map and (OUT/'build.json').exists():
  previous=json.loads((OUT/'build.json').read_text())['maps']
  receipt['maps']=[job for job in previous if job['id'] not in {row['id'] for row in jobs}]+jobs
 (OUT/'build.json').write_text(json.dumps(receipt,indent=2)+'\n');(ROOT/'maps/KOTH/ROTATION.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print('ROTATING_KOTH_BUILD_COMPLETE',flush=True)
if __name__=='__main__':main()
