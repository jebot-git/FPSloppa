"""Refine existing baked CQ authoring scenes in Blender, preserving their source UVs.
Run once on pre-refinement scenes: Blender --background --python refine_fittings.py.
"""
import bpy,bmesh,json,struct,math,sys
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'deathmatch/weapons/cq';AUTH=ROOT/'tools/cq_assets/tier_authoring'
# Grasp origins in Godot model coordinates, before VR's shared 0.65 scale.
SUPPORT={
 'pistol':[0,-.018,-.14], 'burst_pistol':[0,-.018,-.15],
 'scout_pistol':[0,-.065,-.07], 'beam_pistol':[0,.045,-.34],
 'carbine':[0,-.005,-.24], 'assault_rifle':[0,-.015,-.36],
 'burst_rifle':[0,-.005,-.415], 'railgun':[0,.065,-.567],
 'massacre':[0,-.065,-.555], 'guided_launcher':[0,-.005,-.457],
 'energy_minigun':[0,.082,-.553],
 'smg':[0,.035,-.109], 'smg_t2':[0,.045,-.250], 'smg_t3':[0,.015,-.278]}
SMG_SCALE=.70

def aperture(body,lo,hi):
 """Subtract a rectangular sight tunnel locally; interpolate the baked UVs."""
 source=body.data;uv=source.uv_layers.active;points=[];faces=[];coords=[];materials=[]
 def clip(poly,axis,value,sign):
  result=[]
  for (a,ua),(b,ub) in zip(poly,poly[1:]+poly[:1]):
   da=(a[axis]-value)*sign;db=(b[axis]-value)*sign
   if da>=0:result.append((a,ua))
   if (da>=0)!=(db>=0):
    t=da/(da-db);result.append((a+(b-a)*t,ua+(ub-ua)*t))
  return result
 for face in source.polygons:
  poly=[(source.vertices[source.loops[i].vertex_index].co.copy(),uv.data[i].uv.copy() if uv else Vector((0,0))) for i in face.loop_indices]
  if any(max(v[a] for v,u in poly)<lo[a] or min(v[a] for v,u in poly)>hi[a] for a in range(3)):fragments=[poly]
  else:
   fragments=[]
   for axis,value,sign in [(a,v,k) for a in range(3) for v,k in [(lo[a],1),(hi[a],-1)]]:
    outside=clip(poly,axis,value,-sign)
    if len(outside)>=3:fragments.append(outside)
    poly=clip(poly,axis,value,sign)
    if len(poly)<3:break
  for fragment in fragments:
   start=len(points);points.extend(v for v,u in fragment);coords.extend(u for v,u in fragment);faces.append(tuple(range(start,len(points))));materials.append(face.material_index)
 mesh=bpy.data.meshes.new('OpenSightTunnel');mesh.from_pydata(points,[],faces);mesh.update()
 for mat in source.materials:mesh.materials.append(mat)
 layer=mesh.uv_layers.new(name='SourceUV')
 for face,material in zip(mesh.polygons,materials):
  face.material_index=material
  for i in face.loop_indices:layer.data[i].uv=coords[mesh.loops[i].vertex_index]
 body.data=mesh

def remove_smg_optic(body,key):
 # Weld coincident geometric vertices; per-corner atlas UVs stay on the faces.
 # Delete the actual disconnected optic islands, never their enclosing boxes.
 bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);seen=set();removed=[]
 for v in bm.verts:
  if v in seen:continue
  group={v};todo=[v];seen.add(v)
  while todo:
   for e in todo.pop().link_edges:
    for n in e.verts:
     if n not in seen:seen.add(n);group.add(n);todo.append(n)
  lo=Vector([min(v.co[i] for v in group) for i in range(3)]);hi=Vector([max(v.co[i] for v in group) for i in range(3)])
  if (key=='smg' and lo.z>.20 and lo.y>-.06 and hi.y>.03) or (key=='smg_t2' and lo.z>.285):removed.extend(group)
 assert removed,(key,'no original sight islands')
 bmesh.ops.delete(bm,geom=removed,context='VERTS');bm.to_mesh(body.data);bm.free()

def add_red_dot(key):
 with bpy.data.libraries.load(str(ROOT/'test-results/weapon-sources/red_dot.blend'),link=False) as (a,b):b.objects=[n for n in a.objects if n in ['Plane','Circle']]
 dots=[o for o in b.objects if o and o.type=='MESH'];assert len(dots)==2
 for o in dots:bpy.context.collection.objects.link(o)
 bpy.context.view_layer.update();depsgraph=bpy.context.evaluated_depsgraph_get()
 for o in dots:
  mesh=bpy.data.meshes.new_from_object(o.evaluated_get(depsgraph));o.modifiers.clear();o.data=mesh
  o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4)
  # Explicit open optical aperture rather than baking opaque lens faces.
  aperture(o,Vector((-.60,-2.,.80)),Vector((.60,3.,1.65)))
 lo=Vector([min(v.co[i] for o in dots for v in o.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for o in dots for v in o.data.vertices) for i in range(3)])
 ds=.13/(hi.y-lo.y);base=Vector((0,-.13 if key=='smg' else .20,.278 if key=='smg' else .290));center=(lo.y+hi.y)*.5
 mat=bpy.data.materials.new('RedDotGunmetal');mat.diffuse_color=(.06,.075,.09,1);mat.use_nodes=True;mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=mat.diffuse_color
 for o in dots:
  for v in o.data.vertices:v.co=(v.co-Vector((0,center,lo.z)))*ds+base
  o.data.materials.clear();o.data.materials.append(mat)
  for p in o.data.polygons:p.material_index=0
 return dots,[0.,(1.225-lo.z)*ds+base.z,-((-1.15-center)*ds+base.y)]

