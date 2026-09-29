"""Original Tribes-style field equipment, Blender MCP rebuild entry point.
Reuses CC0 Kenney cores with independent outer geometry and the vehicle atlas.
Godot metres / Y-up / forward -Z; pivot positions follow production controls.
"""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(globals().get('PROP_PROJECT',(Path(__file__).resolve().parents[2] if '__file__' in globals() else Path('/home/blux/Documents/FPSloppa'))))
exec(compile((ROOT/'tools/tribes/prop_sources.py').read_text(),'prop_sources.py','exec'))
OUT=ROOT/'deathmatch/tribes/props';OUT.mkdir(exist_ok=True)
KINDS=['station_surround','station_inventory','station_ammo','station_command','station_vehicle','generator','portable_generator','solar','base_sensor','large_sensor','fixed_fusion','fixed_mini','fixed_elf','fixed_missile','fixed_mortar','turret','inventory','ammo_station','pulse','motion','remote_jammer','camera','beacon']
image=bpy.data.images.load(str(ROOT/'deathmatch/vehicles/tribes/hull-atlas.png'),check_existing=True);image.pack()
mats=[]
for name,color in [('Bronze',(1,1,1,1)),('Gunmetal',(1,1,1,1)),('Recess',(.8,.8,.8,1)),('TeamPanel',(1,1,1,1)),('StatusLight',(.08,.60,.72,1))]:
 m=bpy.data.materials.new('STEquipment_'+name);m.use_nodes=True;m.diffuse_color=color
 p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=color;p.inputs['Metallic'].default_value=.28;p.inputs['Roughness'].default_value=.62
 if name!='StatusLight':
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 else:p.inputs['Emission Color'].default_value=color;p.inputs['Emission Strength'].default_value=1.3
 mats.append(m)
