"""Reproducible KOTH derivatives of LibreQuake v0.09-beta (BSD-3-Clause)."""
import sys,re,json,struct,hashlib,shutil,subprocess,concurrent.futures,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/quake_source'),str(ROOT/'tools/makkon')]
from generate_tf_maps import Arena
import importlib.util
spec=importlib.util.spec_from_file_location("quake_source_build",ROOT/"tools/quake_source/build.py");source_tools=importlib.util.module_from_spec(spec);spec.loader.exec_module(source_tools)
blocks,fields,setkey=source_tools.blocks,source_tools.fields,source_tools.setkey
import theme
OUT=ROOT/'maps/KOTH';LOCAL=ROOT/'tools/koth/local/dev';SCALE=1.5
class Shape(Arena):
 def face(self,points,texture):
  a,b,c=points;u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)];n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
  axis=max(range(3),key=lambda i:abs(n[i]));uv=['[ 0 1 0 0 ] [ 0 0 -1 0 ]','[ 1 0 0 0 ] [ 0 0 -1 0 ]','[ 1 0 0 0 ] [ 0 -1 0 0 ]'][axis]
  return ' '.join('( %g %g %g )'%p for p in reversed(points))+' '+texture+' '+uv+' 0 1 1'
def entity(d):return '{\n'+'\n'.join('"%s" "%s"'%(k,v) for k,v in d.items())+'\n}'
def point(p):return ' '.join('%g'%x for x in p)
def scaled(m):
 p=list(map(float,m[1].split()));return '( '+point([p[0]*SCALE,p[1]*SCALE,p[2]])+' )'
