"""Fit CC0 donors to gameplay anchors, refine authored meshes and bake UV finishes.

Run in a disposable background Blender instance. All dimensions are Blender metres
(+Y muzzle, +Z up); gameplay exports remain Godot -Z muzzle, +Y up.
"""
import bpy,bmesh,math,json,sys,os
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parent;sys.path.insert(0,str(ROOT))
from workshop import clear,activate,load_gltf,load_blend,load_blend_path,bounds,transform_meshes,canonical,reduce,export
from designs import double_barrel,launcher,ripper
from tribes_designs import build_tribes
from donor_edits import build as build_additional,SOURCES as ADDITIONAL
from ut99_designs import build as build_ut99
from dimensions import anchors as fitted_anchors
from cs_refine import refine as refine_cs
from cs_furniture import refine as refine_furniture
from working_parts import configure as configure_parts
from finishes import finish as paint_finishes
from shared_part_budgets import part_budget
OUT=ROOT/'refined';OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
ANCHORS=fitted_anchors()
def xyz(v):return Vector((v[0],-v[2],v[1]))
def material(name,color,metal=.3):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.6;return m
PALETTES={'doom':[(.13,.16,.18),(.25,.29,.31),(.045,.05,.055),(.24,.29,.12)],'quake':[(.15,.12,.095),(.3,.27,.21),(.05,.045,.038),(.27,.14,.075)],'ut99':[(.15,.18,.20),(.34,.37,.39),(.04,.045,.05),(.38,.23,.09)],'tribes':[(.13,.18,.17),(.31,.35,.33),(.04,.05,.052),(.34,.27,.13)]}
DONORS={
 'doom_5':('minigun',False),'doom_9':('painted',False),
 'ut99_4':('gunz_Flak Cannon 5',True),'ut99_5':('minigun',False),
 'quake_4':('lq_g_rock.mdl',False),'quake_5':('lq_g_nail.mdl',False),'quake_6':('lq_g_rock2.mdl',False),
 'quake_7':('lq_g_nail2.mdl',False),'quake_8':('lq_g_light.mdl',False),'quake_9':('painted',False),
}
def classic_shotgun(key,double=False):
 if double:return double_barrel(key,ANCHORS)
 folder=ROOT/'sources/low-poly-guns-pack/unpacked/Ultimate Gun Pack - July 2019/Blends'
 objects=load_blend_path(folder/'Shotgun_1.blend')
 canonical(objects,'+X')
 path=ROOT/'catalog'/'classic_shotgun.glb';export(path,objects);clear()
 objects=fit_donor(key,path.stem,False)
 muzzle=xyz(ANCHORS[key]['muzzle']);lo,hi=bounds(objects)
 tip=sorted(v.co.z for o in objects for v in o.data.vertices if v.co.y>hi.y-.002)
 upper=[z for z in tip if z>(tip[0]+tip[-1])*.5]
 if upper:transform_meshes(objects,Matrix.Translation(Vector((0,0,muzzle.z-(min(upper)+max(upper))*.5))))
 return objects
def indicator(meshes,key):
 colors={'doom_7':(.18,.65,1),'doom_8':(.4,1,.12),'doom_9':(.3,.65,1),'quake_8':(.3,.55,1),'quake_9':(.5,.7,1),'ut99_1':(.4,1,.1),'ut99_3':(.65,.2,1),'ut99_7':(.15,1,.45),'ut99_10':(.2,.7,1)}
 if key not in colors:return
 muzzle=xyz(ANCHORS[key]['muzzle']);target=Vector((.08,muzzle.y*.38,muzzle.z+.07));choices=[]
 for ob in meshes:
  for p in ob.data.polygons:
   if abs(p.normal.x)<.6 or p.area<.0003:continue
   c=ob.matrix_world@p.center
   if c.x<0:continue
   choices.append(((c-target).length,ob,p))
 if not choices:return
 _,ob,face=min(choices,key=lambda x:x[0]);center=face.center;normal=face.normal
 radius=max((ob.data.vertices[i].co-center).length for i in face.vertices);factor=min(.25,.010/max(radius,.001))
 points=[ob.matrix_world@(center+(ob.data.vertices[i].co-center)*factor+normal*.0003) for i in face.vertices]
 data=bpy.data.meshes.new('Inset status light');data.from_pydata(points,[],[list(range(len(points)))]);data.materials.append(material('Status lens',colors[key],.05));data.update()
 led=bpy.data.objects.new('EnergyIndicator',data);bpy.context.scene.collection.objects.link(led);led['lamp']=list(colors[key]);meshes.append(led)
