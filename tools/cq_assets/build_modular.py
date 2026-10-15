"""Author the CQ weapon family from Felix Kütt's original carbine, without collapse decimation.
Blender: --python build_modular.py -- SOURCE_DIR OUTPUT_DIR [--only NAME] [--optimized] [--audit]
"""
import bpy,bmesh,math,json,sys
from pathlib import Path
from mathutils import Vector,Matrix
args=sys.argv[sys.argv.index('--')+1:];src=Path(args[0]).resolve();out=Path(args[1]).resolve()
optimized='--optimized' in args
repo=Path(__file__).resolve().parents[2];authoring=Path(__file__).with_name('optimized_authoring' if optimized else 'modular_authoring');authoring.mkdir(exist_ok=True)
manifest=json.loads((out/'manifest.json').read_text())
for obsolete in ('akira','beam_rifle'):manifest.pop(obsolete,None)
def clear():
 for obj in list(bpy.context.scene.objects):bpy.data.objects.remove(obj,do_unlink=True)
 if 'materials' in globals():
  for material in list(bpy.data.materials):
   if material not in materials and material.users==0:bpy.data.materials.remove(material)
  for mesh in list(bpy.data.meshes):
   if mesh.users==0:bpy.data.meshes.remove(mesh)
  for image in list(bpy.data.images):
   if image!=palette and image.users==0:bpy.data.images.remove(image)
def select_enum(owner,property_name,value):
 return next(e.identifier for e in owner.bl_rna.properties[property_name].enum_items if e.identifier==value)
def finish(name,color,metallic=0.0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 node.inputs['Base Color'].default_value=(*color,1);node.inputs['Roughness'].default_value=.32;node.inputs['Metallic'].default_value=metallic
 m.diffuse_color=(*color,1);return m
# These colors are sampled from the editable palette painted through Krita MCP.
palette=bpy.data.images.load(str(Path(__file__).with_name('modular_finish.png')))
def sample(x,y):
 index=((palette.size[1]-1-y)*palette.size[0]+x)*4
 rgb=palette.pixels[index:index+3]
 return [c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
paint=finish('CQ safety orange',sample(256,256));black=finish('CQ graphite',sample(768,256));white=finish('CQ cell ceramic',sample(256,768));steel=finish('CQ machined steel',sample(768,768),.25)
materials=[paint,black,white,steel]
clear()
with bpy.data.libraries.load(str(src/'rifle/rifle.blend'),link=False) as (a,b):b.objects=a.objects
for obj in b.objects:
 if obj and obj.type=='MESH':
  bpy.context.collection.objects.link(obj);obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4);obj.modifiers.clear()
body=next(o for o in bpy.context.scene.objects if o.name.startswith('Rifle_Body'))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
seeds={}
for obj in bpy.context.scene.objects:
 lo=min(v.co.y for v in obj.data.vertices);hi=max(v.co.y for v in obj.data.vertices)
 name='Cell' if obj.name.startswith('Rifle_Clip') else 'Receiver' if lo<-5 else 'Bridge' if lo<2 else 'Housing' if lo<5 else 'Collar' if hi<12.1 else 'Bore'
 seeds[name]=([tuple(v.co) for v in obj.data.vertices],[tuple(f.vertices) for f in obj.data.polygons])
def part(name,seed,scale,mapper=lambda v:v):
 verts,faces=seeds[seed];mesh=bpy.data.meshes.new(name);mesh.from_pydata([mapper(Vector(v)) for v in verts],[],faces);mesh.update()
 mesh.materials.clear()
 for m in materials:mesh.materials.append(m)
 for face in mesh.polygons:
  face.material_index=1 if seed in ('Bore','Collar') else 3 if seed=='Bridge' else 0
  if seed=='Housing' and face.normal.z<-.6:face.material_index=1
  if seed=='Receiver' and face.center.z<.1 and face.center.y>-.5:face.material_index=1
  if seed=='Cell':face.material_index=3 if face.center.z<0 else 1
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
 for v in mesh.vertices:v.co=(v.co-Vector((0,-3,-2)))*scale
 return obj
def ranged(v,a,b,c,d):
 v.y=c+(v.y-a)*(d-c)/(b-a);return v
def box(name,p,size,material,scale,bevel=True):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(Vector(p)-Vector((0,-3,-2)))*scale)
 obj=bpy.context.object;obj.name=name;obj.scale=Vector(size)*scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);obj.data.materials.append(material);return obj

