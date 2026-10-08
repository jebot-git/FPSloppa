"""Build all ChaosUT KOTH adaptations with explicit material and actor provenance."""
from build_candidate import *
import re,copy
from shapely.geometry import Polygon
from shapely.ops import unary_union,triangulate
sys.path.insert(0,str(ROOT/'tools/arena_imports'))
from rcmd_materials import Materials
IDS={'KOTH-(WTF)Buttnutt':'buttnutt','KOTH-(WTF)TryTitan':'trytitan','KOTH-FbBeyondThunderdome][':'thunderdome','koth-The temple':'temple','KOTH_Cerebro':'cerebro','KOTH_Dungeon':'dungeon','KOTH_Wilderness':'wilderness'}
PICKUPS={'ut_eightball':'weapon_rocketlauncher','ut_flakcannon':'weapon_grenadelauncher','flak2':'weapon_grenadelauncher','flak2proxy':'weapon_grenadelauncher','minigun2':'weapon_supernailgun','armor':'item_armor2','armor2':'item_armor2','thighpads':'item_armor1','superhealth':'item_health','c_megahealth':'item_health','shieldbelt':'item_armorInv','ut_shieldbelt':'item_armorInv','miniammo':'item_spikes','flakammo':'item_rockets','rocketpack':'item_rockets','warheadlauncher':'weapon_lightning','shockrifle':'weapon_lightning','sniperrifle':'weapon_supershotgun','sniper_rpb':'weapon_supershotgun','pulsegun':'weapon_nailgun','ripper':'weapon_supernailgun','ut_biorifle':'weapon_grenadelauncher','medbox':'item_health','healthpack':'item_health','healthvial':'item_health','bulletbox':'item_shells','shockcore':'item_cells','pammo':'item_spikes','bladehopper':'item_spikes','bioammo':'item_rockets','crossbow':'weapon_supershotgun','explosivecrossbow':'weapon_rocketlauncher','poisonarrowpack':'item_shells','exparrowpack':'item_rockets','udamage':'item_artifact_super_damage','ut_invisibility':'item_artifact_invisibility'}
def rename(raw,alias):
 out=bytearray(raw);out[:16]=alias.encode().ljust(16,b'\0');return bytes(out)
def floor_at(polys,loc,maximum=256):
 x,y,z=loc;found=[]
 for f in polys:
  n=np.array(f['normal'])
  if n[2]<.65 or f.get('flags',0)&8:continue
  ps=np.array(f['points']);plane_z=ps[0,2]-(n[0]*(x-ps[0,0])+n[1]*(y-ps[0,1]))/n[2]
  if not z+16>=plane_z>=z-maximum:continue
  signs=[]
  for a,b in zip(ps,np.roll(ps,-1,axis=0)):signs.append((b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]))
  if min(signs)>=-.1 or max(signs)<=.1:found.append(plane_z)
 return np.array([x,y,max(found)]) if found else None

def transform(poly,p):
 out=copy.deepcopy(poly);pitch,yaw,roll=np.array(p.get('Rotation',[0,0,0]))*math.pi/32768
 cy,sy=math.cos(yaw),math.sin(yaw);cp,sp=math.cos(pitch),math.sin(pitch);cr,sr=math.cos(roll),math.sin(roll)
 rot=np.array([[cy*cp,cy*sp*sr-sy*cr,-cy*sp*cr-sy*sr],[sy*cp,sy*sp*sr+cy*cr,-sy*sp*cr+cy*sr],[sp,-cp*sr,cp*cr]])
 scale=np.ones(3)
 for key in ['MainScale','PostScale']:
  if isinstance(p.get(key),dict):scale*=np.array(struct.unpack('<3f',bytes.fromhex(p[key]['raw'])[:12]))
 matrix=rot@np.diag(scale);out['points']=((np.array(poly['points'])-p.get('PrePivot',[0,0,0]))@matrix.T+p.get('Location',[0,0,0])).tolist();out['normal']=(np.linalg.inv(matrix).T@np.array(poly['normal'])).tolist()
 return out