def fit_donor(key,source,flip):
 objects=load_gltf(ROOT/'catalog'/(source+'.glb'));meshes=[o for o in objects if o.type=='MESH']
 transform_meshes(meshes,Matrix.Identity(4))
 for o in objects:
  if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
 if flip:canonical(meshes,'-Y')
 lo,hi=bounds(meshes);muzzle=xyz(ANCHORS[key]['muzzle']);grip=xyz(ANCHORS[key]['grip'])
 # Keep source proportions. A local grip adjustment below the receiver fits the
 # palm without changing the barrel's axis or the receiver's cross-section.
 grip_fraction=.15 if source=='minigun' else .18
 source_grip=lo.y+(hi.y-lo.y)*grip_fraction
 scale=(muzzle.y-grip.y-.015)/(hi.y-source_grip)
 tip=[v.co for o in meshes for v in o.data.vertices if v.co.y>hi.y-(hi.y-lo.y)*.015]
 bore=(min(v.z for v in tip)+max(v.z for v in tip))*.5
 shift=Vector((-(lo.x+hi.x)*.5*scale,muzzle.y-.015-hi.y*scale,muzzle.z-bore*scale))
 transform_meshes(meshes,Matrix.Translation(shift)@Matrix.Scale(scale,4))
 if key=='quake_4':
  # The pickup donor's drum was oversized for a held grenade launcher.
  # Reduce its radial bulk about the bore while retaining the palm position.
  for ob in meshes:
   for v in ob.data.vertices:
    v.co.x*=.78
    if v.co.z>grip.z+.04:v.co.z=muzzle.z+(v.co.z-muzzle.z)*.78
 if source=='minigun':
  # Size the whole rotary head by its diameter, independently of barrel length.
  # The motor and retainers grow with the barrels; the palm stays unchanged.
  barrels=next(o for o in meshes if o.name=='barrels');low,high=bounds([barrels])
  factor=.24/(high.x-low.x)
  for ob in meshes:
   if ob.name not in ['barrels','stabilizer mid','stabilizer front','main body','controls','handle']:continue
   radial=factor if ob.name in ['barrels','stabilizer mid','stabilizer front'] else min(factor,1.6)
   for v in ob.data.vertices:
    v.co.x*=radial;v.co.z=muzzle.z+(v.co.z-muzzle.z)*radial
 if source=='sentinel':
  for ob in meshes:
   activate(ob);remesh=ob.modifiers.new('Retopologized receiver shell','REMESH')
   if 'VOXEL' in [i.identifier for i in remesh.bl_rna.properties['mode'].enum_items]:remesh.mode='VOXEL'
   remesh.voxel_size=.0035;remesh.use_smooth_shade=True;remesh.use_remove_disconnected=False
   bpy.ops.object.modifier_apply(modifier=remesh.name);reduce(ob,8500)
 if source=='minigun' or key in ['doom_8','quake_8']:
  old=next((o for o in meshes if o.name=='trigger'),None) if source=='minigun' else None
  if old:meshes.remove(old);bpy.data.objects.remove(old,do_unlink=True)
  donated=load_blend('28872',['grip.001']);transform_meshes(donated,Matrix.Rotation(math.pi/2,4,'Z'))
  low,high=bounds(donated);s=.24/(high.z-low.z);center=(low+high)*.5
  transform_meshes(donated,Matrix.Translation(grip)@Matrix.Scale(s,4)@Matrix.Translation(-center))
  for ob in donated:
   ob.data.materials.clear();ob.data.materials.append(material('Donated grip rubber',(.026,.03,.035),.03))
  meshes.extend(donated)
 if key=='quake_5':
  for ob in meshes:
   for v in ob.data.vertices:
    if abs(v.co.y-grip.y)<.18:v.co.z-=.060*max(0,min(1,(muzzle.z-.025-v.co.z)/.05))
 for ob in meshes:
  ob.name='Donor_'+ob.name
  # Only pistol-grip vertices are reshaped; barrel/optic vertices are fixed.
  for v in ob.data.vertices:
   if v.co.z<muzzle.z-.075 and abs(v.co.y-grip.y)<.14:
    envelope=max(0,1-abs(v.co.y-grip.y)/.14)
    v.co.x*=1-.12*envelope
  if source=='minigun' and any(s in ob.name for s in ['barrels','stabilizer']):
   pivot=Vector((muzzle.x,0,muzzle.z));ob.data.transform(Matrix.Translation(-pivot));ob.location=pivot;ob['motion']='spin';ob['amount']=[0,0,1]
 return meshes