def tube(name,y,z,r,length,scale,x=0,material=None):
 # An open bore with an actual wall and lip, instead of a capped cylinder.
 n=8 if optimized else 16;verts=[]
 for yy,rr in [(y-length/2,r),(y+length/2,r),(y-length/2,r*.65),(y+length/2,r*.65)]:
  for i in range(n):
   t=math.tau*i/n;verts.append(tuple((Vector((x+rr*math.cos(t),yy,z+rr*math.sin(t)))-Vector((0,-3,-2)))*scale))
 faces=[]
 for i in range(n):
  j=(i+1)%n;faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(n+i,n+j,3*n+j,3*n+i),(i,2*n+i,2*n+j,j)])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(material or black);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj

def stock(scale,front=-5.5):
 # Keep the butt in place and extend both rails into the shortened pistol receiver.
 center=(front-10.5)/2;length=front+10.5
 return [box('Skeleton stock upper',(0,center,1.65),(1.35,length,.55),black,scale),box('Skeleton stock lower',(0,center,.15),(1.35,length,.42),black,scale),box('Stock butt',(0,-10.6,.85),(1.35,.65,2.35),black,scale),box('Orange cheek rest',(0,-7.1,1.95),(1.5,3.6,.55),paint,scale)]
def windows(scale,ys,z=1.15,x=1.72):
 result=[]
 for side in [-1,1]:
  for y in ys:
   result.extend([box('Cell window bezel',(side*x,y,z),(.1,.68,1.28),black,scale),box('White cell window',(side*(x+.065),y,z),(.055,.46,1.02),white,scale)])
 return result

def dot_sight(scale,y=-1.1,z=3.05):
 # Reuse JeanPFP's requested sight, with the common orange/graphite finish.
 with bpy.data.libraries.load(str(src/'red_dot.blend'),link=False) as (a,b):b.objects=a.objects
 result=[o for o in b.objects if o and o.type=='MESH']
 for obj in result:bpy.context.collection.objects.link(obj)
 bpy.context.view_layer.update()
 for obj in result:
  deps=bpy.context.evaluated_depsgraph_get();mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),depsgraph=deps);obj.modifiers.clear();obj.data=mesh;mesh.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
 vertices=[v.co for o in result for v in o.data.vertices]
 lo=Vector([min(v[i] for v in vertices) for i in range(3)]);hi=Vector([max(v[i] for v in vertices) for i in range(3)])
 unit=2.2/(hi.y-lo.y);center=Vector(((hi.x+lo.x)*.5,(hi.y+lo.y)*.5,lo.z))
 for obj in result:
  obj.name='RedDotHousing' if 'Plane' in obj.name else 'RedDotBase'
  obj.data.materials.clear();obj.data.materials.append(paint if obj.name=='RedDotHousing' else black)
  for v in obj.data.vertices:v.co=((v.co-center)*unit+Vector((0,y,z))-Vector((0,-3,-2)))*scale
 return result

def scope(scale):
 result=[box('Scope rear foot',(0,-2.8,3.22),(1.2,.65,.55),black,scale),box('Scope front foot',(0,1.8,3.22),(1.2,.65,.55),black,scale),tube('Scope tube',-.5,4.3,.8,6.8,scale),tube('Scope rear collar',-3.85,4.3,.94,.7,scale,material=paint),tube('Scope front collar',2.85,4.3,.94,.7,scale,material=paint),box('Scope adjustment',(1.05,-.8,4.3),(.5,.7,.7),black,scale)]
 return result

def game_point(p,scale):
 q=(Vector(p)-Vector((0,-3,-2)))*scale;return [q.x,q.z,-q.y]
