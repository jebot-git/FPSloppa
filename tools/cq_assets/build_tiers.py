"""CQ tier assets. Blender --background --factory-startup --python build_tiers.py.
Source silhouettes/UV surface detail are retained with a gunmetal finish. Movable reload parts share one baked atlas.
"""
import bpy,bmesh,json,math,sys,struct
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];SRC=ROOT/'test-results/weapon-sources';OUT=ROOT/'deathmatch/weapons/cq';AUTH=ROOT/'tools/cq_assets/tier_authoring';AUTH.mkdir(exist_ok=True)
MANIFEST=json.loads((OUT/'manifest.json').read_text())
MANIFEST['carbine'].update(red_dot=True,sight_zero_metres=50.,red_dot_position=[0.,.2442,-.0392])
COMPLEX_WEAPONS={'burst_rifle','scout_pistol','beam_pistol','guided_launcher','energy_minigun'}
def triangle_budget(key):return 7000 if key in COMPLEX_WEAPONS else 5000
# Coordinates in Blender: +Y muzzle, +Z up. glTF exports these as -Z/+Y.
JOBS=[
 ('pistol','fwp.blend',['Pistol1'],.45,math.pi,'pistol'),
 ('burst_pistol','fwp.blend',['Pistol3'],.48,math.pi,'pistol'),
 ('smg','fwp.blend',['SMG1'],.72,math.pi,'rifle'),
 ('smg_t2','fwp.blend',['SMG2'],.747,math.pi,'rifle'),
 ('smg_t3','fwp.blend',['SMG3'],.765,math.pi,'rifle'),
 ('assault_rifle','fwp.blend',['Rifle'],1.12,math.pi,'rifle'),
 ('repair_kit','fwp.blend',['Pistol2'],.38,math.pi,'tool'),
 ('scout_pistol','pistol/pistol.obj',None,1.05,0,'pistol'),
 ('beam_pistol','energy/Eectric_Rifle_Final.fbx',None,1.12,math.pi,'rifle'),
 ('massacre','massacre/Massacre.obj',None,1.21,0,'pack'),
 ('guided_launcher','akira.blend',['rifle1'],1.35,math.pi,'pack'),
 ('designator','emg.blend',None,.80,math.pi,'tool'),
 ('burst_rifle','burst_rifle.blend',None,1.18,math.pi/2,'scope'),
 ('railgun','railgun.blend',None,1.40,math.pi/2,'display'),
 ('energy_minigun','minigun/MiniGun.blend',None,1.40,math.pi/2,'pack')]
# Model-specific placements in the normalized source frame (forward +Y).
# Each tuple is magazine centre, dimensions and outward extraction direction.
MAGAZINES={
 'pistol':((0,-.035,.005),(.043,.070,.125),(0,-.22,-.976)),
 'burst_pistol':((0,.165,.100),(.043,.078,.125),(0,0,-1)),
 'smg':((0,-.070,.225),(.047,.110,.190),(0,0,-1)),
 'smg_t2':((0,.290,.025),(.047,.115,.215),(0,-.68,-.733)),
 'smg_t3':((0,.470,.060),(.047,.100,.210),(0,0,-1)),
 'assault_rifle':((0,-.105,.105),(.045,.090,.180),(0,0,-1)),
 'burst_rifle':((0,.245,.025),(.045,.085,.170),(0,0,-1)),
 'railgun':((0,-.125,-.025),(.050,.110,.170),(0,0,-1)),
 'massacre':((-.080,.330,.085),(.125,.150,.100),(-1,0,0)),
 'guided_launcher':((0,.220,.005),(.065,.125,.150),(0,0,-1)),
 'energy_minigun':((0,-.100,-.235),(.190,.220,.180),(0,0,-1)),
}
# Correct palm origins independently of the model's bounding-box centre.
PALMS={'pistol':(0,-.025,.025),'burst_pistol':(0,-.01,.025),
 'smg':(0,.245,.065),'smg_t2':(0,-.050,.065),'smg_t3':(0,-.060,.130),
 'assault_rifle':(0,.120,.040),'scout_pistol':(0,.035,.020),
 'beam_pistol':(0,.105,-.020),'guided_launcher':(0,.100,.005)}

