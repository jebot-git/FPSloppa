"""Offline Blender donor preparation. Source files never execute embedded scripts."""
import bpy,bmesh,json,math,struct
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parent
def clear():
 for ob in list(bpy.context.scene.objects):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.context.view_layer.update()
def activate(ob):
 bpy.context.view_layer.update()
 for o in bpy.context.view_layer.objects:
  if o:o.select_set(False)
 ob.hide_set(False);ob.select_set(True);bpy.context.view_layer.objects.active=ob
def load_blend(folder,names):
 path=next((ROOT/'sources'/folder).rglob('*.blend'))
 return load_blend_path(path,names)
def load_blend_path(path,names=None):
 with bpy.data.libraries.load(str(path),link=False) as (s,d):d.objects=s.objects
 for ob in d.objects:
  if ob:bpy.context.scene.collection.objects.link(ob)
 bpy.context.view_layer.update();result=[]
 for ob in d.objects:
  if not ob:continue
  if ob.type=='MESH' and (names is None or ob.name in names):
   if ob.data.shape_keys:ob.shape_key_clear()
   # Keep shape-producing modifiers, drop render subdivision and UI node helpers.
   for mod in list(ob.modifiers):
    if mod.type in ['SUBSURF','NODES','EDGE_SPLIT']:ob.modifiers.remove(mod)
   activate(ob)
   for mod in list(ob.modifiers):
    try:bpy.ops.object.modifier_apply(modifier=mod.name)
    except RuntimeError:ob.modifiers.remove(mod)
   world=ob.matrix_world.copy();ob.parent=None;ob.matrix_world=Matrix.Identity(4);ob.data.transform(world);result.append(ob)
  else:bpy.data.objects.remove(ob,do_unlink=True)
 return result
def load_gltf(path):
 # Godot exports hidden suppressors with this new optional visibility extension;
 # Blender 5.2 cannot read it yet. Visibility is restored by our Godot importer.
 if path.suffix=='.glb':
  raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length])
  if 'KHR_node_visibility' in doc.get('extensionsUsed',[]):
   for key in ['extensionsUsed','extensionsRequired']:
    if key in doc:doc[key]=[e for e in doc[key] if e!='KHR_node_visibility']
   for node in doc.get('nodes',[]):node.get('extensions',{}).pop('KHR_node_visibility',None)
   encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);tail=raw[20+length:]
   path=Path('/tmp/fps-fidelity-visible.glb');path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(tail))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+tail)
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path))
 return [o for o in bpy.data.objects if o not in before]
def bounds(objects):
 pts=[o.matrix_world@v.co for o in objects if o.type=='MESH' for v in o.data.vertices]
 return Vector([min(p[i] for p in pts) for i in range(3)]),Vector([max(p[i] for p in pts) for i in range(3)])
def transform_meshes(objects,matrix):
 bpy.context.view_layer.update()
 for ob in objects:
  if ob.type!='MESH':continue
  world=ob.matrix_world.copy();ob.parent=None;ob.matrix_world=Matrix.Identity(4);ob.data.transform(matrix@world)
def canonical(objects,forward='+Y',length=1.0):
 if forward=='-Y':transform_meshes(objects,Matrix.Rotation(math.pi,4,'Z'))
 elif forward=='+X':transform_meshes(objects,Matrix.Rotation(math.pi/2,4,'Z'))
 elif forward=='-X':transform_meshes(objects,Matrix.Rotation(-math.pi/2,4,'Z'))
 lo,hi=bounds(objects);scale=length/(hi.y-lo.y)
 transform_meshes(objects,Matrix.Scale(scale,4)@Matrix.Translation(-Vector(((lo.x+hi.x)*.5,lo.y,(lo.z+hi.z)*.5))))
 return objects
def reduce(ob,budget):
 count=sum(len(p.vertices)-2 for p in ob.data.polygons)
 if count>budget:
  activate(ob);m=ob.modifiers.new('Game mesh reduction','DECIMATE');m.ratio=budget/count;m.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=m.name)
def modern_materials(objects):
 cache={}
 for ob in objects:
  if ob.type!='MESH':continue
  if not ob.data.materials:
   mat=bpy.data.materials.new('Parkerized donor steel');mat.diffuse_color=(.16,.19,.22,1);ob.data.materials.append(mat)
  for slot in ob.material_slots:
   old=slot.material
   if not old:continue
   if old not in cache:
    mat=bpy.data.materials.new(old.name+' game');mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=old.diffuse_color;p.inputs['Roughness'].default_value=.57;p.inputs['Metallic'].default_value=.35
    if old.use_nodes:
     textures=[n for n in old.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.size[0]>0]
     texture=next((n for n in textures if not any(w in n.image.name.lower() for w in ['normal','rough','bump','orm','hdr','spec'])),None)
     if texture:
      im=mat.node_tree.nodes.new('ShaderNodeTexImage');im.image=texture.image;mat.node_tree.links.new(im.outputs['Color'],p.inputs['Base Color'])
    cache[old]=mat
   slot.material=cache[old]
def export(path,objects):
 bpy.context.view_layer.update()
 for ob in bpy.context.view_layer.objects:
  if ob:ob.select_set(False)
 for ob in objects:ob.hide_set(False);ob.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(path),use_selection=True,export_animations=False,export_extras=True)
CATALOG={
 'minigun':('25753',['trigger','stabilizer mid','stabilizer front','main body','handle','controls','barrels'],'+Y'),
 'painted':('12345',['gun'],'-Y'),
 'alpha':('8856',['Alpha_Ray_Gun'],'+Y'),
 'sentinel':('22552',['gun'],'-Y'),
 'kit':('12291',['Main','Magazine','Muzzle_Short','Stock_Light'],'+X'),
 'marine_pistol':('futuristic-weapons',['Pistol2'],'-Y'),
 'marine_smg':('futuristic-weapons',['SMG1'],'-Y'),
 'marine_rifle':('futuristic-weapons',['Rifle'],'-Y'),
}
if __name__=='__main__':
 out=ROOT/'catalog';out.mkdir(exist_ok=True);(out/'.gdignore').touch();report={}
 for key,(folder,names,forward) in CATALOG.items():
  clear();obs=load_blend(folder,names)
  if key=='kit':transform_meshes(obs,Matrix.Rotation(math.pi/2,4,'X'))
  canonical(obs,forward)
  total=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs)
  for ob in obs:reduce(ob,max(100,int(10000*sum(len(p.vertices)-2 for p in ob.data.polygons)/max(total,1))))
  modern_materials(obs);export(out/(key+'.glb'),obs);report[key]=[{'name':o.name,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)} for o in obs]
 for path in (ROOT/'converted').glob('*.glb'):
  clear();obs=load_gltf(path);meshes=[o for o in obs if o.type=='MESH'];lo,hi=bounds(meshes)
  # 3DS assets have a common Y-longitudinal coordinate convention.
  canonical(meshes,'-Y');modern_materials(meshes);export(out/('gunz_'+path.name),meshes)
 (out/'report.json').write_text(json.dumps(report,indent=2))
 print('DONOR_CATALOG_COMPLETE',flush=True)
 import os;os._exit(0)