def build(row, assault=None):
 name=assault["id"] if assault else 'koth_ut_'+IDS[row['name']];out=LOCAL/'candidates'/name;out.mkdir(parents=True,exist_ok=True)
 files=members((LOCAL/'archives'/row['archive_sha1']).read_bytes());source=LOCAL/'converted'/row['archive_sha1'][:12];model=json.load(gzip.open(source/'world.json.gz'));actors=json.loads((source/'actors.json').read_text());attempt=json.loads((source/'attempt.json').read_text());pkg=Package(files[attempt['member']])
 packs={Path(n).stem.lower():Package(b) for n,b in files.items() if n.lower().endswith(('.utx','.unr'))}
 materials=Materials(wad_textures((ROOT/'tools/fortressone/librequake.wad').read_bytes()),{});bank=materials.bank;bank['skip']=rename(bank['met_brn_pan1'],'skip');bank['trigger']=rename(bank['met_brn_pan1'],'trigger')
 textures={};sources={};adaptations=[];movers=[]
 for actor in actors:
  if actor['class_path'].split('.')[-1]=='Mover':
   props=actor['properties'];polys=[transform(f,props) for f in pkg.brush_polygons(props['Brush']['object'])];movers.append((actor,polys))
 allpolys=model['polygons']+[f for a,polys in movers for f in polys]
 for original in sorted({p['texture'] for p in allpolys}):
  alias='ut'+hashlib.sha256(original.encode()).hexdigest()[:12];source_info={}
  try:
   key,local=original.split('.',1);pack=packs[key.lower()];e=next(e for i,e in enumerate(pack.exports) if pack.path(i+1).lower()==local.lower());bank[alias]=texture(pack,e,alias);source_info=dict(kind='authored package texture',path=original)
  except (KeyError,ValueError,StopIteration):
   donor=materials.material(original);bank[alias]=rename(bank[donor],alias);source_info=dict(kind='existing project replacement',source=original,donor=donor)
  textures[original]=alias;sources[alias]=source_info
 def surface(f):
  alias='sky_star' if f['flags']&128 else textures[f['texture']]
  return prism(f,alias)
 brushes=[];liquid_brushes=[];liquid_groups={}
 if assault or name in ['koth_ut_trytitan','koth_ut_dungeon']:
  ramps=[];stair_faces=[];adapt_steps=assault and name!='as_ut_twintower'
  for f in model['polygons']:
   ps=np.array(f['points']);normal=np.array(f['normal']);height=np.ptp(ps[:,2])
   if abs(normal[2])>.001 or not (12<height<40 if adapt_steps else 31.9<height<32.1):continue
   top=ps[np.abs(ps[:,2]-ps[:,2].max())<.01]
   if len(top)<2:continue
   a,b=max(((a,b) for a in top for b in top),key=lambda pair:np.linalg.norm(pair[0]-pair[1]))
   if np.linalg.norm(a-b)<(40 if adapt_steps else 64):continue
   ramp_run=height*(.95 if adapt_steps else 1.7)
   center=(a+b)*.5;low=center+normal*ramp_run;low[2]-=height
   floor=floor_at(model['polygons'],low+np.array([0,0,2]),8)
   upper=floor_at(model['polygons'],center-normal*2+np.array([0,0,2]),8)
   if floor is None or upper is None or abs(floor[2]-low[2])>2 or abs(upper[2]-center[2])>2:continue
   ramp_points=np.array([a-normal*.5,b-normal*.5,b+normal*ramp_run-np.array([0,0,height]),a+normal*ramp_run-np.array([0,0,height])]);ramp_points[:,2]+=.15
   n=np.cross(ramp_points[1]-ramp_points[0],ramp_points[2]-ramp_points[0]);n/=np.linalg.norm(n)
   if n[2]<0:n=-n
   stair_faces.append((f,a,b,height,normal))
   ramps.append(dict(points=ramp_points.tolist(),normal=n.tolist(),uv_texels=[[q[0],q[1]] for q in ramp_points],texture=f['texture'],flags=0))
  if adapt_steps:
   # Join collinear stair runs into continuous walking surfaces. Short isolated
   # treads can vanish during capsule erosion even when every rise is legal.
   groups={}
   for f,a,b,h,n in stair_faces:
    axis=0 if abs(n[0])>.999 else 1 if abs(n[1])>.999 else -1
    if axis<0:continue
    cross=1-axis;key=(axis,round(n[axis]),round(min(a[cross],b[cross])),round(max(a[cross],b[cross])))
    groups.setdefault(key,[]).append((f,a,b,h,n))
   flights=[]
   for key,faces in groups.items():
    faces.sort(key=lambda r:r[1][2]);chain=[]
    for item in faces:
     if chain and (item[1][2]-chain[-1][1][2]>40.1 or abs(item[1][key[0]]-chain[-1][1][key[0]])>80):
      if len(chain)>=3:flights.append(chain)
      chain=[]
     chain.append(item)
    if len(chain)>=3:flights.append(chain)
   for chain in flights:
    first=chain[0];last=chain[-1];axis=0 if abs(first[4][0])>.999 else 1;cross=1-axis;n=first[4]
    low=sorted([first[1],first[2]],key=lambda q:q[cross]);high=sorted([last[1],last[2]],key=lambda q:q[cross])
    ps=np.array([high[0]-n*.5,high[1]-n*.5,low[1]+n*2-np.array([0,0,first[3]]),low[0]+n*2-np.array([0,0,first[3]])]);ps[:,2]+=.2
    normal=np.cross(ps[1]-ps[0],ps[2]-ps[0]);normal/=np.linalg.norm(normal)
    if normal[2]<0:normal=-normal
    if normal[2]<.68:continue
    ramps.append(dict(points=ps.tolist(),normal=normal.tolist(),uv_texels=[[q[0],q[1]] for q in ps],texture=last[0]['texture'],flags=0))
   adaptations.append(str(len(flights))+' short-tread stair flights bridged with continuous ramps')
  if name=='as_ut_pumpfac':
   # The original shaft stair treads split into narrow CSG fragments. Preserve
   # that route with three continuous ramps over the authored stair flights.
   for coords in [
    [[1088,-2688,-352],[1232,-2688,-352],[1232,-2432,-240],[1088,-2432,-240]],
    [[1232,-2416,-240],[1232,-2272,-240],[1440,-2272,-128],[1440,-2416,-128]],
    [[1392,-2784,-432],[1392,-2640,-432],[1232,-2640,-352],[1232,-2784,-352]]]:
    ps=np.array(coords,dtype=float);ps[:,2]+=.3;normal=np.cross(ps[1]-ps[0],ps[2]-ps[0]);normal/=np.linalg.norm(normal)
    if normal[2]<0:normal=-normal
    ramps.append(dict(points=ps.tolist(),normal=normal.tolist(),uv_texels=[[q[0],q[1]] for q in ps],texture=next(f['texture'] for f in model['polygons'] if f['normal'][2]>.9),flags=0))
   adaptations.append('Three continuous shaft-stair ramps retain the original approach to Shaft and Hall')
  if name=='as_ut_atlantica':
   # Close the short gap at the outer lighthouse stair landing with a stone
   # ramp; both endpoints remain on the authored stair route.
   ps=np.array([[-352,876,-1696],[-400,876,-1696],[-400,944,-1680],[-352,944,-1680]],dtype=float);ps[:,2]+=.3
   normal=np.cross(ps[1]-ps[0],ps[2]-ps[0]);normal/=np.linalg.norm(normal)
   if normal[2]<0:normal=-normal
   ramps.append(dict(points=ps.tolist(),normal=normal.tolist(),uv_texels=[[q[0],q[1]] for q in ps],texture=next(f['texture'] for f in model['polygons'] if f['normal'][2]>.9),flags=0))
   adaptations.append('Short stone connector preserves the outer lighthouse stair landing')
  model['polygons']+=ramps;adaptations.append(str(len(ramps))+' ramps over tall authored stairs for standard arena movement')
 for f in model['polygons']:
  if f['flags']&8:
   lower=f['texture'].lower()
   if abs(f['normal'][2])>.65 and ('water' in lower or 'lava' in lower):
    z=round(float(np.array(f['points'])[:,2].mean()),3);kind='*lava1' if 'lava' in lower else '*water2'
    liquid_groups.setdefault((kind,z),[]).append(Polygon(np.array(f['points'])[:,:2]).buffer(0))
   continue # Other nonsolid decorations must not seal movement
  try:brushes.append(surface(f))
  except ValueError:adaptations.append('Skipped degenerate polygon')
 for (kind,z),polygons in liquid_groups.items():
  united=unary_union(polygons).simplify(.05,preserve_topology=True)
  regions=list(united.geoms) if hasattr(united,'geoms') else [united]
  for region in regions:
   if region.is_empty or region.area<1:continue
   pieces=[region.convex_hull] if abs(region.convex_hull.area-region.area)<.1 else [t for t in triangulate(region) if region.covers(t.representative_point())]
   for piece in pieces:
    if piece.area<1:continue
    points=[[x,y,z] for x,y in list(piece.exterior.coords)[:-1]];center=np.array(points).mean(axis=0)
    floor=floor_at(model['polygons'],center-np.array([0,0,20]),4096)
    depth=max(8,min(1024,(z-floor[2])*.8+4)) if floor is not None else 128
    liquid=dict(points=points,normal=[0,0,1],uv_texels=[[q[0],q[1]] for q in points])
    liquid_brushes.append(prism(liquid,kind,depth))
 brushes+=liquid_brushes
 adaptations.append(str(len(liquid_brushes))+' authored liquid surfaces rebuilt as native water/lava volumes')
 points=np.array([p for f in model['polygons'] for p in f['points']])*.8;lo=points.min(axis=0)-64;hi=points.max(axis=0)+64
 for axis in range(3):
  for side in range(2):
   a=lo.copy();b=hi.copy()
   if side==0:b[axis]=lo[axis]+16
   else:a[axis]=hi[axis]-16
   brushes.append(box(a,b,'skip'))
 entities=[];starts=[];hills=[];spawn_fixes=[];blockers=[];traversal=[]
 authored_teams={a['properties'].get('TeamNumber',0) for a in actors if a['class_path'].endswith('.PlayerStart')}
 if len(authored_teams)>1:adaptations.append('Retained authored red/blue starts for two-team KOTH; green/gold team starts excluded')
 for actor in actors:
  c=actor['class_path'].split('.')[-1];p=actor['properties'];loc=np.array(p.get('Location',[0,0,0]),dtype=float)
  if c=='PlayerStart':
   if len(authored_teams)>1 and p.get('TeamNumber',0)>1:continue
   floor=floor_at(model['polygons'],loc)
   if floor is None:
    for radius in [32,64,96]:
     for dx,dy in [(radius,0),(-radius,0),(0,radius),(0,-radius)]:
      floor=floor_at(model['polygons'],loc+np.array([dx,dy,0]))
      if floor is not None:break
     if floor is not None:break
   if floor is None:blockers.append('No floor under '+actor['name']);continue
   q=floor*.8;q[2]+=22.4;starts.append((q,p));spawn_fixes.append(dict(actor=actor['name'],source=loc.tolist(),floor=floor.tolist()))
  pickup=PICKUPS.get(c.lower())
  if pickup:entities.append(ent({'classname':pickup,'origin':point(loc*.8),'spawnflags':2 if c.lower() in ['superhealth','c_megahealth'] else 0}))
  if c in ['ChaosKOTHHill','ChaosKOTHHillZone','KOTH2Hill']:
   floor=floor_at(model['polygons'],loc,1024)
   if floor is None:blockers.append('No floor below hill '+actor['name']);continue
   q=floor*.8;q[2]+=22.4;hills.append(q)
  if c=='Light' or c in ['LightBox','TorchFlame','Lantern']:
   h=p.get('LightHue',0)/255;s=1-p.get('LightSaturation',255)/255;colour=colorsys.hsv_to_rgb(h,s,1)
   entities.append(ent({'classname':'light','origin':point(loc*.8),'light':max(160,p.get('LightBrightness',64)*4),'wait':max(.08,256/max(160,p.get('LightRadius',64)*20)),'_color':point(colour)}))
  if c in ['Teleporter','VisibleTeleporter']:
   tag=str(p.get('Tag',actor['name'])).lower();url=str(p.get('URL','')).lower()
   entities.append(ent({'classname':'info_teleport_destination','targetname':tag,'origin':point(loc*.8+np.array([0,0,-4.6])),'angle':p.get('Rotation',[0,0,0])[1]*360/65536}))
   if url and '#' not in url and '/' not in url:
    radius=p.get('CollisionRadius',20)*.8;height=p.get('CollisionHeight',40)*.8;q=loc*.8
    entities.append(ent({'classname':'trigger_teleport','target':url})[:-1]+'\n'+box(q-[radius,radius,height],q+[radius,radius,height],'trigger')+'\n}');traversal.append(dict(kind='teleport',source=actor['name'],target=url))
  if c=='WarpZoneInfo':
   tag=str(p.get('ThisTag',actor['name'])).lower();url=str(p.get('OtherSideURL','')).lower()
   origin=loc
   if isinstance(p.get('WarpCoords'),dict):origin=np.array(struct.unpack('<3f',bytes.fromhex(p['WarpCoords']['raw'])[:12]))
   options=[]
   for radius in [24,48,72,96,128,192]:
    for dx,dy in [(radius,0),(-radius,0),(0,radius),(0,-radius)]:
     candidate=floor_at(model['polygons'],origin+np.array([dx,dy,64]),512)
     if candidate is not None:options.append(candidate)
    if options:break
   if not options:blockers.append('No safe floor at warp '+actor['name']);continue
   floor=min(options,key=lambda q:np.linalg.norm(q[:2]));q=floor*.8
   entities.append(ent({'classname':'info_teleport_destination','targetname':tag,'origin':point(q+np.array([0,0,-3.64]))}))
   entities.append(ent({'classname':'trigger_teleport','target':url})[:-1]+'\n'+box(q+[-16,-16,0],q+[16,16,64],'trigger')+'\n}')
   traversal.append(dict(kind='warp adapted as teleporter',source=actor['name'],target=url))
  if c=='Kicker':
   velocity=p.get('KickVelocity',[0,0,0]);q=loc*.8;radius=p.get('CollisionRadius',40)*.8;height=p.get('CollisionHeight',40)*.8
   if sum(v*v for v in velocity)>0:
    entities.append(ent({'classname':'trigger_push','angles':point([-math.degrees(math.atan2(velocity[2],math.hypot(velocity[0],velocity[1]))),math.degrees(math.atan2(velocity[1],velocity[0])),0]),'speed':np.linalg.norm(velocity)*.8,'fpsloppa_push_scale':1})[:-1]+'\n'+box(q-[radius,radius,height],q+[radius,radius,height],'trigger')+'\n}');traversal.append(dict(kind='push',source=actor['name']))
 for actor,polys in movers:
  p=actor['properties'];travel=np.array(p.get('KeyPos[1]',[0,0,0]))*.8
  if not polys:raise ValueError("Empty moving brush")
  extent=np.ptp(np.array([q for f in polys for q in f['points']]),axis=0)
  lift=abs(travel[0])+abs(travel[1])<.1 and abs(travel[2])>48 and extent[2]<min(extent[0],extent[1])*.5 and 'Trigger' not in p.get('InitialState','')
  if lift:
   raised=[]
   for f in polys:
    f=copy.deepcopy(f);f['points']=(np.array(f['points'])+np.maximum(travel,0)/.8).tolist();raised.append(surface(f))
   entities.append(ent({'classname':'func_plat','height':abs(travel[2])})[:-1]+'\n'+'\n'.join(raised)+'\n}')
  elif assault and np.linalg.norm(travel)<.1:
   # Rotating wall levers become the native objective console at the Fort marker.
   brushes.extend(surface(f) for f in polys)
  else:
   entities.append(ent({'classname':'func_door','ut_travel':point(travel),'speed':np.linalg.norm(travel)/max(.1,p.get('MoveTime',1.0)),'wait':p.get('StayOpenTime',4)})[:-1]+'\n'+'\n'.join(surface(f) for f in polys)+'\n}')
  traversal.append(dict(kind='lift' if lift else 'static switch lever' if assault and np.linalg.norm(travel)<.1 else 'proximity door',source=actor['name'],travel=travel.tolist()))
 if assault:
  for loc,p in starts:p['TeamNumber']=1-p.get('TeamNumber',0) # UT team 1 attacks; native role 0 attacks first.
  by_name={a['name']:a for a in actors}
  objective_details=[]
  for i,objective in enumerate(assault['objectives']):
   actor=by_name[objective['actor']];p=actor['properties'];loc=np.array(p['Location'],dtype=float)
   if name=='as_ut_atlantica' and actor['name']=='FortStandard0':
    loc+=np.array([0,24,0]);adaptations.append('Generator console moved 0.6 m within its authored activation zone to retain a clear exit beside the lever')
   floor=floor_at(model['polygons'],loc,512)
   if floor is None:raise ValueError('No floor under AS objective '+actor['name'])
   q=floor*.8;q[2]+=22.4
   health=0 if p.get('bTriggerOnly',False) else max(1,p.get('Health',100))
   title=objective['title'] or p.get('FortName') or p.get('Tag',actor['name'])
   entities.append(ent({'classname':'info_as_objective','origin':point(q),'step':i+1,'health':health,'title':title}))
   objective_details.append(dict(actor=actor['name'],step=i+1,title=title,health=health,source=loc.tolist(),origin=q.tolist(),interaction='switch' if health==0 else 'destructible'))
  adaptations.append('Authored FortStandard sequence mapped to native switches/destructible targets; UT team 1 becomes initial attacking role')
 for i,(loc,p) in enumerate(starts):
  entities.append(ent({'classname':'info_player_team'+str(1+(p.get('TeamNumber',0) if len(authored_teams)>1 else i%2)),'origin':point(loc),'angle':p.get('Rotation',[0,0,0])[1]*360/65536}))
 for i,hill in enumerate(hills):entities.append(ent({'classname':'info_koth_control','origin':point(hill),'hill_index':i,'hill_authored':1}))
 if not starts or not (assault or hills):raise ValueError('No starts or objectives')
 entities.append(ent({'classname':'info_player_start','origin':point(starts[0][0])}))
 world=ent({'classname':'worldspawn','wad':'textures.wad','message':row['name']+' — ChaosUT adaptation','_fpsloppa_bake':'1','_fpsloppa_atlas':'4096','_fpsloppa_light_response':'quake','_minlight':'64','_bounce':'1'})[:-1]+'\n'+'\n'.join(brushes)+'\n}'
 (out/(name+'.map')).write_text(world+'\n'+'\n'.join(entities));(out/'textures.wad').write_bytes(wad(bank))
 report=dict(id=name,source=row,texture_sources=sources,source_faces=len(model['polygons']),spawns=len(starts),hill_points=len(hills),spawn_grounding=spawn_fixes,traversal=traversal,adaptations=adaptations+['Missing retail materials replaced with varied existing project materials','Scripted Chaos weapons mapped to classic arena pickups','Moving brushes adapted to ordinary proximity doors and lifts; original script events not executed'],blockers=blockers,status='staging')
 if assault:report['assault_objectives']=objective_details;report['mode']='as'
 (out/'conversion.json').write_text(json.dumps(report,indent=2)+'\n')
 for stage,args in [('qbsp',['-noclip']),('light',['-extra','-bspxlit','-threads','2'])]:
  with (out/(stage+'.log')).open('w') as log:run=subprocess.run([str(COMPILER/stage),*args,str(out/(name+('.map' if stage=='qbsp' else '.bsp')))],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=600)
  if run.returncode:raise RuntimeError(stage+' failed: '+(out/(stage+'.log')).read_text()[-1200:])
 # Godot renders meshes directly and never uses the Quake compressed PVS.
 # Thin-shell conversions generate huge PVS lumps; discard only that unused
 # visibility stream while retaining all collision and lighting lumps.
 from build import unpack,pack
 bsp=out/(name+'.bsp');data=bsp.read_bytes();parts,extra=unpack(data);parts[4]=b'';leaves=bytearray(parts[10])
 for offset in range(4,len(leaves),28):struct.pack_into('<i',leaves,offset,-1)
 parts[10]=bytes(leaves)
 bsp.write_bytes(pack(parts,extra,data[:4]))
 print(name,'built',len(starts),'starts',len(hills),'hills',flush=True)
 return report
if __name__=='__main__':
 results=[]
 if len(sys.argv)>1 and (HERE/'koth-builds.json').exists():results=[x for x in json.loads((HERE/'koth-builds.json').read_text()) if IDS.get(x['source']['name']) not in sys.argv[1:]]
 for row in json.loads((HERE/'downloads.json').read_text()):
  if row['mode']!='koth' or len(sys.argv)>1 and IDS[row['name']] not in sys.argv[1:]:continue
  try:results.append(build(row))
  except Exception as e:print(row['name'],'FAILED',e,flush=True);results.append(dict(source=row,status='failed',error=str(e)))
 (HERE/'koth-builds.json').write_text(json.dumps(results,indent=2)+'\n')