def extract_group(o,name):
 group=o.vertex_groups.get(name)
 if not group:return None
 active(o);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
 for v in o.data.vertices:v.select=any(g.group==group.index and g.weight>.5 for g in v.groups)
 before=set(bpy.data.objects);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
 return next(x for x in bpy.data.objects if x not in before)

def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def load(path,names=None):
 before=set(bpy.data.objects)
 if path.suffix=='.blend':
  with bpy.data.libraries.load(str(path),link=False) as (a,b):b.objects=[n for n in a.objects if names is None or n in names]
  for o in b.objects:
   if o and o.type=='MESH':bpy.context.collection.objects.link(o)
 elif path.suffix.lower()=='.obj':bpy.ops.wm.obj_import(filepath=str(path))
 else:bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False)
 bpy.context.view_layer.update()
 return [o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
def bounds(objects):
 vs=[v.co for o in objects for v in o.data.vertices]
 return Vector([min(v[i] for v in vs) for i in range(3)]),Vector([max(v[i] for v in vs) for i in range(3)])
def evaluated(objects):
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
 for o in objects:
  m=bpy.data.meshes.new_from_object(o.evaluated_get(deps),depsgraph=deps);m.transform(o.matrix_world);o.modifiers.clear();o.parent=None;o.matrix_world=Matrix.Identity(4);o.data=m
  # Every texture uses the original UV during atlas rebaking.
  if not m.uv_layers:m.uv_layers.new(name='SourceUV')
  else:
   source_uv=m.uv_layers.active
   for layer in list(m.uv_layers):
    if layer!=source_uv:m.uv_layers.remove(layer)
   source_uv.name='SourceUV'
  if not m.materials:m.materials.append(material('Unpainted source metal',(.22,.25,.28)))
  for index,mat in enumerate(m.materials):
   if mat is None:m.materials[index]=material('Unpainted source metal',(.22,.25,.28))
  for mat in m.materials:
   if not mat:continue
   was_nodes=mat.use_nodes;original_color=tuple(mat.diffuse_color);mat.use_nodes=True
   if not was_nodes:
    shader=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if shader:shader.inputs['Base Color'].default_value=original_color
   for n in list(mat.node_tree.nodes):
    if n.type!='TEX_IMAGE' or not n.image:continue
    if not n.image.has_data:
     matches=list((SRC/'burst_textures').rglob(Path(n.image.filepath.replace('\\','/')).name))
     if matches:n.image.filepath=str(matches[0]);n.image.reload()
    uv=mat.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map='SourceUV';mat.node_tree.links.new(uv.outputs['UV'],n.inputs['Vector'])
def material(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True
 shader=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');shader.inputs['Base Color'].default_value=(*color,1);shader.inputs['Roughness'].default_value=.55
 return m
metal=None
def cube(name,p,size):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.scale=size;active(o);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(metal);return o

def shell_well(body,center,size,orientation=Matrix.Identity(3)):
 # An actual open aperture, with a thin collar; the magazine is a separate node.
 # Source meshes contain disconnected/non-manifold islands. Partition only
 # polygons crossing the aperture instead of applying whole-object CSG.
 lo=Vector(center)-Vector((size[0]*1.04,size[1]*1.04,size[2]*1.15))*.5
 hi=Vector(center)+Vector((size[0]*1.04,size[1]*1.04,size[2]*1.15))*.5
 source=body.data;uv=source.uv_layers.active;points=[];faces=[];texcoords=[];materials=[]
 def clip(poly,axis,value,sign):
  result=[]
  for (a,ua),(b,ub) in zip(poly,poly[1:]+poly[:1]):
   da=(a[axis]-value)*sign;db=(b[axis]-value)*sign
   if da>=0:result.append((a,ua))
   if (da>=0)!=(db>=0):
    t=da/(da-db);result.append((a+(b-a)*t,ua+(ub-ua)*t))
  return result
 for face in source.polygons:
  poly=[(orientation.transposed()@(source.vertices[source.loops[i].vertex_index].co-center)+center,uv.data[i].uv.copy() if uv else Vector((0,0))) for i in face.loop_indices]
  if any(max(v[a] for v,u in poly)<lo[a] or min(v[a] for v,u in poly)>hi[a] for a in range(3)):fragments=[poly]
  else:
   fragments=[]
   for axis,value,sign in [(a,v,k) for a in range(3) for v,k in [(lo[a],1),(hi[a],-1)]]:
    outside=clip(poly,axis,value,-sign)
    if len(outside)>=3:fragments.append(outside)
    poly=clip(poly,axis,value,sign)
    if len(poly)<3:break
  for fragment in fragments:
   start=len(points);points.extend(orientation@(v-center)+center for v,u in fragment);texcoords.extend(u for v,u in fragment);faces.append(tuple(range(start,len(points))));materials.append(face.material_index)
 mesh=bpy.data.meshes.new('LocalizedOpenWell');mesh.from_pydata(points,[],faces);mesh.update()
 for mat in source.materials:mesh.materials.append(mat)
 layer=mesh.uv_layers.new(name='SourceUV')
 for face,material_index in zip(mesh.polygons,materials):
  face.material_index=material_index
  for loop in face.loop_indices:layer.data[loop].uv=texcoords[mesh.loops[loop].vertex_index]
 body.data=mesh
 parts=[]
 for side in [-1,1]:parts.append(cube('WellSide',(center[0]+side*size[0]*.56,center[1],center[2]+size[2]*.25),(.006,size[1]*1.15,.024)))
 for side in [-1,1]:parts.append(cube('WellEdge',(center[0],center[1]+side*size[1]*.56,center[2]+size[2]*.25),(size[0]*1.15,.006,.024)))
 for part in parts:
  part.location=orientation@(part.location-center)+center;part.data.transform(orientation.to_4x4())
 return parts

def join(objects,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o

def triangles(o):o.data.calc_loop_triangles();return len(o.data.loop_triangles)
def reduce(objects,limit,preserve_detail=False):
 total=sum(triangles(o) for o in objects)
 if total<=limit:return
 if not preserve_detail:
  for o in objects:
   active(o);m=o.modifiers.new('Preserve planes','DECIMATE');m.decimate_type='DISSOLVE';m.angle_limit=.025;bpy.ops.object.modifier_apply(modifier=m.name)
 total=sum(triangles(o) for o in objects)
 if total>limit:
  protected=sum(triangles(o) for o in objects if triangles(o)<200)
  ratio=max(.01,(limit-32-protected)/max(1,total-protected))
  for o in objects:
   if triangles(o)<200:continue
   active(o);m=o.modifiers.new('Runtime triangle budget','DECIMATE');m.ratio=ratio;bpy.ops.object.modifier_apply(modifier=m.name)

def game(v):return [float(v[0]),float(v[2]),float(-v[1])]
def bake(objects,key):
 # Join once for an atlas; vertex groups preserve independently movable pieces.
 for o in objects:
  if o.name in ('InsertedAmmo','ChargingHandle','SlidingBolt','ReloadReceiver','ReloadGrip'):
   g=o.vertex_groups.new(name='PART_'+o.name);g.add(list(range(len(o.data.vertices))),1.,'REPLACE')
 body=join(objects,key);active(body)
 for layer in list(body.data.uv_layers):
  if layer.name!='SourceUV':body.data.uv_layers.remove(layer)
 atlas_name=body.data.uv_layers.new(name='CQAtlas').name;body.data.uv_layers.active_index=len(body.data.uv_layers)-1;body.data.uv_layers.active.active_render=True
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.006);bpy.ops.object.mode_set(mode='OBJECT')
 image=bpy.data.images.new(key+'_atlas',1024,1024,alpha=False)
 for mat in body.data.materials:
  if not mat:continue
  mat.use_nodes=True
  shader=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if shader is None:shader=next((n for n in mat.node_tree.nodes if n.type in ['BSDF_DIFFUSE','BSDF_GLOSSY']),None)
  color=shader.inputs.get('Base Color') if shader and shader.type=='BSDF_PRINCIPLED' else shader.inputs.get('Color') if shader else None
  emission=mat.node_tree.nodes.new('ShaderNodeEmission')
  if color and color.is_linked:mat.node_tree.links.new(color.links[0].from_socket,emission.inputs['Color'])
  else:emission.inputs['Color'].default_value=color.default_value if color else tuple(mat.diffuse_color)
  # Bake source texture values into a neutral blue-grey metal palette.
  # Luminance preserves authored markings and wear without pastel body colours.
  luminance=mat.node_tree.nodes.new('ShaderNodeRGBToBW')
  source=emission.inputs['Color']
  if source.is_linked:mat.node_tree.links.new(source.links[0].from_socket,luminance.inputs['Color'])
  else:luminance.inputs['Color'].default_value=source.default_value
  ramp=mat.node_tree.nodes.new('ShaderNodeValToRGB')
  ramp.color_ramp.elements[0].color=(.018,.024,.030,1)
  ramp.color_ramp.elements[1].color=(.24,.275,.31,1)
  mat.node_tree.links.new(luminance.outputs[0],ramp.inputs[0])
  occlusion=mat.node_tree.nodes.new('ShaderNodeAmbientOcclusion');occlusion.inputs['Distance'].default_value=.045;occlusion.samples=16
  multiply=mat.node_tree.nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=.65
  mat.node_tree.links.new(ramp.outputs[0],multiply.inputs[1]);mat.node_tree.links.new(occlusion.outputs['Color'],multiply.inputs[2]);mat.node_tree.links.new(multiply.outputs[0],emission.inputs['Color'])
  for output in [n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL']:mat.node_tree.links.new(emission.outputs[0],output.inputs['Surface'])
  n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=image;mat.node_tree.nodes.active=n
 bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
 bpy.context.scene.render.bake.use_pass_direct=False;bpy.context.scene.render.bake.use_pass_indirect=False;bpy.context.scene.render.bake.use_pass_color=True;bpy.context.scene.render.bake.margin=4
 bpy.ops.object.bake(type='EMIT')
 image.filepath_raw=str(OUT/(key+'_tier_atlas.png'));image.file_format='PNG';image.save();image.pack()
 mat=material(key+'_finish',(.25,.25,.25));shader=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');shader.inputs['Metallic'].default_value=.35;shader.inputs['Roughness'].default_value=.43;n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=image;mat.node_tree.links.new(n.outputs['Color'],shader.inputs['Base Color'])
 body.data.materials.clear();body.data.materials.append(mat)
 for p in body.data.polygons:p.material_index=0
 for color in list(body.data.color_attributes):body.data.color_attributes.remove(color)
 for uv in list(body.data.uv_layers):
  if uv.name!=atlas_name:body.data.uv_layers.remove(uv)
 parts=[body]
 for name in ['InsertedAmmo','ChargingHandle','SlidingBolt','ReloadReceiver','ReloadGrip']:
  group=body.vertex_groups.get('PART_'+name)
  if not group:continue
  active(body);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
  selected=[v for v in body.data.vertices if any(g.group==group.index and g.weight>.5 for g in v.groups)]
  if not selected:continue
  for v in selected:v.select=True
  before=set(bpy.data.objects);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
  part=next(o for o in bpy.data.objects if o not in before);part.name=name;parts.append(part)
 return parts

def build(job):
 global metal
 key,filename,names,length,angle,kind=job
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 objects=load(SRC/filename,names)
 source_ammo=None;reload_path=[];moving_parts=[];source_motion=[]
 if key=='beam_pistol':
  bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
  bpy.ops.import_scene.fbx(filepath=str(SRC/filename),use_anim=True)
  arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
  bone=arm.data.bones['Bone'];bind=arm.matrix_world@bone.matrix_local
  for frame in range(1,102,5):
   bpy.context.scene.frame_set(frame);reload_path.append(arm.matrix_world@arm.pose.bones['Bone'].matrix@bind.inverted())
   source_motion.append({name:arm.matrix_world@arm.pose.bones[name].matrix@(arm.matrix_world@arm.data.bones[name].matrix_local).inverted() for name in ['Slide','Grip']})
  bpy.context.scene.frame_set(101);end=arm.matrix_world@arm.pose.bones['Bone'].matrix@bind.inverted()
  bpy.context.scene.frame_set(0);arm.animation_data_clear()
  for b in arm.pose.bones:b.matrix_basis=Matrix.Identity(4)
  bpy.context.view_layer.update();source_ammo=extract_group(mesh,'Bone');objects=[mesh]
  evaluated([source_ammo]);source_ammo.data.transform(end)
  for group,name in [('Slide','ReloadReceiver'),('Grip','ReloadGrip')]:
   part=extract_group(mesh,group);part.name=name;moving_parts.append(part)
  evaluated(objects+moving_parts)
  objects+=moving_parts+[source_ammo]
 else:evaluated(objects)
 if key=='burst_rifle':objects=[o for o in objects if min((o.matrix_world@Vector(v)).z for v in o.bound_box)>.7]
 if key=='energy_minigun':objects=[o for o in objects if o.name in ['Minigun','Cylinder.005','Cylinder.004']]
 rotation=Matrix.Rotation(angle,4,'Z')
 for o in objects:o.data.transform(rotation)
 lo,hi=bounds(objects);scale=length/(hi.y-lo.y)
 # Place the main grip at the palm; source axes and complete silhouettes retained.
 grip=Vector(((lo.x+hi.x)*.5,lo.y+(hi.y-lo.y)*(.34 if key=='scout_pistol' else .22),lo.z+(hi.z-lo.z)*.25))
 if key=='burst_rifle':grip=rotation@Vector((-1.0,.265,1.12))
 if key=='railgun':grip=rotation@Vector((-2.5,0,-.1))
 if key=='energy_minigun':grip=rotation@Vector((-13.45,0,1.05))
 palm=Vector(PALMS.get(key,(0,0,0)));grip+=palm/scale
 for o in objects:
  for v in o.data.vertices:v.co=(v.co-grip)*scale
 if source_ammo:objects.remove(source_ammo)
 for part in moving_parts:objects.remove(part)
 budget=triangle_budget(key)
 reduce(objects+moving_parts,budget-450 if key in COMPLEX_WEAPONS else 4500,preserve_detail=key in COMPLEX_WEAPONS)
 body=join(objects,key);metal=material('Reload hardware',(.12,.15,.17));lo,hi=bounds([body]+moving_parts);muzzle=Vector((0,hi.y,hi.z*.62))
 # Source barrel-centre sockets, independent of the sight line.
 if filename=='fwp.blend':muzzle.z=hi.z-(hi.z-lo.z)*(.24 if key.startswith('smg') else .25)
 if key=='scout_pistol':muzzle.z=(.85-grip.z)*scale
 if key=='burst_rifle':muzzle.z=(1.55-grip.z)*scale
 if key=='railgun':muzzle.z=(1.37-grip.z)*scale
 if key=='energy_minigun':muzzle.z=(0-grip.z)*scale
 parts=[body]+moving_parts;mag=Vector((0,0,0));mag_direction=Vector((0,0,-1));mag_rotation=Matrix.Identity(3)
 rack=Vector((.045,max(.07,muzzle.y*.22),muzzle.z))
 if kind!='tool':
  if key=='beam_pistol':
   ml,mh=bounds([source_ammo]);mag=(ml+mh)*.5;size=mh-ml
   ammo=source_ammo;ammo.name='InsertedAmmo';mag_direction=Vector((1,0,0))
  elif key=='scout_pistol':
   # Retain the source's shaped grip magazine rather than replacing it with a box.
   # Extract its lower grip surfaces, leaving the upper receiver/trigger untouched.
   bm=bmesh.new();bm.from_mesh(body.data);threshold=(-.65-grip.z)*scale
   keep=[f for f in bm.faces if all(v.co.z<threshold and abs(v.co.x)<.017 for v in f.verts) and all(-.04 < v.co.y < .055 for v in f.verts)]
   copy=bm.copy();selected={f.index for f in keep}
   bmesh.ops.delete(copy,geom=[f for f in copy.faces if f.index not in selected],context='FACES')
   mesh=bpy.data.meshes.new('Authored scout grip magazine');copy.to_mesh(mesh);copy.free()
   bmesh.ops.delete(bm,geom=keep,context='FACES');bm.to_mesh(body.data);bm.free()
   ammo=bpy.data.objects.new('InsertedAmmo',mesh);bpy.context.collection.objects.link(ammo)
   ml,mh=bounds([ammo]);mag=(ml+mh)*.5;size=mh-ml;mag_direction=Vector((0,-.15,-.989)).normalized()
  else:
   center,dimensions,direction=MAGAZINES[key];mag=Vector(center)-palm
   if key=='energy_minigun':mag.y+=5.45*scale
   if key.startswith('smg'):mag*=.9
   if key in ['massacre','guided_launcher']:mag*=1.08
   size=Vector(dimensions);mag_direction=Vector(direction).normalized()
   mag_rotation=Vector((0,0,-1)).rotation_difference(mag_direction).to_matrix()
   parts+=shell_well(body,mag,size,mag_rotation)
   if filename=='fwp.blend' and (kind=='pistol' or key=='assault_rifle'):
    mags=load(SRC/'fwp.blend',['PistolMag' if kind=='pistol' else 'RifleMag']);evaluated(mags);ml,mh=bounds(mags);mc=(ml+mh)*.5
    for o in mags:
     for v in o.data.vertices:v.co=mag_rotation@Vector([(v.co[a]-mc[a])*size[a]/max(.001,mh[a]-ml[a]) for a in range(3)])+mag
    ammo=join(mags,'InsertedAmmo')
   else:
    ammo=cube('InsertedAmmo',mag,size);ammo.data.transform(mag_rotation.to_4x4())
  parts.append(ammo)
  if kind not in ['pack','pistol']:
   handle=cube('ChargingHandle',rack,(.055,.035,.025));parts.append(handle)
 # The source pistols' upper receiver becomes a real slide, preserving source UVs.
 if kind=='pistol':
  active(body);bm=bmesh.new();bm.from_mesh(body.data)
  slide_face=lambda f: min(v.co.z for v in f.verts)>muzzle.z-.035 and (key!='scout_pistol' or max(v.co.z for v in f.verts)<muzzle.z+.04 and max(v.co.y for v in f.verts)<.20)
  selected=[f for f in bm.faces if slide_face(f)]
  if selected:
   mesh=bpy.data.meshes.new('Slide');copy=bm.copy()
   bmesh.ops.delete(copy,geom=[f for f in copy.faces if not slide_face(f)],context='FACES');copy.to_mesh(mesh);copy.free()
   bmesh.ops.delete(bm,geom=selected,context='FACES');bm.to_mesh(body.data)

   for mat in body.data.materials:mesh.materials.append(mat)
   slide=bpy.data.objects.new('SlidingBolt',mesh);bpy.context.collection.objects.link(slide);parts.append(slide)
  bm.free()
 # Preserve the built-in scope for the burst rifle and scout. Others get a reused red dot.
 # The T1 salvo launcher has no screen or display pedestal.

 scope=kind=='scope' or key=='scout_pistol'
 mount_z=muzzle.z+.04
 sight=Vector((0,-.04,mount_z+.035))
 if key=='assault_rifle':
  dots=load(SRC/'red_dot.blend');evaluated(dots);dl,dh=bounds(dots);ds=.13/(dh.y-dl.y)
  for o in dots:
   for v in o.data.vertices:v.co=(v.co-Vector((0,(dl.y+dh.y)*.5,dl.z)))*ds+Vector((0,-.04,mount_z))
  parts+=dots
  sight=Vector((0,(-1.14013-(dl.y+dh.y)*.5)*ds-.04,mount_z+(1.237855-dl.z)*ds))
 support=Vector((0,max(.10,muzzle.y*.48),muzzle.z-.055))
 if key=='scout_pistol':support=Vector((0,.07,-.025));rack=Vector((.012,.055,muzzle.z))
 if key=='energy_minigun':support=(rotation@Vector((-9.7,0,2.7))-grip)*scale;rack=Vector((0,0,0))
 total=sum(triangles(o) for o in parts)
 if total>budget-16:reduce([body],triangles(body)-(total-(budget-32)),preserve_detail=key in COMPLEX_WEAPONS)
 total=sum(triangles(o) for o in parts);assert total<=budget-16,(key,total)
 parts=bake(parts,key)
 for part in parts:
  anchor=mag if part.name=='InsertedAmmo' else rack if part.name=='ChargingHandle' else None
  if anchor is not None:part.data.transform(Matrix.Translation(-anchor));part.location=anchor
 # Mesh parts export around the same palm frame; runtime moves them from saved rests.
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0]
 bpy.ops.wm.save_as_mainfile(filepath=str(AUTH/(key+'.blend')),check_existing=False)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
 raw=(OUT/(key+'.glb')).read_bytes();gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
 total=sum(gltf['accessors'][p['indices']]['count']//3 for mesh in gltf['meshes'] for p in mesh['primitives'])
 data=dict(triangles=total,materials=1,textures=1,texture_size=[1024,1024],muzzle=game(muzzle),magazine_anchor=game(mag),magazine_extract=game(mag_direction),magazine_layout='model specific',rack_anchor=game(rack),support_anchor=game(support),red_dot_position=game(sight),red_dot=key in ['assault_rifle','burst_rifle'],sight_zero_metres=50,optimization_pending=False,triangle_budget=budget,finish='gunmetal',construction='source silhouette; authored open magazine well and independent reload parts',source=filename,reload_kind='slide' if kind=='pistol' else 'pack' if kind=='pack' else 'handle')
 # Flush inset readout on the source T2 rear-facing monitor, inside its bezel.
 if key=='guided_launcher':data.update(guidance_monitor=True,monitor_position=[0.,.1611161,-.10653],monitor_size=[.046,.046],monitor_rotation=[0.,0.,0.])
 if scope:data.update(scope_rear=game(Vector((0,-.07,hi.z-.018))),scope_front=game(Vector((0,.06,hi.z-.018))),scope_radius=.035,zoom_steps=[1.5] if kind=='scope' else [1.5,3.,6.])
 if key=='scout_pistol':
  rear=Vector((0,(-1.99-grip.y)*scale,(1.68-grip.z)*scale));front=Vector((0,(3.62-grip.y)*scale,rear.z))
  data.update(scope_rear=game(rear),scope_front=game(front),scope_radius=.43*scale,red_dot_position=game(rear),reload_kind='slide')
 if key.startswith('smg'):data.update(aim_laser=True,laser_anchor=game(Vector((0,hi.y*.7,hi.z-.025))))
 if key=='beam_pistol':data.update(scope_monitor=True,monitor_anchor=[-.17,.18,-.13],monitor_size=[.15,.095],monitor_zoom=3.)
 if key=='burst_rifle':
  source_rear=rotation@Vector((-1.1795475,.268947,1.82477));source_front=rotation@Vector((-.306768,.268947,1.82477))
  data.update(scope_rear=game((source_rear-grip)*scale),scope_front=game((source_front-grip)*scale),scope_radius=.030,red_dot_position=game((source_rear-grip)*scale))
 if key=='beam_pistol':
  reference=Vector((-1.05655,-.00809,-1.08277));last=end@reference
  data['magazine_reload_path']=[game((rotation@(matrix@reference-last))*scale) for matrix in reload_path]
  data['magazine_reload_source']='FBX Bone animation, frames 1-101'
  transform=Matrix.Diagonal((scale,scale,scale,1.))@Matrix.Translation(-grip)@rotation
  convert=Matrix.Rotation(-math.pi/2,4,'X');data['reload_motion']={}
  for source,name in [('Slide','ReloadReceiver'),('Grip','ReloadGrip')]:
   frames=[]
   for sample in source_motion[:13]:
    pose=convert@transform@sample[source]@transform.inverted()@convert.inverted();q=pose.to_quaternion()
    frames.append({'position':list(pose.translation),'rotation':[q.x,q.y,q.z,q.w]})
   data['reload_motion'][name]=frames
 if key=='railgun':
  # Cube.035 material 1 is the existing rear-facing screen (normal -source X).
  panel=rotation@Vector((-1.04865,-.00998,1.8477));data.update(thermal_range=150.,display_anchor=game((panel-grip)*scale),display_size=[.35*scale,.43*scale],display_rotation=[0.,0.,0.])
  data['display_anchor'][2]+=.001
 MANIFEST[key]=data;(OUT/'manifest.json').write_text(json.dumps(MANIFEST,indent=2)+'\n');print('CQ_TIER_BUILT',key,total,flush=True)
def recolor_carbine():
 # Keep the existing carbine geometry, sockets and movable parts exactly as authored.
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 objects=load(ROOT/'tools/cq_assets/optimized_authoring/carbine.blend')
 for o in objects:
  for name in ['InsertedAmmo','ChargingHandle','SlidingBolt','ReloadReceiver','ReloadGrip']:
   if o.name.startswith(name):o.name=name

 for o in objects:o.hide_render=False;o.hide_viewport=False;o.hide_set(False)
 evaluated(objects);parts=bake(objects,'carbine')
 data=MANIFEST['carbine']
 for part in parts:
  field='magazine_anchor' if part.name=='InsertedAmmo' else 'rack_anchor' if part.name=='ChargingHandle' else None
  if field:
   p=data[field];anchor=Vector((p[0],-p[2],p[1]));part.data.transform(Matrix.Translation(-anchor));part.location=anchor
 bpy.ops.object.select_all(action='DESELECT')
 for part in parts:part.select_set(True)
 bpy.context.view_layer.objects.active=parts[0]
 bpy.ops.wm.save_as_mainfile(filepath=str(AUTH/'carbine.blend'),check_existing=False)
 bpy.ops.export_scene.gltf(filepath=str(OUT/'carbine.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
 raw=(OUT/'carbine.glb').read_bytes();gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
 data.update(triangles=sum(gltf['accessors'][p['indices']]['count']//3 for mesh in gltf['meshes'] for p in mesh['primitives']),source='existing optimized carbine',texture_size=[1024,1024],finish='gunmetal',triangle_budget=5000)
 (OUT/'manifest.json').write_text(json.dumps(MANIFEST,indent=2)+'\n')

if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
 if not args or 'carbine' in args:recolor_carbine()
 for job in JOBS:
  if not args or job[0] in args:build(job)