def cv(p):return (p[0],-p[2],p[1])
class Model:
 def __init__(self,kind):
  self.kind=kind;self.prefix='STProp_'+kind+'_'
  for o in list(bpy.data.objects):
   if o.name.startswith(self.prefix):bpy.data.objects.remove(o,do_unlink=True)
  self.root=bpy.data.objects.new(self.prefix+'Root',None);bpy.context.collection.objects.link(self.root)
  self.parent=self.root;self.head=None
 def mesh(self,name,verts,faces,mat=0):
  data=bpy.data.meshes.new(self.prefix+name);data.from_pydata([cv(v) for v in verts],[],faces);data.update()
  o=bpy.data.objects.new(self.prefix+name,data);bpy.context.collection.objects.link(o);o.parent=self.parent;o.data.materials.append(mats[mat]);o['atlas_cell']=mat
  return o
 def box(self,name,at,size,mat=0):
  x,y,z=at;a,b,c=[s*.5 for s in size]
  return self.mesh(name,[(x+u*a,y+v*b,z+w*c) for u,v,w in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)
 def vertical(self,name,sections,mat=0,at=(0,0,0)):
  verts=[]
  for y,w,d in sections:
   b=min(w,d)*.27
   verts.extend([(at[0]+x,at[1]+y,at[2]+z) for x,z in [(-w,-d+b),(-w+b,-d),(w-b,-d),(w,-d+b),(w,d-b),(w-b,d),(-w+b,d),(-w,d-b)]])
  faces=[tuple(range(7,-1,-1)),tuple(range(len(verts)-8,len(verts)))]
  for j in range(len(sections)-1):
   for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
  return self.mesh(name,verts,faces,mat)
 def tube(self,name,a,b,r,mat=1,n=12,r2=None):
  a=Vector(a);b=Vector(b);direction=(b-a).normalized();u=direction.cross(Vector((0,1,0)))
  if u.length<.01:u=direction.cross(Vector((0,0,1)))
  u.normalize();v=direction.cross(u);verts=[]
  for centre,radius in [(a,r),(b,r if r2 is None else r2)]:verts += [tuple(centre+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for i in range(n)]
  return self.mesh(name,verts,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
 def ring(self,name,x,y,z,r,mat=0,depth=.06,inner=.72):
  verts=[]
  for zz,rr in [(z+depth,r),(z,r),(z,r*inner),(z+depth,r*inner)]:
   verts += [(x+rr*math.cos(i*math.tau/16),y+rr*math.sin(i*math.tau/16),zz) for i in range(16)]
  return self.mesh(name,verts,[(j*16+i,j*16+(i+1)%16,((j+1)%4)*16+(i+1)%16,((j+1)%4)*16+i) for j in range(4) for i in range(16)],mat)
 def panel(self,name,at,size,mat=4):return self.box(name,at,size,mat)
 def lens(self,x,y,z,r=.08):
  self.ring('OpticRim',x,y,z,r,1,r*.3);self.tube('Optic',(x,y,z+.002),(x,y,z+.018),r*.68,4)
 def core(self,name,at,size,mat=1):
  src=bpy.data.objects['STPropSource_'+name];o=src.copy();o.data=src.data.copy();bpy.context.collection.objects.link(o);o.hide_set(False)
  o.name=self.prefix+'CC0_'+name;o.parent=self.parent;o.location=(0,0,0);o.rotation_euler=(0,0,0);o.scale=(1,1,1)
  lo=[min(v.co[i] for v in o.data.vertices) for i in range(3)];hi=[max(v.co[i] for v in o.data.vertices) for i in range(3)]
  target=cv(at);dims=(size[0],size[2],size[1])
  for v in o.data.vertices:v.co=Vector(tuple(target[i]+(v.co[i]-(lo[i]+hi[i])*.5)/max(.001,hi[i]-lo[i])*dims[i] for i in range(3)))
  o.data.materials.clear();o.data.materials.append(mats[mat]);o['atlas_cell']=mat
  for p in o.data.polygons:p.material_index=0
  return o
 def pivot(self,height):
  self.head=bpy.data.objects.new(self.prefix+'Head',None);bpy.context.collection.objects.link(self.head);self.head.parent=self.root;self.head.location=cv((0,height,0));self.parent=self.head
 def finish(self):
  parts=[o for o in self.root.children_recursive if o.type=='MESH']
  for o in parts:
   bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
   uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap');cell=min(3,int(o.get('atlas_cell',0)))
   for poly in o.data.polygons:
    drop=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=drop];values=[o.data.vertices[o.data.loops[i].vertex_index].co for i in poly.loop_indices]
    lo=[min(v[a] for v in values) for a in axes];hi=[max(v[a] for v in values) for a in axes];span=[max(.001,hi[i]-lo[i]) for i in range(2)]
    tile=0
    if poly.area>.025 and max(span)/min(span)<7:tile=2 if max(span)/min(span)<1.8 and poly.index%4==0 else 1
    if 'CC0' in o.name or 'Vent' in o.name:tile=3 if poly.area>.08 else 0
    for li,v in zip(poly.loop_indices,values):uv.data[li].uv=((tile+.035+(v[axes[0]]-lo[0])/span[0]*.93)/4,(3-cell+.035+(v[axes[1]]-lo[1])/span[1]*.93)/4)
  for parent in [self.root]+([self.head] if self.head else []):
   items=[o for o in parent.children if o.type=='MESH']
   for o in bpy.context.selected_objects:o.select_set(False)
   for o in items:o.select_set(True)
   bpy.context.view_layer.objects.active=items[0]
   if len(items)>1:bpy.ops.object.join()
   items[0].name=self.prefix+('Body' if parent==self.root else 'HeadMesh')
  for o in bpy.context.selected_objects:o.select_set(False)
  self.root.select_set(True)
  for o in self.root.children_recursive:o.select_set(True)
  bpy.ops.export_scene.gltf(filepath=str(OUT/(self.kind+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
  bounds=[o.matrix_world@Vector(v) for o in self.root.children_recursive if o.type=='MESH' for v in o.bound_box]
  return {'vertices':sum(len(o.data.vertices) for o in self.root.children_recursive if o.type=='MESH'),'bounds_blender':[[round(f(v[i] for v in bounds),4) for i in range(3)] for f in [min,max]]}
report={}
for kind in KINDS:
 m=Model(kind)
 if kind=='station_surround':
  m.box('BSPAlcoveCladding',(0,.94,3.5),(4.04,2.04,3.04),1)
  m.box('SupplyFrontPanel',(0,1.20,1.825),(3.26,.94,.04),0)
  for x in [-1.14,1.14]:m.panel('AlcovePaint',(x,1.2,1.795),(.20,.69,.025),3)
 elif kind.startswith('station_'):
  # Original split pylons/capsule, kept behind the existing open service pad.
  m.box('ServiceMat',(0,-.023,0),(2.9,.04,2.9),2)
  for x in [-1.65,1.65]:
   m.vertical('SplitPylon',[(0,.17,.30),(.25,.20,.32),(2.65,.16,.28),(3,.08,.22)],1,(x,0,1.7))
   m.panel('TeamStripe',(x,1.65,1.365),(.18,1.05,.025),3);m.lens(x,1.4,1.315,.115)
   for y in [.32,.52,2.27,2.48]:m.panel('PylonVent',(x,y,1.395),(.20,.09,.022),2)
  m.box('RearBridge',(0,2.4,1.88),(2.95,.72,.44),1)
  m.vertical('ServiceCapsule',[(1.94,.42,.24),(2.13,.58,.30),(2.71,.48,.30),(2.92,.28,.20)],0,(0,0,1.7))
  m.core('desk_computerScreen',(0,2.40,1.42),(.78,.55,.18),2)
  m.panel('StatusPanel',(0,2.48,1.315),(.44,.14,.026),4)
  if kind=='station_inventory':
   for x in [-.76,.76]:m.tube('RefitArm',(x,2.2,1.68),(x*.75,1.92,1.45),.055,0)
   m.panel('RefitSlot',(0,2.20,1.308),(.56,.05,.029),2)
  elif kind=='station_ammo':
   for x in [-.78,-.52,.52,.78]:m.tube('AmmoFeed',(x,2.33,1.47),(x,2.33,1.30),.085,0)
   m.panel('FeedSlot',(0,2.16,1.30),(.38,.07,.03),2)
  elif kind=='station_command':
   m.ring('CommandEmblem',0,2.40,1.28,.27,0,.035,.88)
   m.panel('CommandUplink',(0,2.91,1.72),(.10,.14,.10),4)
  else:
   m.panel('VehicleDisplay',(0,2.28,1.305),(.32,.09,.026),4)
   for x in [-.18,.18]:m.box('FlightGlyph',(x,2.35,1.285),(.05,.08,.023),0)
 elif kind in ['generator','portable_generator','solar']:
  # These are surface housings for the pre-existing BSP/native solid cover.
  w,h,d=(6.06,3.04,3.25) if kind=='generator' else (5.82,2.82,2.02)
  z=-.50 if kind=='generator' else 0
  m.box('Housing',(0,0,z),(w,h,d),1)
  if kind=='solar':
   for x in [-2.2,-1.1,0,1.1,2.2]:
    m.box('PanelFrame',(x,0,1.025),(1.04,2.6,.035),0)
    m.box('Photovoltaic',(x,0,1.047),(.89,2.43,.012),2)
    for y in [-.9,-.6,-.3,0,.3,.6,.9]:m.panel('CellGrid',(x,y,1.058),(.90,.012,.009),1)
   m.core('machine_generator',(0,-1.12,0),(2.8,.5,1.9),1)
  else:
   front=z+d*.5
   m.core('machine_generatorLarge',(0,0,front+.05),(3.4,2.75,.30),1)
   for x in [-w*.37,w*.37]:
    m.vertical('ArmourPillar',[(-h*.5,.36,.15),(-h*.34,.44,.22),(h*.40,.33,.21),(h*.5,.24,.13)],0,(x,0,front))
    for y in [-.9,-.6,-.3,0,.3,.6,.9]:m.box('CoolingVent',(x,y,front+.225),(.40,.11,.025),2)
   for x in [-.48,0,.48]:m.box('PowerCell',(x,.09,front+.225),(.23,1.72,.06),4)
   m.panel('TeamBand',(0,-1.15,front+.23),(1.65,.15,.04),3)
 elif kind in ['base_sensor','large_sensor']:
  m.box('LegacyPlinth',(0,1,0),(4.62,2.02,4.62),1)
  m.vertical('PlinthShoulder',[(1.98,2.32,2.32),(2.22,1.90,1.90),(2.4,.61,.61)],0)
  m.vertical('Mast',[(2,.47,.47),(4.6,.47,.47),(5.95,.30,.35)],1)
  # The original three dish motif wraps the retained Stonehenge sensor beam.
  m.box('LegacySensorBeam',(0,5,0),(7.42,2.02,1.22),1)
  for x,y,r in [(-2.48,4.83,.95),(2.48,4.83,.95),(0,5.45,.83)]:
   m.ring('DishLip',x,y,-.84,r,0,.20,.76)
   m.tube('DishWell',(x,y,-.62),(x,y,-.81),r*.76,2)
   m.tube('DishFeed',(x,y,-.84),(x,y,-1.02),r*.19,4)
  for x in [-1.18,1.18]:m.panel('SensorTeam',(x,5,-.625),(.35,1.0,.025),3)
  if kind=='large_sensor':
   for x in [-2.0,2.0]:m.core('satelliteDish_detailed',(x,1.9,1.75),(1.1,.9,.9),1)
 elif kind.startswith('fixed_'):
  typ=kind.removeprefix('fixed_');mini=typ=='mini';height=1.35 if mini else 2.55;scale=.56 if mini else 1
  m.vertical('ArmouredFoot',[(0,1.55*scale,1.55*scale),(.22*scale,1.58*scale,1.58*scale),(.60*scale,1.16*scale,1.16*scale)],0)
  m.tube('Bearing',(0,.55*scale,0),(0,.85*scale,0),.73*scale,1)
  m.vertical('AngledYoke',[(.76*scale,.65*scale,.57*scale),(height-.45,.42*scale,.49*scale),(height-.12,.67*scale,.45*scale)],1)
  for x in [-.75*scale,.75*scale]:m.panel('TeamShoulder',(x,.44*scale,-1.20*scale),(.37*scale,.19*scale,.05),3)
  m.pivot(height)
  if typ in ['fusion','mini']:
   m.core('turret_double' if typ=='fusion' else 'turret_single',(0,-.08,.1),(2.2*scale,.75*scale,1.1*scale),1)
   m.vertical('EmitterCarapace',[(-.38*scale,.96*scale,.64*scale),(.15*scale,1.15*scale,.71*scale),(.43*scale,.62*scale,.49*scale)],1)
   for x in ([-.54,.54] if typ=='fusion' else [0]):
    m.tube('FusionSleeve',(x,0,-.38),(x,0,-1.90),.25*scale,0)
    m.ring('FusionMuzzle',x,0,-2.07,.25*scale,1,.12)
    m.tube('FusionCore',(x,0,-2.045),(x,0,-2.06),.13*scale,4)
   for x in [-.80*scale,.80*scale]:m.panel('UpperStripe',(x,.1,-.72*scale),(.23*scale,.15*scale,.03),3)
  elif typ=='missile':
   m.box('LauncherTrunnion',(0,-.1,.08),(1.8,.62,1),1)
   for x in [-.61,.61]:
    m.vertical('MissilePod',[(-.44,.45,.74),(.64,.47,.77),(.98,.34,.58)],0,(x,0,-.27))
    for y in [-.14,.28,.70]:
     m.ring('LaunchTube',x,y,-1.065,.16,1,.08);m.tube('DarkTube',(x,y,-.97),(x,y,-1.055),.11,2)
   m.tube('CentreEmitter',(0,0,-.42),(0,0,-2.05),.12,1);m.lens(0,0,-2.07,.13)
  elif typ=='elf':
   m.vertical('ScorpionHood',[(-.37,.60,.49),(.30,.69,.62),(.6,.56,.55)],1,(0,0,.20))
   m.box('CoilSpine',(0,0,-.73),(.62,.60,1.60),2)
   for z in [-.30,-.60,-.90,-1.2]:m.ring('InductionCoil',0,0,z,.46,0,.065,.85)
   for x in [-.52,.52]:
    m.tube('EmitterFork',(x,-.13,-.27),(x*.68,0,-1.90),.10,1);m.lens(x*.68,0,-2.03,.12)
   m.tube('FluxEmitter',(0,0,-1.33),(0,0,-2.08),.12,4)
  else:
   m.core('turret_single',(0,-.12,.20),(1.9,.76,1.20),1)
   for x in [-.86,.86]:m.tube('MortarYoke',(x,-.39,.37),(x,.35,-.25),.14,0)
   m.tube('MortarBreech',(0,0,.52),(0,0,-.48),.53,1)
   m.tube('MortarBarrel',(0,0,-.45),(0,0,-1.9),.40,0)
   m.ring('MortarLip',0,0,-2.07,.47,1,.17,.70)
   m.tube('MortarBore',(0,0,-1.88),(0,0,-2.06),.30,2)
  m.lens(0,.34 if typ!='mini' else .18,-.80 if typ!='mini' else -.44,.10)
 elif kind=='beacon':
  m.vertical('BeaconCapsule',[(-.11,.09,.09),(-.06,.13,.13),(.09,.13,.13),(.12,.08,.08)],1)
  m.box('BeaconSignal',(0,.125,0),(.12,.012,.12),4)
  for x in [-.10,.10]:m.panel('BeaconPaint',(x,0,-.12),(.035,.10,.013),3)
 else:
  # Compact stake bases distinguish deployed equipment from large fixed mounts.
  h={'turret':.76,'camera':.47,'inventory':.58,'ammo_station':.31,'pulse':.72,'motion':.18,'remote_jammer':.36}[kind]
  r=.20 if kind in ['turret','inventory','ammo_station'] else .15
  m.vertical('GroundSpike',[(0,r*.24,r*.24),(.12,r*.70,r*.70),(h,r,r)],1)
  m.vertical('FootCollar',[(.04,r*.8,r*.8),(.12,r*1.15,r*1.15),(.17,r,r)],0)
  if kind=='turret':
   m.tube('TurretBearing',(0,.69,0),(0,.78,0),.25,0)
   # Existing launch axis is y=1.2; the rotating barrel axis matches it.
   m.pivot(1.15)
   m.core('turret_single',(0,-.20,.08),(.47,.34,.42),1)
   m.vertical('ClaptrapShield',[(-.35,.24,.20),(-.04,.26,.21),(.05,.16,.17)],1,(0,0,.08))
   for x in [-.095,0,.095]:
    m.tube('ClaptrapBarrel',(x,.05,-.08),(x,.05,-.45),.037,0)
    m.ring('ClaptrapBore',x,.05,-.46,.039,2,.035)
   m.panel('TurretPaint',(0,-.07,-.19),(.27,.08,.03),3);m.lens(0,.0,-.20,.045)
  elif kind=='camera':
   m.pivot(.57)
   m.vertical('CameraShield',[(-.1,.20,.17),(.08,.23,.18),(.14,.16,.15)],1)
   m.lens(0,0,-.272,.10);m.panel('CameraPaint',(.17,.025,-.19),(.04,.10,.02),3)
  elif kind in ['inventory','ammo_station']:
   inv=kind=='inventory';cy=1.0 if inv else .53;width=.56 if inv else .55
   m.box('SupplyBridge',(0,cy,.02),(width*1.85,.13,.19),1)
   for x in [-width,width]:
    m.vertical('RemotePylon',[(cy-.28,.07,.1),(cy+.34,.06,.1),(cy+.40,.025,.05)],0,(x,0,.04))
    m.lens(x,cy,-.083,.052);m.panel('SupplyStripe',(x,cy+.14,-.075),(.066,.12,.024),3)
   m.vertical('SupplyCapsule',[(h-.08,.17,.16),(cy+.09,.22,.19),(cy+.25,.12,.12)],1)
   m.core('desk_computerScreen',(0,cy,-.155),(.30,.33,.075),2)
   m.panel('SupplyScreen',(0,cy+.06,-.20),(.18,.08,.02),4)
   for x in [-.11,.11]:m.panel('SupplySlot',(x,cy-.07,-.20),(.08,.035,.02),0)
  elif kind=='pulse':
   m.tube('SensorFork',(-.21,.85,0),(.21,.85,0),.045,0)
   for x,y in [(-.22,.97),(.22,.97),(0,1.17)]:
    m.ring('ArgusDish',x,y,-.10,.12,1,.045,.73);m.tube('ArgusWell',(x,y,-.05),(x,y,-.096),.09,2);m.lens(x,y,-.12,.026)
   m.panel('SensorPaint',(0,.63,-.155),(.14,.13,.022),3)
  elif kind=='motion':
   m.vertical('MotionCone',[(.16,.19,.19),(.30,.25,.25),(.43,.17,.17)],1)
   m.panel('MotionCap',(0,.442,0),(.20,.026,.20),3)
   for x in [-.14,.14]:m.lens(x,.31,-.185,.055)
  else:
   m.vertical('BuzzboxSkirt',[(.3,.13,.13),(.52,.35,.35),(.65,.22,.22),(.72,.14,.14)],1)
   m.vertical('JammerAerial',[(.70,.11,.09),(.96,.07,.055),(1.0,.015,.018)],0)
   m.panel('JammerLight',(0,.724,0),(.19,.02,.13),4)
   for x in [-.22,.22]:m.panel('JammerPaint',(x,.52,-.30),(.10,.09,.025),3)
 report[kind]=m.finish()
 # Arrange editable models after export; transforms never enter the game assets.
 i=KINDS.index(kind);m.root.location=cv(((i%5)*9,0,(i//5)*10+18))
for o in bpy.data.objects:
 if o.name.startswith('STPropSource_'):o.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/tribes/prop-sources/st-equipment.blend'),copy=True)
(ROOT/'test-results/st-equipment-design/blender-audit.json').write_text(json.dumps(report,indent=2))
print('ST_EQUIPMENT_MODELS',len(report),'vertices',sum(v['vertices'] for v in report.values()))
for o in bpy.context.selected_objects:o.select_set(False)
for o in bpy.data.objects:
 if o.name.startswith('STProp_'):o.select_set(True)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  with bpy.context.temp_override(area=area,region=next(r for r in area.regions if r.type=='WINDOW')):bpy.ops.view3d.view_selected()