def attach_with_existing_atlas(parts,key):
 # Preserve every existing UV and pixel. New sight hardware samples one solid
 # metal texel from the same atlas, so the GLB still has one material/texture.
 body=next(o for o in parts if o.name==key);material=body.data.materials[0]
 image=next(n.image for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
 chosen=None
 for index in range(0,image.size[0]*image.size[1],37):
  pixel=image.pixels[index*4:index*4+4]
  if .05<sum(pixel[:3])/3.<.18 and max(pixel[:3])-min(pixel[:3])<.05:chosen=index;break
 assert chosen is not None,'No metal texel in the existing atlas'
 coord=((chosen%image.size[0]+.5)/image.size[0],(chosen//image.size[0]+.5)/image.size[1])
 moving=[o for o in parts if o.name in ['InsertedAmmo','ChargingHandle']]
 dots=[o for o in parts if o!=body and o not in moving]
 for o in dots:
  o.data.materials.clear();o.data.materials.append(material)
  for layer in list(o.data.uv_layers):o.data.uv_layers.remove(layer)
  layer=o.data.uv_layers.new(name=body.data.uv_layers.active.name)
  for uv in layer.data:uv.uv=coord
  for face in o.data.polygons:face.material_index=0
 bpy.ops.object.select_all(action='DESELECT')
 for o in [body]+dots:o.select_set(True)
 bpy.context.view_layer.objects.active=body;bpy.ops.object.join();body.name=key
 return [body]+moving

def scale_metadata(data,factor):
 for key,value in list(data.items()):
  if key.endswith(('_anchor','_position','_rear','_front')) or key in ['muzzle','magazine_reload_path']:
   if isinstance(value,list):data[key]=[[n*factor for n in point] for point in value] if value and isinstance(value[0],list) else [n*factor for n in value]
 for key in ['scope_radius','monitor_size','display_size']:
  if key in data:data[key]=[n*factor for n in data[key]] if isinstance(data[key],list) else data[key]*factor

def run():
 manifest=json.loads((OUT/'manifest.json').read_text())
 for key in (sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['smg','smg_t2','smg_t3','designator']):
  bpy.ops.wm.open_mainfile(filepath=str(AUTH/(key+'.blend')))
  if bpy.context.scene.get('cq_fittings_refined',False):print('CQ_FITTING_ALREADY_REFINED',key);continue
  parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name in [key,'InsertedAmmo','ChargingHandle']];body=bpy.data.objects[key];data=manifest[key]
  if key in ['smg','smg_t2']:
   remove_smg_optic(body,key);dots,sight=add_red_dot(key);parts+=dots
   parts=attach_with_existing_atlas(parts,key);data.update(red_dot=True,red_dot_position=sight,red_dot_size=[.035,.026]);data.pop('aim_laser',None);data.pop('laser_anchor',None)
  if key.startswith('smg'):
   for o in parts:
    o.data.transform(Matrix.Scale(SMG_SCALE,4));o.location*=SMG_SCALE
   scale_metadata(data,SMG_SCALE)
   if 'red_dot_size' in data:data['red_dot_size']=[n*SMG_SCALE for n in data['red_dot_size']]
   data['authored_scale_reduction']=SMG_SCALE
   # Rebase movable geometry so the saved socket is its local origin.
   for o in parts:
    if o.name in ['InsertedAmmo','ChargingHandle']:
     anchor=data['magazine_anchor' if o.name=='InsertedAmmo' else 'rack_anchor'];at=Vector((anchor[0],-anchor[2],anchor[1]));o.data.transform(Matrix.Translation(o.location-at));o.location=at
  else:
   aperture(body,Vector((-.019,.390,.190)),Vector((.019,.420,.218)))
   data.update(red_dot=True,red_dot_position=[.00004,.20484,-.395],red_dot_size=[.034,.024],sight_aperture={'minimum':[-.019,.190,-.420],'maximum':[.019,.218,-.390]})
  bpy.context.scene['cq_fittings_refined']=True
  bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.select_set(True)
  bpy.context.view_layer.objects.active=body if body in parts else parts[0];bpy.ops.wm.save_as_mainfile(filepath=str(AUTH/(key+'.blend')),check_existing=False)
  bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
  raw=(OUT/(key+'.glb')).read_bytes();gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]]);data['triangles']=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives']);print('CQ_FITTING_REFINED',key,data['triangles'],flush=True)
 for key,anchor in SUPPORT.items():manifest[key]['support_anchor']=anchor
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':run()
