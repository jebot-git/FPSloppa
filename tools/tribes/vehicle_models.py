"""Reference-led Tribes vehicle remodel, run in Blender MCP.
Original art: independent shapes/SVG panels. CC0 Kenney mesh remains the keel.
Godot coordinates are authored directly, then converted to Blender Z-up.
"""
import bpy, bmesh, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(globals().get('VEHICLE_PROJECT', (Path(__file__).resolve().parents[2] if '__file__' in globals() else Path('/home/blux/Documents/FPSloppa'))))
KINDS=globals().pop('VEHICLE_KINDS',['scout','lpc','hpc'])
image=bpy.data.images.load(str(ROOT/'deathmatch/vehicles/tribes/hull-atlas.png'),check_existing=False)
image.pack()
materials=[]
for name,colour,emission in [('Bronze',(1,1,1,1),False),('Gunmetal',(1,1,1,1),False),('Recess',(1,1,1,1),False),('TeamPanel',(.5,.10,.06,1),False),('Engine',(.04,.42,.65,1),True)]:
 m=bpy.data.materials.new('TribesOriginal_'+name);m.diffuse_color=colour;m.use_nodes=True
 node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');node.inputs['Base Color'].default_value=colour;node.inputs['Metallic'].default_value=.25;node.inputs['Roughness'].default_value=.67
 if not emission:
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
  m.node_tree.links.new(tex.outputs['Color'],node.inputs['Base Color'])
 else:
  node.inputs['Emission Color'].default_value=colour;node.inputs['Emission Strength'].default_value=1.3
 materials.append(m)
source=bpy.data.objects.get('craft_speederA')
if source is None:
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'tools/tribes/vehicle-sources/craft_speederA.glb'))
 source=bpy.data.objects['craft_speederA']