def main():
 rows=json.loads((ROOT/'tools/koth/recipes.json').read_text());alltiles={};spawn_overrides=json.loads((ROOT/'tools/koth/spawns.json').read_text());balance=json.loads((ROOT/'tools/koth/balance.json').read_text())
 for map_id,settings in balance.items():
  spawn_overrides[map_id]=[[-p[2]*32/SCALE,-p[0]*32/SCALE,(p[1]+.7)*32] for p in [entry['position'] for entry in settings['starts']]]
 for wad in sorted((LOCAL/'texture-wads').glob('*.wad')):alltiles.update(theme.wad_textures(wad.read_bytes()))
 donors,_=theme.makkon();cross=json.loads((ROOT/'tools/makkon/shared.json').read_text())['librequake'];used={};report=[]
 for row in rows:
  source=LOCAL/'maps/src/dm'/(row['source']+'.map');shutil.copy2(source,OUT/'original'/source.name)
  ents=blocks(source.read_text());world=ents.pop(0);a=Shape(row['id'],row['title']);cx,cy,base=row['center'];top=row['top']
  # One broad hold space; the actual score circle is smaller than the deck.
  a.box((cx-112,cy-112,base-32),(cx+112,cy+112,top-8),row['trim'])
  a.box((cx-112,cy-112,top-8),(cx+112,cy+112,top),row['floor'])
  # Hand-authored approach levels surveyed against the original BSP.
  heights={'lqdm1':[32,32,-32,96],'lqdm2':[-192,0,0,0],'lqdm3':[0,-64,48,-16],'lqdm8':[576,384,None,576]}[row['source']]
  for index,h in enumerate(heights):
   if h is None:continue
   ramp=Shape('','');sign=1 if index%2==0 else -1
   x0,x1,z0,z1=(112,256,top,h) if sign>0 else (-256,-112,h,top)
   ramp.ramp_x(x0,x1,-64,64,z0,z1,row['floor'])
   def place(m):
    x,y,z=map(float,m[1].split())
    # Rotate +X approach into +Y for the latter two ramps.
    if index>=2:x,y=-y,x
    return '( '+point([x+cx,y+cy,z])+' )'
   for brush in ramp.brushes:
    brush=re.sub(r'\(\s*([^()]+)\)',place,brush)
    if index>=2:
     def rotate_uv(m):
      x,y,z,w=map(float,m[1].split());return '[ '+point([-y,x,z,w])+' ]'
     brush=re.sub(r'\[\s*([^\[\]]+)\]',rotate_uv,brush)
    a.brushes.append(brush)
  # Low baffles outside the score circle interrupt cross-map firing lanes.
  for dx,dy in [(-92,-92),(92,92)]:
   a.box((cx+dx-18,cy+dy-18,top),(cx+dx+18,cy+dy+18,top+40),row['trim'])
  # Upstream Hyperborea/Alichar sources leak with ericw 0.18, even unchanged.
  # Seal their exterior void beyond all authored geometry; playable walls stay intact.
  if row['source'] in ['lqdm3','lqdm8']:
   points=[list(map(float,m)) for m in re.findall(r'\(\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\)',source.read_text())]
   x,y,z=[min(p[i] for p in points)-64 for i in range(3)];X,Y,Z=[max(p[i] for p in points)+64 for i in range(3)]
   for lo,hi in [((x-32,y-32,z-32),(X+32,Y+32,z)),((x-32,y-32,Z),(X+32,Y+32,Z+32)),((x-32,y-32,z),(x,Y+32,Z)),((X,y-32,z),(X+32,Y+32,Z)),((x,y-32,z),(X,y,Z)),((x,Y,z),(X,Y+32,Z))]:a.box(lo,hi,'sky_star')
  world=world.rstrip()[:-1]+'\n'+'\n'.join(a.brushes)+'\n}'
  for key,value in {'wad':'koth-used.wad','message':row['title'],'_fpsloppa_bake':'1','_fpsloppa_atlas':'2048','_minlight':'48'}.items():world=setkey(world,key,value)
  result=[world];removed=[];spawns=[]
  for ent in ents:
   f=fields(ent);kind=f.get('classname','');p=list(map(float,f.get('origin','0 0 0').split()))
   if row['id']=='koth_solstice' and kind=='weapon_supershotgun' and abs(p[0]-288)<1 and abs(p[1]+1216)<1:
    ent=setkey(ent,'origin',point([309.19744,-1246.52139,104.8112]))
   if kind.startswith('monster_') or kind in ['info_koth_control','info_intermission']:continue
   if kind=='trigger_push' and 'angles' in f:
    pitch,yaw,roll=map(float,f['angles'].split());r=math.radians(pitch)
    horizontal=math.cos(r)*SCALE;vertical=-math.sin(r)
    ent=setkey(ent,'angles',point([math.degrees(math.atan2(-vertical,horizontal)),yaw,roll]))
    ent=setkey(ent,'speed','%g'%(float(f.get('speed',1000))*math.hypot(horizontal,vertical)))
   near=((p[0]-cx)**2+(p[1]-cy)**2)**.5<200 and abs(p[2]-top)<160
   if near and (kind.startswith('item_') or kind.startswith('weapon_')):removed.append(kind);continue
   if kind in ['info_player_start','info_player_deathmatch']:
    if row['id'] in spawn_overrides:continue
    if near:continue
    spawns.append(p)
   result.append(ent)
  if row['id'] in spawn_overrides:
   spawns=spawn_overrides[row['id']]
   for i,p in enumerate(spawns):result.append(entity({'classname':'info_player_deathmatch','origin':point(p)}))
   result.append(entity({'classname':'info_player_start','origin':point(spawns[0])}))
  assert len(spawns)>=4
  result.append(entity({'classname':'info_koth_control','origin':point([cx,cy,top+24])}))
  # Spawn groups interleave by distance: neither team monopolises nearest starts.
  if row['id'] not in spawn_overrides:spawns.sort(key=lambda p:(p[0]-cx)**2+(p[1]-cy)**2+(p[2]-top)**2)
  for i,p in enumerate(spawns):result.append(entity({'classname':'info_player_team'+str(1+balance.get(row['id'],{}).get('teams',[0,1,1,0]*4)[i]),'origin':point(p)}))
  text='\n'.join(result)+'\n';text=re.sub(r'\(\s*([-\d.]+\s+[-\d.]+\s+[-\d.]+)\s*\)',scaled,text)
  def origin(m):
   p=list(map(float,m[1].split()));return '"origin" "'+point([p[0]*SCALE,p[1]*SCALE,p[2]])+'"'
  text=re.sub(r'"origin"\s*"([-\d.]+\s+[-\d.]+\s+[-\d.]+)"',origin,text)
  mapping={}
  def texture(m):
   old=m[2];new=cross.get(old.lower(),old.lower());tile=donors.get(new,alltiles.get(new));assert tile is not None,(old,new)
   used[new]=tile;mapping[old]=new;return m[1]+new
  text=re.sub(r'(^\s*\([^\n]+?\)\s*\([^\n]+?\)\s*\([^\n]+?\)\s+)(\S+)',texture,text,flags=re.M)
  dest=OUT/'source'/(row['id']+'.map');dest.write_text('// LibreQuake derivative for FPSloppa; see ../README.md and licence files.\n'+text)
  def godot(p):return [-p[1]*SCALE/32,p[2]/32-.7,-p[0]*SCALE/32]
  report.append({**row,'source_sha256':theme.sha(source.read_bytes()),'added_brushes':len(a.brushes),'removed_hill_pickups':removed,'spawns':len(spawns),'objectives':{'red':godot(spawns[0]),'blue':godot(spawns[1]),'hill':godot([cx,cy,top+24])},'texture_mapping':mapping})
 # Animated companions must be present in the WAD as well.
 for name in list(used):
  if name.startswith('+'):
   for other,tile in alltiles.items():
    if other.startswith('+') and other[2:]==name[2:]:used[other]=tile
 wad=bytearray(b'WAD2'+bytes(8));directory=[]
 for name,tile in sorted(used.items()):
  at=len(wad);wad.extend(tile);directory.append(struct.pack('<iiiBBH16s',at,len(tile),len(tile),68,0,0,name.encode()))
 at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at);(OUT/'source/koth-used.wad').write_bytes(wad)
 compiler=Path('/tmp/hislop-ericw/ericw-tools-v0.18-Linux/bin')
 def compile(row):
  id=row['id'];dest=ROOT/'maps'/(id+'.bsp')
  for exe,flags in [('qbsp',['-nodetail',str(OUT/'source'/(id+'.map')),str(dest)]),('vis',['-threads','2','-fast',str(dest)]),('light',['-threads','2','-extra','-bspxlit',str(dest)])]:
   with (ROOT/'test-results/koth'/(id+'-'+exe+'.log')).open('w') as log:subprocess.run([str(compiler/exe),*flags],cwd=OUT/'source',stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
  row['sha256']=theme.sha(dest.read_bytes());print('COMPILED',id,flush=True)
  for suffix in ['.prt','.pts','.texinfo','.log']:(ROOT/'maps'/(id+suffix)).unlink(missing_ok=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(compile,report))
 for name in ['qbsp.log','vis.log','light.log']:(OUT/'source'/name).unlink(missing_ok=True)
 (OUT/'BUILD.json').write_text(json.dumps({'xy_scale':SCALE,'maps':report,'wad_bytes':len(wad),'textures':len(used)},indent=2)+'\n')
 manifest_path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(manifest_path.read_text());ids=[r['id'] for r in report]
 catalog=[r for r in catalog if r['id'] not in ids]
 for entry in catalog:
  if 'modes' in entry:entry['modes']=[m for m in entry['modes'] if m!='koth']
 for r in report:catalog.append({k:r[k] for k in ['id','title','objectives','sha256']}|{'modes':['koth'],'path':'res://maps/'+r['id']+'.bsp','scene':'res://maps/cache/'+r['id']+'.scn'})
 manifest_path.write_text(json.dumps(catalog,indent=2)+'\n');(ROOT/'maps/koth_maplist.txt').write_text('\n'.join(ids)+'\n')
 for name in ['COPYING','CREDITS','README-IMPORTANT-LICENCE-INFO']:shutil.copy2(ROOT/'maps'/('LibreQuake-'+name+'.txt'),OUT/('LibreQuake-'+name+'.txt'))
 shutil.copy2(ROOT/'deathmatch/maps/texture_replacements/Makkon_License.txt',OUT/'Makkon_License.txt')
if __name__=='__main__':main()