def color_donor(meshes,rules,source):
 if source.startswith(('marine','lq_')) or source=='painted':return
 palette=list(PALETTES.get(rules,PALETTES['doom']))
 if source=='classic':palette[3]=(.22,.105,.045)
 palette[0]={'gunz_Bio Rifle':(.16,.23,.10),'gunz_Flak Cannon 5':(.37,.23,.08),'gunz_Link Gun':(.11,.24,.16),'sentinel':(.16,.21,.10)}.get(source,palette[0])
 mats=[material('Authored '+rules+' '+str(i),tuple(v*.58 for v in c),.6 if i in [0,1] else .05) for i,c in enumerate(palette)]
 lo,hi=bounds(meshes);span=hi-lo
 for ob in meshes:
  old=[m.name.lower() if m else '' for m in ob.data.materials];indices=[p.material_index for p in ob.data.polygons]
  ob.data.materials.clear()
  for m in mats:ob.data.materials.append(m)
  for p,idx in zip(ob.data.polygons,indices):
   c=ob.matrix_world@p.center;n=old[min(idx,len(old)-1)] if old else ''
   # Material boundaries follow the source's authored part allocation.
   i=2 if any(w in n for w in ['rubber','leather','black','trigger']) else 3 if any(w in n for w in ['gold','camo','ceramic']) else 1 if any(w in n for w in ['chrome','alu','metal_glance']) else idx%2
   if c.z<lo.z+span.z*.32:i=2
   if source=='classic' and (c.y<lo.y+span.y*.29 or c.z<lo.z+span.z*.36):i=3
   p.material_index=i