def coord(p):return (p[0],-p[2],p[1])
roots=[]
for kind in KINDS:
 prefix={'scout':'STScout','lpc':'STLPC','hpc':'STHPC'}[kind]
 for o in list(bpy.data.objects):
  if o.name.startswith(prefix):bpy.data.objects.remove(o,do_unlink=True)
 root=bpy.data.objects.new(prefix,None);bpy.context.collection.objects.link(root);roots.append(root)
 def mesh(name,verts,faces,mat=0):
  data=bpy.data.meshes.new(prefix+'_'+name);data.from_pydata([coord(v) for v in verts],[],faces);data.update()
  o=bpy.data.objects.new(prefix+'_'+name,data);bpy.context.collection.objects.link(o);o.parent=root
  o.data.materials.append(materials[mat]);o['atlas_cell']=mat
  return o
 def box(name,at,size,mat=0):
  x,y,z=at;a,b,c=[s/2 for s in size]
  return mesh(name,[(x+u*a,y+v*b,z+w*c) for u,v,w in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)
 def plate(name,points,depth=(0,-.1,0),mat=0):
  n=len(points);verts=points+[tuple(p[i]+depth[i] for i in range(3)) for p in points]
  return mesh(name,verts,[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
 def loft(name,sections,mat=0,x=0):
  verts=[]
  for z,w,lo,hi in sections:
   b=min(.15,w*.28,(hi-lo)*.22)
   verts += [(x+a,h,z) for a,h in [(-w,lo+b),(-w+b,lo),(w-b,lo),(w,lo+b),(w,hi-b),(w-b,hi),(-w+b,hi),(-w,hi-b)]]
  faces=[tuple(range(7,-1,-1)),tuple(range(len(verts)-8,len(verts)))]
  for j in range(len(sections)-1):
   for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
  return mesh(name,verts,faces,mat)
 def tube(name,start,end,radius,mat=1,n=12):
  a=Vector(start);b=Vector(end);direction=(b-a).normalized();u=direction.cross(Vector((0,1,0)))
  if u.length<.01:u=direction.cross(Vector((0,0,1)))
  u.normalize();v=direction.cross(u);verts=[]
  for centre in [a,b]:
   verts.extend([tuple(centre+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for i in range(n)])
  return mesh(name,verts,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
 def engine(x,y,z,r=.32):
  tube('ThrusterCollar',(x,y,z-.28),(x,y,z+.20),r,0)
  tube('ThrusterRim',(x,y,z+.20),(x,y,z+.24),r*.85,1)
  tube('ThrusterRecess',(x,y,z+.241),(x,y,z+.25),r*.70,2)
  tube('ThrusterCore',(x,y,z+.251),(x,y,z+.26),r*.40,4)
 def liftjet(x,z,y):
  tube('VTOLHousing',(x,y+.22,z),(x,y-.08,z),.23,1)
  tube('VTOLLight',(x,y-.08,z),(x,y-.10,z),.16,4)
 def cockpit(x,y,z):
  # Positions retained from the working mounts; keep forward sightline clear.
  box('SeatPedestal',(x,y+.2,z+.16),(.58,.4,.52),2)
  box('PilotCushion',(x,y+.45,z+.16),(.72,.16,.62),2)
  loft('PilotBack',[(z+.40,.42,y+.38,y+1.08),(z+.61,.36,y+.40,y+.96)],2,x)
  loft('InstrumentCowl',[(z-1.05,.34,y+.26,y+.69),(z-.72,.58,y+.2,y+.87),(z-.55,.50,y+.30,y+.8)],1,x)
  box('PilotDisplay',(x,y+.878,z-.76),(.38,.016,.18),4)
  for side in [-1,1]:
   tube('ConsoleBrace',(x+side*.45,y+.10,z-.66),(x+side*.45,y+.69,z-.61),.045,1)
   tube('ControlPedestal',(x+side*.49,y+.20,z-.08),(x+side*.49,y+.88,z-.10),.045,1)
   box('ControlGrip',(x+side*.49,y+.9,z-.10),(.10,.16,.16),2)
 # Retain a refinished real-asset keel, reshaped below the reconstructed armour.
 body=source.copy();body.data=source.data.copy();bpy.context.collection.objects.link(body);body.name=prefix+'_Keel';body.parent=root;body.location=(0,0,0);body.rotation_euler=(0,0,0);body.scale=(1,1,1);body['atlas_cell']=1
 lo=Vector(tuple(min(v.co[i] for v in body.data.vertices) for i in range(3)));hi=Vector(tuple(max(v.co[i] for v in body.data.vertices) for i in range(3)))
 dims={'scout':(1.25,4.9,.36),'lpc':(2.2,6.0,.46),'hpc':(2.8,7.7,.50)}[kind]
 for v in body.data.vertices:v.co=Vector(((v.co.x-(hi.x+lo.x)/2)/(hi.x-lo.x)*dims[0],(v.co.y-(hi.y+lo.y)/2)/(hi.y-lo.y)*dims[1],(v.co.z-(hi.z+lo.z)/2)/(hi.z-lo.z)*dims[2]-.22))
 body.data.materials.clear();body.data.materials.append(materials[1])
 for poly in body.data.polygons:poly.material_index=0
 if kind=='scout':
  loft('TaperedFuselage',[(-2.78,.10,-.16,.10),(-2.15,.43,-.34,.49),(-1.05,.58,-.40,.48),(.45,.52,-.40,.23),(1.5,.62,-.35,.48),(2.45,.28,-.22,.22)],0)
  loft('NoseCrown',[(-2.64,.09,.07,.18),(-2.07,.36,.46,.60),(-1.5,.34,.48,.65),(-1.14,.24,.44,.52)],1)
  for side in [-1,1]:
   plate('SweptWing',[(side*.47,-.06,-.52),(side*1.94,.06,-.12),(side*2,.30,.96),(side*.57,.01,.64)],(0,-.12,0),1)
   plate('WingBronzeInset',[(side*.61,.014,-.26),(side*1.78,.10,.05),(side*1.85,.26,.81),(side*.71,.077,.55)],(0,-.018,0),0)
   plate('WingTeamTip',[(side*1.77,.175,.38),(side*1.94,.18,.38),(side*1.96,.307,.90),(side*1.79,.257,.80)],(0,-.017,0),3)
   plate('ForwardCanard',[(side*.35,-.08,-1.83),(side*1.17,-.03,-1.2),(side*.46,-.03,-1.0)],(0,-.1,0),0)
   loft('AftEnginePod',[(.67,.20,-.32,.39),(1.35,.31,-.36,.48),(2.25,.23,-.20,.31)],0,side*.61)
   plate('PairedTailFin',[(side*.51,.25,.94),(side*.73,1.64,1.92),(side*.78,1.80,2.38),(side*.57,.17,2.05)],(side*.09,0,0),0)
   engine(side*.61,.02,2.27,.22);liftjet(side*.68,1.22,-.30)
   # Existing muzzle coordinates are unchanged and visibly terminate here.
   tube('RocketTube',(side*1.05,.02,-1.64),(side*1.05,.02,-2.86),.13,1)
   tube('RocketMouth',(side*1.05,.02,-2.86),(side*1.05,.02,-2.90),.105,2)
   plate('LauncherBrace',[(side*.37,-.04,-1.70),(side*1.12,-.04,-1.70),(side*1.12,-.04,-2.05),(side*.43,-.04,-2.13)],(0,-.10,0),0)
  cockpit(0,.15,.25)
 else:
  heavy=kind=='hpc';W=3.0 if heavy else 2.4;L=4.4 if heavy else 3.5;y=.75 if heavy else .7
  pilot=-2.6 if heavy else -1.9
  # A low, clipped diamond hull instead of the earlier rectangular barge.
  footprint=[(-W*.31,y-.24,-L),(W*.31,y-.24,-L),(W*.86,y-.13,-L*.60),(W*.84,y-.13,L*.68),(W*.61,y-.13,L),(-W*.61,y-.13,L),(-W*.84,y-.13,L*.68),(-W*.86,y-.13,-L*.60)]
  plate('ClippedArmourHull',footprint,(0,-.72,0),0)
  # Broad sloping nose shoulders frame the pilot rather than leaving a flat bow.
  for side in [-1,1]:
   plate('NoseShoulder',[(side*.39,y+.09,-L+.06),(side*W*.33,y-.20,-L+.06),(side*W*.82,y-.09,-L*.60),(side*W*.69,y+.40,pilot+.18),(side*.63,y+.38,pilot+.18),(side*.63,y+.23,pilot-.63)],(0,-.10,0),0)
  # Faceted armoured sponsons leave open bays at the established passenger points.
  for side in [-1,1]:
   sx=side*(W-.37)
   loft('OutboardArmour',[(-L+.4,.22,.06,.62),(-L*.56,.34,-.12,1.01),(L*.62,.31,-.07,.98),(L-.15,.23,.02,.65)],0,sx)
   plate('ForwardWinglet',[(side*(W-.55),.2,-L+.95),(side*W,.12,-L+.35),(side*(W-.03),.18,-L*.30),(side*(W-.54),.3,-L*.12)],(0,-.15,0),1)
   # Detached-looking original pods are joined with thick visible pylons.
   for z in ([-L*.62,L*.64] if heavy else [L*.63]):
    box('PodPylon',(side*(W-.52),.08,z),(.84,.24,.44),1)
    loft('LiftPod',[(z-.43,.26,-.42,.34),(z-.26,.36,-.48,.50),(z+.35,.36,-.46,.42),(z+.50,.25,-.36,.19)],0,side*(W-.35))
    liftjet(side*(W-.35),z,-.48)
    tube('TopTurbineRim',(side*(W-.35),.501,z),(side*(W-.35),.52,z),.18,1)
    tube('TopTurbineCore',(side*(W-.35),.521,z),(side*(W-.35),.525,z),.125,2)
   engine(side*(W-.44),.12,L-.18,.29)
   box('TeamFlank',(side*(W-.018),.58,.30),(.026,.21,L*.55),3)
  # Sloping central cowl matches the dark humped silhouettes in the manual.
  loft('CentreCanopy',[(pilot+.70,.39,y+.04,y+.88),(pilot+1.12,.62,y+.08,y+1.18),(L*.50,.56,y+.05,y+.98),(L*.70,.40,y-.02,y+.55)],1)
  # Bright edge ribs wrap the cowl without becoming a cockpit roof.
  for side in [-1,1]:tube('CanopyRib',(side*.44,y+.83,pilot+.77),(side*.51,y+1.01,L*.47),.026,0)
  loft('NoseArmour',[(-L,.24,y-.02,y+.15),(-L+.55,.78,y-.1,y+.37),(pilot-.75,.61,y-.06,y+.51)],0)
  cockpit(0,y,pilot)
  seats=[(-1.65,.2),(1.65,.2),(-1.65,2.1),(1.65,2.1)] if heavy else [(-1.35,.7),(1.35,.7)]
  for i,(x,z) in enumerate(seats):
   box('RecessedPassengerFloor',(x,y-.026,z),(1.05,.048,1.03),2)
   box('PassengerRearBulkhead',(x,y+.40,z+.62),(1.02,.82,.14),0)
   box('PassengerBackPad',(x,y+.43,z+.54),(.75,.56,.025),2)
   box('PassengerTeamCushion',(x,y+.016,z+.30),(.72,.035,.28),3)
   for side in [-1,1]:box('BayCheek',(x+side*.50,y+.12,z),(.085,.25,1.02),0)
  if heavy:
   loft('RaisedAftHull',[(L*.67,W*.60,y-.03,y+.40),(L*.83,W*.60,y-.05,y+.75),(L,W*.49,y-.25,y+.50)],0)
  else:
   loft('RearShoulder',[(L*.66,1.33,y-.04,y+.18),(L*.88,1.24,y-.13,y+.36),(L,1.0,y-.18,y+.14)],0)
 # Consistent outward normals and panel UVs: one original atlas, mipmapped on import.
 for o in list(root.children):
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
  uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
  cell=min(int(o.get('atlas_cell',0)),3)
  for poly in o.data.polygons:
   normal=poly.normal;drop=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=drop]
   values=[o.data.vertices[o.data.loops[i].vertex_index].co for i in poly.loop_indices]
   lo=[min(v[a] for v in values) for a in axes];hi=[max(v[a] for v in values) for a in axes]
   span=[max(hi[i]-lo[i],.001) for i in range(2)]
   aspect=max(span)/min(span)
   tile=0
   if poly.area>.12 and aspect<7:
    tile=1
    if aspect<1.9 and poly.index%3==0:tile=2
    if any(n in o.name for n in ['Recessed','BackPad','Instrument','Keel']):tile=3
   for li,v in zip(poly.loop_indices,values):
    u=(v[axes[0]]-lo[0])/span[0];w=(v[axes[1]]-lo[1])/span[1]
    uv.data[li].uv=((tile+.035+u*.93)/4,(3-cell+.035+w*.93)/4)
 # Consolidate static detail to five material surfaces plus separate grips.
 for o in bpy.context.selected_objects:o.select_set(False)
 for o in root.children:
  o.hide_set(False)
  if 'ControlGrip' not in o.name:o.select_set(True)
 bpy.context.view_layer.objects.active=body;bpy.ops.object.join();body.name=prefix+'_Hull'
 for o in bpy.context.selected_objects:o.select_set(False)
 root.select_set(True)
 for o in root.children:o.select_set(True)
 bpy.context.view_layer.objects.active=body
 bpy.ops.export_scene.gltf(filepath=str(ROOT/f'deathmatch/vehicles/tribes/{kind}.glb'),export_format='GLB',use_selection=True,export_apply=True)
 bounds=[o.matrix_world@Vector(v) for o in root.children for v in o.bound_box]
 print('VEHICLE_REMODEL',kind,'meshes',len(root.children),'verts',sum(len(o.data.vertices) for o in root.children),'bounds',[[round(f(v[i] for v in bounds),3) for i in range(3)] for f in [min,max]])
# Editable hierarchy and neutral viewing arrangement, not part of GLB exports.
for kind in ['scout','lpc','hpc']:
 r=bpy.data.objects.get({'scout':'STScout','lpc':'STLPC','hpc':'STHPC'}[kind])
 if r:r.location.x={'scout':-7,'lpc':0,'hpc':8}[kind]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/tribes/vehicle-sources/vehicles.blend'),copy=True)
for o in bpy.data.objects:
 if o.name in bpy.context.view_layer.objects:o.hide_set(not any(o==r or o.parent==r for r in roots))
for o in bpy.context.selected_objects:o.select_set(False)
for r in roots:
 r.select_set(True)
 for o in r.children:o.select_set(True)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  with bpy.context.temp_override(area=area,region=next(r for r in area.regions if r.type=='WINDOW')):bpy.ops.view3d.view_selected()
