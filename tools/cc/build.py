"""Build four CC-specific LibreQuake derivatives. Original layout sources: BSD-3-Clause."""
from pathlib import Path
import sys,importlib.util,json,re,shutil,struct,subprocess,concurrent.futures,collections,math,hashlib
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('koth_builder',ROOT/'tools/koth/build.py');k=importlib.util.module_from_spec(spec);spec.loader.exec_module(k)
OUT=ROOT/'maps/CC';LOCAL=ROOT/'tools/koth/local/dev';LOG=ROOT/'test-results/cc'
def main():
 recipes=json.loads((ROOT/'tools/cc/recipes.json').read_text());tiles={};used={};rows=[]
 for wad in sorted((LOCAL/'texture-wads').glob('*.wad')):tiles.update(k.theme.wad_textures(wad.read_bytes()))
 donors,_=k.theme.makkon();cross=json.loads((ROOT/'tools/makkon/shared.json').read_text())['librequake']
 spawns=json.loads((ROOT/'tools/cc/spawns.json').read_text()) if (ROOT/'tools/cc/spawns.json').exists() else {}
 for r in recipes:
  id=r['id'];source=LOCAL/'maps/src/dm'/(r['source']+'.map');shutil.copy2(source,OUT/'original'/source.name);text=source.read_text();entities=k.blocks(text);world=entities.pop(0);a=k.Shape(id,r['title']);x,y,z=r['center'];tex=r['floor'];trim=r['trim'];counts=collections.Counter()
  def box(lo,hi,t=tex):a.box(tuple(lo[i]+[x,y,z][i] for i in range(3)),tuple(hi[i]+[x,y,z][i] for i in range(3)),t)
  def ramp(x0,x1,y0,y1,z0,z1,rotate=False):
   temp=k.Shape('','');temp.ramp_x(x0,x1,y0,y1,z+z0,z+z1,tex)
   for b in temp.brushes:
    def p(m):
     X,Y,Z=map(float,m[1].split())
     if rotate:X,Y=-Y,X
     return '( '+k.point([x+X,y+Y,Z])+' )'
    b=re.sub(r'\(\s*([^()]+)\)',p,b)
    if rotate:
     def uv(m):
      X,Y,Z,W=map(float,m[1].split());return '[ '+k.point([-Y,X,Z,W])+' ]'
     b=re.sub(r'\[\s*([^\[\]]+)\]',uv,b)
    a.brushes.append(b)
  if r['source']=='lqdm3':
   # Two wide crossings through the irregular temple court, gentle landing ramps.
   box((-160,-96,-32),(160,96,0));box((-96,-160,-32),(96,160,0))
   ramp(160,320,-72,72,0,-64);ramp(-320,-160,-72,72,-128,0)
   ramp(160,320,-72,72,0,-16,True);ramp(-320,-160,-72,72,-80,0,True)
  elif r['source']=='lqdm4':
   # Widen the exposed central lava crossing and add a parallel passing lane.
   box((-288,-128,-32),(288,128,0));box((-224,128,-32),(224,192,0))
   ramp(192,352,-96,96,0,-120,True)
   for dx in [-192,192]:box((dx-24,-100,0),(dx+24,-76,48),trim)
  elif r['source']=='lqdm6':
   # Join the broken upper walk; a long return ramp links the lower court.
   box((-256,-96,-32),(256,96,0));box((-128,-224,-32),(128,224,0))
   ramp(-512,-128,-80,80,-192,0,True)
   for dx in [-200,200]:box((dx-20,60,0),(dx+20,84,48),trim)
  else:
   # A direct lower-to-upper ramp replaces the long stair detour; retain two flanks.
   ramp(-64,256,-72,72,0,144)
   box((256,-96,120),(320,96,144))
   box((-192,-128,-16),(-64,128,0))
  bounds=r.get('bounds')
  def outside(block):
   pts=[list(map(float,m)) for m in re.findall(r'\(\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\)',block)]
   return bool(bounds and pts and any(max(p[i] for p in pts)<bounds[i] or min(p[i] for p in pts)>bounds[i+3] for i in range(3)))
  if bounds:
   # Keep the temple court and its flanks; remove the disconnected eastern arena.
   old_brushes=k.blocks(world[1:-1]);kept=[b for b in old_brushes if not outside(b)]
   counts['outside_world_brushes']=len(old_brushes)-len(kept)
   world=k.entity(k.fields(world));world=world[:-1]+'\n'+'\n'.join(kept)+'\n}'
   X,Y,Z,XX,YY,ZZ=bounds
   for lo,hi in [((X-32,Y-32,Z),(X,YY+32,ZZ)),((XX,Y-32,Z),(XX+32,YY+32,ZZ)),((X,Y-32,Z),(XX,Y,ZZ)),((X,YY,Z),(XX,YY+32,ZZ))]:a.box(lo,hi,trim)
  # Preserve architecture while dropping collision-free ornament meshes and inert pickups.
  retained=[]
  for e in entities:
   f=k.fields(e);kind=f.get('classname','')
   if bounds:
    p=list(map(float,f.get('origin','0 0 0').split()))
    if outside(e) or ('origin' in f and any(p[i]<bounds[i] or p[i]>bounds[i+3] for i in range(3))):counts['outside_entities']+=1;continue
   if kind.startswith(('item_' ,'weapon_','monster_','ambient_')) or kind in ['info_intermission','info_koth_control','trigger_changelevel']:
    counts[kind]+=1;continue
   if kind=='func_detail_illusionary' and not any(t in e.lower() for t in ['*water','*lava','*slime','sky']):counts['decorative_entities']+=1;continue
   if id in spawns and kind in ['info_player_start','info_player_deathmatch','info_player_team1','info_player_team2']:continue
   if kind.startswith('light'):e=re.sub(r'^"(?:targetname|style)"[^\n]*\n?','',e,flags=re.M)
   if kind=='trigger_push' and r['scale']!=1 and 'angles' in f:
    pitch,yaw,roll=map(float,f['angles'].split());rad=math.radians(pitch);h=math.cos(rad)*r['scale'];v=-math.sin(rad)
    e=k.setkey(e,'angles',k.point([math.degrees(math.atan2(-v,h)),yaw,roll]));e=k.setkey(e,'speed','%g'%(float(f.get('speed',1000))*math.hypot(h,v)))
   retained.append(e)
  # Seal upstream exterior void; structural walls stay intact.
  points=[list(map(float,m)) for m in re.findall(r'\(\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\)',text)]
  X,Y,Z=[min(p[i] for p in points)-64 for i in range(3)];XX,YY,ZZ=[max(p[i] for p in points)+64 for i in range(3)]
  for lo,hi in [((X-32,Y-32,Z-32),(XX+32,YY+32,Z)),((X-32,Y-32,ZZ),(XX+32,YY+32,ZZ+32)),((X-32,Y-32,Z),(X,YY+32,ZZ)),((XX,Y-32,Z),(XX+32,YY+32,ZZ)),((X,Y-32,Z),(XX,Y,ZZ)),((X,YY,Z),(XX,YY+32,ZZ))]:a.box(lo,hi,'sky_star')
  world=world.rstrip()[:-1]+'\n'+'\n'.join(a.brushes)+'\n}'
  for key,value in {'wad':'cc-used.wad','message':r['title'],'_fpsloppa_bake':'1','_fpsloppa_atlas':'2048','_fpsloppa_light_response':'quake'}.items():world=k.setkey(world,key,value)
  if id in spawns:
   for p in spawns[id]:retained.append(k.entity({'classname':'info_player_deathmatch','origin':k.point(p)}))
   retained.append(k.entity({'classname':'info_player_start','origin':k.point(spawns[id][0])}))
  adapted='\n'.join([world,*retained])+'\n'
  def scale(m):
   p=list(map(float,m[1].split()));return '( '+k.point([p[0]*r['scale'],p[1]*r['scale'],p[2]])+' )'
  adapted=re.sub(r'\(\s*([-\d.]+\s+[-\d.]+\s+[-\d.]+)\s*\)',scale,adapted)
  def origin(m):
   p=list(map(float,m[1].split()));return '"origin" "'+k.point([p[0]*r['scale'],p[1]*r['scale'],p[2]])+'"'
  adapted=re.sub(r'"origin"\s*"([-\d.]+\s+[-\d.]+\s+[-\d.]+)"',origin,adapted);mapping={}
  def texture(m):
   old=m[2];new=cross.get(old.lower(),old.lower());tile=donors.get(new,tiles.get(new));assert tile is not None,(old,new);used[new]=tile;mapping[old]=new;return m[1]+new
  adapted=re.sub(r'(^\s*\([^\n]+?\)\s*\([^\n]+?\)\s*\([^\n]+?\)\s+)(\S+)',texture,adapted,flags=re.M)
  path=OUT/'source'/(id+'.map');path.write_text('// CC derivative of LibreQuake; retain ../LibreQuake-COPYING.txt and credits.\n'+adapted)
  rows.append({**r,'source_sha256':k.theme.sha(source.read_bytes()),'adapted_sha256':k.theme.sha(path.read_bytes()),'added_brushes':len(a.brushes),'removed':dict(counts),'texture_mapping':mapping})
 for name in list(used):
  if name.startswith('+'):
   for other,tile in tiles.items():
    if other.startswith('+') and other[2:]==name[2:]:used[other]=tile
 wad=bytearray(b'WAD2'+bytes(8));directory=[]
 for name,tile in sorted(used.items()):
  at=len(wad);wad.extend(tile);directory.append(struct.pack('<iiiBBH16s',at,len(tile),len(tile),68,0,0,name.encode()))
 at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at);(OUT/'source/cc-used.wad').write_bytes(wad)
 compiler=Path('/tmp/hislop-ericw/ericw-tools-v0.18-Linux/bin')
 def compile(row):
  id=row['id'];dest=ROOT/'maps'/(id+'.bsp')
  for exe,flags in [('qbsp',['-nodetail',str(OUT/'source'/(id+'.map')),str(dest)]),('vis',['-threads','2','-fast',str(dest)]),('light',['-threads','2','-extra4','-bspxlit','-bounce','0',str(dest)])]:
   with (LOG/(id+'-'+exe+'.log')).open('w') as log:subprocess.run([str(compiler/exe),*flags],cwd=OUT/'source',stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
  row['sha256']=k.theme.sha(dest.read_bytes());print('CC_BUILT',id,flush=True)
  for ext in ['.prt','.pts','.texinfo','.log']:(ROOT/'maps'/(id+ext)).unlink(missing_ok=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(compile,rows))
 for name in ['qbsp.log','vis.log','light.log']:(OUT/'source'/name).unlink(missing_ok=True)
 for name in ['COPYING','CREDITS','README-IMPORTANT-LICENCE-INFO']:shutil.copy2(ROOT/'maps'/('LibreQuake-'+name+'.txt'),OUT/('LibreQuake-'+name+'.txt'))
 shutil.copy2(ROOT/'maps/KOTH/Makkon_License.txt',OUT/'Makkon_License.txt')
 (OUT/'BUILD.json').write_text(json.dumps({'maps':rows,'textures':len(used),'wad_bytes':len(wad)},indent=2)+'\n')
 manifest=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(manifest.read_text());ids=[r['id'] for r in rows];catalog=[r for r in catalog if r['id'] not in ids]
 for r in rows:catalog.append({k:r[k] for k in ['id','title','sha256']}|{'modes':['cc'],'path':'res://maps/'+r['id']+'.bsp','scene':'res://maps/cache/'+r['id']+'.scn'})
 manifest.write_text(json.dumps(catalog,indent=2)+'\n')
if __name__=='__main__':main()