def refine_mesh(ob,key):
 if ob.data.users>1:ob.data=ob.data.copy()
 if ob.data.shape_keys:ob.shape_key_clear()
 bm=bmesh.new();bm.from_mesh(ob.data)
 if key.startswith('cs16') and ob.name=='Body':
  for v in bm.verts:
   p=ob.matrix_world@v.co
   if -.17<p.z<.025 and -.10<p.y<.03:
    v.co.x*=.86+.14*math.sin(math.pi*(p.z+.17)/.195)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000015)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 # Small forged edges, not subdivision of the whole receiver. All CS sight and
 # optic geometry above the receiver is excluded from silhouette changes.
 edges=[]
 for e in bm.edges:
  if not e.is_manifold or e.calc_face_angle(0)<.45:continue
  if key.startswith('cs16') and any((ob.matrix_world@v.co).z>.128 for v in e.verts):continue
  if e.calc_length()<.008:continue
  # Keep deliberately polygonal barrel walls planar. Bevel only the rims;
  # rounding longitudinal edges would turn an 8-gon back into 24 sides.
  if ob.name.startswith(('HeavyRotaryBarrel','LaserFocusingBarrel','HeavyMortarTube')):
   direction=(e.verts[1].co-e.verts[0].co).normalized()
   if abs(direction.y)>.65:continue
  edges.append(e)
 if edges and len(bm.faces)<22000:
  try:bmesh.ops.bevel(bm,geom=edges,offset=(.0035 if key=='cs16_11' and ob.name=='Body' else .0008) if key.startswith('cs16') else .0018,segments=3 if key=='cs16_11' else 2,affect='EDGES',clamp_overlap=True)
  except ValueError:pass
 bmesh.ops.triangulate(bm,faces=list(bm.faces))
 bm.to_mesh(ob.data);bm.free();ob.data.update()
 budget=part_budget(key,ob.name)
 if budget is not None:reduce(ob,budget)
 elif ob.name=='SculptedShoulderStock':reduce(ob,960)
 elif not key.startswith('cs16'):reduce(ob,11000)
 # Flat receiver faces and interpolated small edge strips avoid melted shading.
 for p in ob.data.polygons:p.use_smooth=True
 ob.data.set_sharp_from_angle(angle=math.radians(40))
 activate(ob)
 mod=ob.modifiers.new('Weighted machined normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
 try:bpy.ops.object.modifier_apply(modifier=mod.name)
 except RuntimeError:ob.modifiers.remove(mod)
def bake(objects,key,size=1024):
 meshes=[o for o in objects if o.type=='MESH' and len(o.data.polygons)]
 if not meshes:return
 # Unique UV atlas for this weapon. Original UVs remain available to source
 # materials during the bake; no repeated silver overlay on every receiver.
 for ob in meshes:
  if not ob.data.uv_layers:ob.data.uv_layers.new(name='SourceUV')
  ob.data.uv_layers.active.name='SourceUV'
  ob.data.uv_layers.new(name='AuthoredUV');ob.data.uv_layers.active_index=len(ob.data.uv_layers)-1
  ob.data.uv_layers.active.active_render=True
 for ob in bpy.context.view_layer.objects:
  if ob:ob.select_set(False)
 for ob in meshes:ob.hide_set(False);ob.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(70),island_margin=.015,area_weight=.6);bpy.ops.uv.select_all(action='SELECT');bpy.ops.uv.pack_islands(rotate=True,margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
 image=bpy.data.images.new(key+' authored albedo',width=size,height=size,alpha=False)
 originals={};bake_mats=[];surface_values={}
 for ob in meshes:
  if not ob.data.materials:ob.data.materials.append(material('Fallback steel',(.16,.18,.2)))
  for slot in ob.material_slots:
   source=slot.material
   if source in originals:slot.material=originals[source];continue
   mat=source.copy();mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links
   p=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
   surface_values[mat]=(p.inputs['Roughness'].default_value,p.inputs['Metallic'].default_value) if p else (.65,0)
   color=p.inputs['Base Color'].default_value[:] if p else source.diffuse_color[:]
   base=p.inputs['Base Color'].links[0].from_socket if p and p.inputs['Base Color'].is_linked else None
   uv=nodes.new('ShaderNodeUVMap');uv.uv_map='SourceUV'
   for n in list(nodes):
    if n.type=='TEX_IMAGE':links.new(uv.outputs['UV'],n.inputs['Vector'])
   rgb=nodes.new('ShaderNodeRGB');rgb.outputs[0].default_value=color
   coord=nodes.new('ShaderNodeTexCoord');noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=135;noise.inputs['Detail'].default_value=2;links.new(coord.outputs['Object'],noise.inputs['Vector'])
   variation=nodes.new('ShaderNodeMapRange');variation.inputs['To Min'].default_value=.96 if key.startswith(('cs16','tribes')) else .76;variation.inputs['To Max'].default_value=1.02 if key.startswith(('cs16','tribes')) else 1.08;links.new(noise.outputs['Fac'],variation.inputs['Value'])
   multiply=nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1;links.new(base or rgb.outputs[0],multiply.inputs[1]);links.new(variation.outputs[0],multiply.inputs[2])
   # Geometry-aware dirt in seams. A short AO distance avoids painted shadows
   # from nearby unrelated components and preserves moving-part independence.
   ao=nodes.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.025;ao.samples=8
   shade=nodes.new('ShaderNodeMixRGB');shade.blend_type='MULTIPLY';shade.inputs[0].default_value=.38;links.new(multiply.outputs[0],shade.inputs[1]);links.new(ao.outputs['AO'],shade.inputs[2])
   geometry=nodes.new('ShaderNodeNewGeometry');wear=nodes.new('ShaderNodeMapRange');wear.inputs['From Min'].default_value=.51;wear.inputs['From Max'].default_value=.59;wear.inputs['To Min'].default_value=0;wear.inputs['To Max'].default_value=.07;wear.clamp=True;links.new(geometry.outputs['Pointiness'],wear.inputs['Value'])
   edge=nodes.new('ShaderNodeMixRGB');edge.inputs[2].default_value=(.38,.40,.40,1);links.new(wear.outputs[0],edge.inputs[0]);links.new(shade.outputs[0],edge.inputs[1])
   tone=nodes.new('ShaderNodeMixRGB');tone.blend_type='MULTIPLY';tone.inputs[0].default_value=1;tone.inputs[2].default_value=(.65,.65,.65,1)
   if key=='quake_9':tone.inputs[2].default_value=(.60,.43,.29,1)
   links.new(edge.outputs[0],tone.inputs[1])
   emission=nodes.new('ShaderNodeEmission');links.new(tone.outputs[0],emission.inputs[0]);output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');links.new(emission.outputs[0],output.inputs['Surface'])
   target=nodes.new('ShaderNodeTexImage');target.image=image;nodes.active=target;target.select=True
   originals[source]=mat;slot.material=mat;bake_mats.append(mat)
 scene=bpy.context.scene
 scene.render.engine='CYCLES';scene.cycles.samples=4;scene.render.threads_mode='FIXED';scene.render.threads=8;scene.render.bake.margin=2;scene.render.bake.use_clear=False
 bpy.ops.object.bake(type='EMIT')
 image.filepath_raw=str(OUT/(key+'_albedo.png'));image.file_format='PNG';image.save()
 orm=bpy.data.images.new(key+' surface response',width=size,height=size,alpha=False)
 orm.colorspace_settings.name='Non-Color'
 for mat in bake_mats:
  nodes=mat.node_tree.nodes;links=mat.node_tree.links
  emission=next(n for n in nodes if n.type=='EMISSION')
  for link in list(emission.inputs[0].links):links.remove(link)
  rough,metal=surface_values[mat];emission.inputs[0].default_value=(1,rough,metal,1)
  target=nodes.new('ShaderNodeTexImage');target.image=orm;nodes.active=target
 bpy.ops.object.bake(type='EMIT')
 orm.filepath_raw=str(OUT/(key+'_orm.png'));orm.file_format='PNG';orm.save()
 final=material(key+' baked finish',(1,1,1),.22 if key.startswith('cs16') else .35)
 p=next(n for n in final.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=final.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;final.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 response=final.node_tree.nodes.new('ShaderNodeTexImage');response.image=orm
 channels=final.node_tree.nodes.new('ShaderNodeSeparateColor');final.node_tree.links.new(response.outputs['Color'],channels.inputs['Color'])
 final.node_tree.links.new(channels.outputs['Green'],p.inputs['Roughness']);final.node_tree.links.new(channels.outputs['Blue'],p.inputs['Metallic'])
 for ob in meshes:
  ob.data.materials.clear();ob.data.materials.append(final)
  for p in ob.data.polygons:p.material_index=0
  for original in list(ob.data.uv_layers):
   if original.name!='AuthoredUV':ob.data.uv_layers.remove(original)
  ob.data.uv_layers.active_index=0
 return image
def split_motion(meshes,key):
 if key.startswith('cs16') or any(o.get('motion') for o in meshes):return
 if key in ['ut99_0','ut99_11'] or key.startswith('tf_'):return
 # Move actual breech geometry. Connected source islands are selected by their
 # bounds, rather than adding decorative boxes on top of the gun.
 muzzle=xyz(ANCHORS[key]['muzzle'])
 if not meshes:return
 ob=max(meshes,key=lambda x:len(x.data.polygons));mesh=ob.data
 lo,hi=bounds([ob]);front=lo.y+(hi.y-lo.y)*.48
 bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table()
 candidates=[f for f in bm.faces if all(front<v.co.y<front+.12 and abs(v.co.x)>.025 and v.co.z>muzzle.z+.03 for v in f.verts)]
 label='WorkingBreech';motion='slide';amount=[0,0,.028]
 if key in ['doom_3','quake_2']:
  candidates=[];remaining=set(bm.verts)
  while remaining:
   seed=remaining.pop();component={seed};todo=[seed]
   while todo:
    v=todo.pop()
    for edge in v.link_edges:
     other=edge.other_vert(v)
     if other in remaining:remaining.remove(other);component.add(other);todo.append(other)
   if len(component)<30:continue
   low=Vector([min(v.co[i] for v in component) for i in range(3)]);high=Vector([max(v.co[i] for v in component) for i in range(3)])
   if low.y>.30 and high.y<muzzle.y-.13 and .05<high.y-low.y<.30 and high.z<muzzle.z+.009:
    candidates.extend(f for f in bm.faces if all(v in component for v in f.verts))
  label='ReciprocatingForeEnd';motion='pump';amount=[0,0,.095]
 if 8<len(candidates)<len(bm.faces)*.4:
  ids={v for f in candidates for v in f.verts};mapping={v:i for i,v in enumerate(ids)}
  data=bpy.data.meshes.new('Working breech');data.from_pydata([v.co[:] for v in ids],[],[[mapping[v] for v in f.verts] for f in candidates]);data.update()
  for mat in mesh.materials:data.materials.append(mat)
  # Preserve original UVs and material allocation when extracting this panel.
  uv=bm.loops.layers.uv.active
  if uv:
   target=data.uv_layers.new(name='SourceUV')
   for polygon,face in zip(data.polygons,candidates):
    polygon.material_index=face.material_index
    for index,loop in zip(polygon.loop_indices,face.loops):target.data[index].uv=loop[uv].uv[:]
  child=bpy.data.objects.new(label,data);bpy.context.scene.collection.objects.link(child);child.matrix_world=ob.matrix_world.copy();child['motion']=motion;child['amount']=amount;meshes.append(child)
  bmesh.ops.delete(bm,geom=candidates,context='FACES');bm.to_mesh(mesh)
 bm.free()
def build(key):
 clear();source='existing authored source'
 if key in ['ut99_1','ut99_6','ut99_7']:
  objects=build_ut99(key,ANCHORS,material);source='Sci-Fi Rifle contoured receiver with slim authored UT bio / pulse / rocket assemblies'
 elif key in ADDITIONAL:
  objects=build_additional(key,ANCHORS,material);source=ADDITIONAL[key]+'; fitted and remodeled for '+key
 elif key=='ut99_10':
  objects=ripper(key,ANCHORS,material);source='Authored disc track and fork + 28872 contoured grip; UT99 reference'
 elif key in ['doom_6','ut99_8']:
  objects=launcher(key,ANCHORS,material);source='Authored launcher housing and bores + 28872 contoured grip'
 elif key.startswith('tribes_') and int(key.split('_')[1]) not in [9,10]:
  objects=build_tribes(int(key.split('_')[1]),ANCHORS,material);source='Authored Starsiege assemblies + BlendSwap 28872 contoured receivers and grips; Josh Buck collection visual reference'
 elif key in ['doom_3','doom_4','quake_2','quake_3']:
  objects=classic_shotgun(key,key in ['doom_4','quake_3']);source='Quaternius Ultimate Gun Pack shotgun'
  color_donor(objects,key.split('_')[0],'classic')
 elif key in DONORS:
  source,flip=DONORS[key];objects=fit_donor(key,source,flip);color_donor(objects,key.split('_')[0],source)
 else:
  objects=load_gltf(ROOT/'bases'/(key+'.glb'))
  # Runtime multimesh ammunition is recreated by ChamberAction. Do not bake
  # its hidden fallback instances into the static M249 asset.
  for ob in list(objects):
   if ob.name=='ArticulatedFeedBelt':
    for child in list(ob.children_recursive):
     objects.remove(child);bpy.data.objects.remove(child,do_unlink=True)
    objects.remove(ob);bpy.data.objects.remove(ob,do_unlink=True)
 meshes=[o for o in objects if o.type=='MESH']
 if key.startswith('cs16'):
  refine_furniture(meshes,key,material);refine_cs(meshes,key)
 configure_parts(meshes,key,ANCHORS,material)
 if key.startswith('tribes_') and int(key.split('_')[1]) not in [9,10] or key in ['doom_3','doom_4','doom_5','doom_6','doom_7','doom_8','ut99_2','ut99_3','quake_2','quake_3','ut99_1','ut99_4','ut99_5','ut99_6','ut99_7','ut99_8','ut99_10']:
  paint_finishes(meshes,key)
 for ob in meshes:
  if ob.name.startswith('fpsloppa_filter'):bpy.data.objects.remove(ob,do_unlink=True);continue
  refine_mesh(ob,key)
 total=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 if total>25000 and not key.startswith('cs16'):
  for ob in meshes:reduce(ob,max(60,int(24000*sum(len(p.vertices)-2 for p in ob.data.polygons)/total)))
 split_motion(meshes,key)
 indicator(meshes,key)
 for ob in meshes:ob.data.validate(clean_customdata=False)
 objects=[o for o in bpy.context.scene.objects if o.type in ['MESH','EMPTY']]
 bake(objects,key,512)
 export(OUT/(key+'.glb'),objects)
 # Editable finished mesh, UVs and packed paint for subsequent manual work.
 for image in bpy.data.images:
  if image.name.startswith((key+' authored',key+' surface')):image.pack()
 bpy.data.orphans_purge(do_recursive=True)
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(key+'.blend')),copy=True)
 triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 row={'key':key,'donor':source,'triangles':triangles,'muzzle':ANCHORS[key]['muzzle'],'grip':ANCHORS[key]['grip'],'texture_size':512}
 (OUT/(key+'.json')).write_text(json.dumps(row,indent=2));print('FIDELITY_BUILT',json.dumps(row),flush=True)
if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(ANCHORS)
 for key in args:
  if key!='doom_0':build(key)
 os._exit(0)