names=['pistol','scout_pistol','designator','carbine','massacre','smg','assault_rifle','beam_pistol','guided_launcher','burst_pistol']
if '--only' in args:names=args[args.index('--only')+1].split(',')
for name in names:
 clear();scale=.04 if name in ('carbine','smg') else .035
 pistol=name in ('pistol','scout_pistol','designator','beam_pistol','burst_pistol');heavy=name in ('massacre','guided_launcher')
 objects=[]
 if pistol:
  objects.append(part('Receiver','Receiver',scale,lambda v:ranged(v,-6,1,-5.1,-.2)))
  objects.append(part('Bridge','Bridge',scale,lambda v:ranged(v,1,4,-.2,1)))
  objects.append(part('Housing','Housing',scale,lambda v:ranged(v,4,11,1,4.5)))
  objects.append(part('Collar','Collar',scale,lambda v:ranged(v,11,12,4.5,5.4)))
  objects.append(part('Bore','Bore',scale,lambda v:ranged(v,11.9,13,5.3,6.3)))
  if name in ('beam_pistol','burst_pistol','designator'):objects+=windows(scale,[1.55,2.5,3.45])
  objects.append(box('Pistol cell',(0,-3.25,-4.05),(1.18,1.82,.72),black,scale))
  if name in ('beam_pistol','scout_pistol'):
   objects+=scope(scale);objects.append(tube('Beam emitter' if name=='beam_pistol' else 'Suppressor',7.1,1.12,.55 if name=='beam_pistol' else .75,2.1 if name=='beam_pistol' else 3.5,scale))
   if name=='scout_pistol':objects+=stock(scale,front=-4.4)
  elif name=='pistol':
   objects+=[box('Rear iron left',(-.38,-3.6,3.13),(.18,.38,.42),black,scale),box('Rear iron right',(.38,-3.6,3.13),(.18,.38,.42),black,scale),box('Front iron blade',(0,4.0,3.13),(.16,.35,.42),black,scale)]
  else:objects+=dot_sight(scale,y=-1.2)
 else:
  objects.append(part('Receiver','Receiver',scale))
  objects.append(part('Bridge','Bridge',scale))
  end=8.7 if name=='smg' else 12.5 if heavy or name=='assault_rifle' else 11.0
  def housing_mapper(v):
   v=ranged(v,4,11,4,end)
   if heavy:v.x*=1.3;v.z=(v.z-1)*1.35+1
   return v
  objects.append(part('Housing','Housing',scale,housing_mapper))
  if heavy:
   objects+=stock(scale)
   positions=[(-.85,.55),(.85,.55),(0,2.0)] if name=='massacre' else [(0,.3),(0,2.0)]
   for i,(x,z) in enumerate(positions):objects.append(tube('Ordnance bore '+str(i+1),end+.5,z,.78,3.1,scale,x=x))
   objects.append(box('Fixed pack socket',(-1.4,2.4,.55),(1.2,2.15,2.3),black,scale))
   objects.append(box('Side ordnance pack',(-2.25,2.4,.55),(1.55,2.65,2.7),paint,scale));objects.append(box('Pack white band',(-3.07,2.4,.55),(.09,.48,2.5),white,scale))
   objects.append(box('Monitor pedestal',(0,-1.5,3.05),(1.4,.75,1.2),black,scale))
   objects.append(box('Monitor frame',(0,-1.5,4.05),(2.15,.42,1.55),black,scale));objects.append(box('Monitor glass',(0,-1.74,4.05),(1.82,.08,1.2),black,scale))
  else:
   objects.append(part('Collar','Collar',scale,lambda v:ranged(v,11,12,end,end+1)))
   objects.append(part('Bore','Bore',scale,lambda v:ranged(v,11.9,13,end+.9,end+2)))
   objects.append(part('Energy cell' if name!='smg' else 'SMG magazine','Cell',scale))
   objects.append(box('Magazine white band',(0,2.5,-.9),(1.18,.45,.6),white,scale))
   objects+=dot_sight(scale)
   if name=='assault_rifle':objects+=stock(scale)
  objects.append(box('Upper ceramic charge mark',(0,6.2,3.12),(1.1,.72,.12),white,scale))
 # A real movable charging handle, using the common receiver slot.
 handle=None
 if not heavy:
  handle=box('ChargingHandle',(.95,-1.7,1.75),(.8,.75,.38),steel,scale);objects.append(handle)
 # Keep source housing chamfers; optimized receiver edges get one bevel segment.
 for obj in objects:
  bpy.context.view_layer.objects.active=obj
  if optimized:
   bm=bmesh.new();bm.from_mesh(obj.data)
   bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
   bmesh.ops.dissolve_limit(bm,angle_limit=math.radians(.5),verts=list(bm.verts),edges=list(bm.edges),delimit={'MATERIAL'})
   bm.to_mesh(obj.data);bm.free();obj.data.update()
  bevel=obj.modifiers.new('Small manufactured bevel','BEVEL');bevel.width=.045*scale;bevel.segments=1 if optimized else 2;bevel.limit_method=select_enum(bevel,'limit_method','ANGLE');bevel.angle_limit=math.radians(60) if optimized else math.radians(30)
  bevel_name=bevel.name
  if optimized and obj.name!='Receiver':
   obj.modifiers.remove(bevel)
  try:
   if bevel_name in obj.modifiers:bpy.ops.object.modifier_apply(modifier=bevel_name)
  except RuntimeError:obj.modifiers.clear()
  for face in obj.data.polygons:face.use_smooth=True
  obj.data.set_sharp_from_angle(angle=math.radians(35))
  normal=obj.modifiers.new('Area weighted normals','WEIGHTED_NORMAL');normal.keep_sharp=True
  bpy.ops.object.modifier_apply(modifier=normal.name)
 if '--audit' in args:
  rows=[]
  for obj in objects:
   obj.data.calc_loop_triangles();rows.append((obj.name,len(obj.data.loop_triangles)))
  print('GEOMETRY_AUDIT',name,sum(r[1] for r in rows),rows,flush=True);continue
 # Keep the editable individual modules in the Blender authoring file.
 raw_collection=bpy.data.collections.new(name+' editable modules');bpy.context.scene.collection.children.link(raw_collection)
 for obj in objects:
  for collection in list(obj.users_collection):collection.objects.unlink(obj)
  raw_collection.objects.link(obj)
 copies=[]
 for obj in objects:
  c=obj.copy();c.data=obj.data.copy();bpy.context.collection.objects.link(c);copies.append(c)
  group_name='ChargingHandleMesh' if obj==handle else 'InsertedAmmoMesh' if obj.name.startswith(('Side ordnance pack','Pack white band','Energy cell','SMG magazine','Magazine white band','Pistol cell')) else ''
  if group_name:
   group=c.vertex_groups.new(name=group_name);group.add(list(range(len(c.data.vertices))),1,'REPLACE')
 bpy.ops.object.select_all(action='DESELECT')
 for obj in copies:obj.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();target=bpy.context.object;target.name=name
 while target.data.uv_layers:target.data.uv_layers.remove(target.data.uv_layers[0])
 target.data.uv_layers.new(name='CQAtlas');target.data.uv_layers[0].active_render=True
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.012,correct_aspect=False,scale_to_bounds=True);bpy.ops.object.mode_set(mode='OBJECT')
 image=bpy.data.images.new(name+'_albedo',width=1024,height=1024,alpha=False)
 for material in target.data.materials:
  tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;material.node_tree.nodes.active=tex
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.device='CPU'
 scene.render.bake.use_selected_to_active=False;scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=12
 for obj in objects:obj.hide_render=True;obj.hide_set(True)
 bpy.ops.object.bake(type='DIFFUSE')
 baked=finish(name+'_baked',(1,1,1));tex=baked.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;baked.node_tree.nodes.active=tex
 target.data.materials.clear();target.data.materials.append(baked)
 for face in target.data.polygons:face.material_index=0
 shader=next(n for n in baked.node_tree.nodes if n.type=='BSDF_PRINCIPLED');baked.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
 # AO is self-baked with the source collection excluded from render visibility.
 import numpy as np
 ao=bpy.data.images.new(name+'_ao',width=1024,height=1024,alpha=False);ao_node=baked.node_tree.nodes.new('ShaderNodeTexImage');ao_node.image=ao;baked.node_tree.nodes.active=ao_node;scene.cycles.samples=16
 bpy.ops.object.bake(type='AO')
 rgba=np.empty(len(image.pixels),dtype=np.float32);shade=np.empty(len(ao.pixels),dtype=np.float32);image.pixels.foreach_get(rgba);ao.pixels.foreach_get(shade)
 rgba=rgba.reshape((-1,4));shade=shade.reshape((-1,4));rgba[:,:3]*=.72+.28*shade[:,:3];image.pixels.foreach_set(rgba.ravel());image.update()
 baked.node_tree.nodes.remove(ao_node);bpy.data.images.remove(ao)
 image.filepath_raw=str(out/(name+'.png'));image.file_format=select_enum(image,'file_format','PNG');image.save();image.pack()
 # Preserve the movable handle's baked UVs when separating it from the body.
 target.data.calc_loop_triangles();count=len(target.data.loop_triangles)
 if optimized:assert count<1000,(name,count)
 exported=[target]
 if handle:handle.name='EditableChargingHandle'
 for group_name,node_name in [('ChargingHandleMesh','ChargingHandle'),('InsertedAmmoMesh','InsertedAmmo')]:
  group=target.vertex_groups.get(group_name)
  if group is None:continue
  for face in target.data.polygons:face.select=False
  for edge in target.data.edges:edge.select=False
  for vertex in target.data.vertices:vertex.select=any(g.group==group.index for g in vertex.groups)
  bpy.ops.object.select_all(action='DESELECT');target.select_set(True);bpy.context.view_layer.objects.active=target
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
  separated=next(o for o in bpy.context.selected_objects if o!=target);separated.name=node_name
  center=Vector([(min(v.co[i] for v in separated.data.vertices)+max(v.co[i] for v in separated.data.vertices))*.5 for i in range(3)])
  for vertex in separated.data.vertices:vertex.co-=center
  separated.location+=center;exported.append(separated)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in exported:obj.select_set(True)
 bpy.context.view_layer.objects.active=target
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
 bounds=[[min((o.matrix_world@v.co)[i] for o in exported for v in o.data.vertices),max((o.matrix_world@v.co)[i] for o in exported for v in o.data.vertices)] for i in range(3)]
 tip=8.85 if name=='scout_pistol' else 8.15 if name=='beam_pistol' else 6.3 if pistol else end+2.05 if heavy else end+2
 data={'triangles':count,'materials':1,'textures':1,'texture_size':[1024,1024],'bounds_blender':bounds,'muzzle':game_point((0,tip,1.12),scale),'construction':'original carbine modules; selective bevels, planar dissolve and octagonal bores' if optimized else 'original carbine modules; authored variants; no decimation','optimization_pending':not optimized}
 if name in ('carbine','smg','burst_pistol','designator'):data['red_dot_position']=game_point((0,-1.1,4.0),scale)
 if name=='assault_rifle':data.update(scope_rear=game_point((0,-1.3,4.0),scale),scope_front=game_point((0,-.9,4.0),scale),scope_radius=.65*scale,zoom_steps=[1.5],red_dot=True)
 if name in ('beam_pistol','scout_pistol'):data.update(scope_rear=game_point((0,-4.22,4.3),scale),scope_front=game_point((0,3.22,4.3),scale),scope_radius=.6*scale,zoom_steps=[2.0,4.0,8.0] if name=='beam_pistol' else [1.5,3.0,6.0])
 if heavy:data.update(pack_entry=game_point((-3.1,2.4,.55),scale),pack_direction=[-1,0,0],monitor_position=game_point((0,-1.8,4.05),scale))
 data['rack_anchor']=([0,.135,-.0455] if pistol else [.055,.10,-.0455] if name=='assault_rifle' else [.065,.115,-.052]) if not heavy else [0,0,0]
 data['magazine_anchor']=game_point((-3.1,2.4,.55),scale) if heavy else game_point((0,-3.25,-4.05),scale) if pistol else game_point((0,2.5,-.3925),scale)
 data['support_anchor']=[0,.025,-.07] if pistol else [0,.015,-.15]
 manifest[name]=data
 for material in materials:
  for node in list(material.node_tree.nodes):
   if node.type=='TEX_IMAGE':material.node_tree.nodes.remove(node)
 bpy.ops.wm.save_as_mainfile(filepath=str(authoring/(name+'.blend')),compress=True)
 print('CQ_MODULAR',name,count,flush=True)
if '--audit' not in args:(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
