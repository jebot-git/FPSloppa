"""Convert CC0 OGA sniper and gatling; original source geometry stays untouched.
Run Blender --background --disable-autoexec --python this_file.py.
"""
import bpy,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/weapon_sources/refined'
report={}
for kind,source in [('sniper','sniper/Sniper_1A.blend'),('sentry_gatling','gatling/mini_gun.blend')]:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/weapon_sources/oga'/source),load_ui=False,use_scripts=False)
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
 bpy.context.view_layer.objects.active=objects[0]
 if objects[0].mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 for o in bpy.context.scene.objects:o.select_set(False)
 if kind=='sniper':
  # Scope is already a hollow tube. Only the two opaque glass caps are omitted;
  # the runtime optic supplies the rear lens, reticle and magnified camera view.
  objects=[o for o in objects if o.name!='Lens']
  image=bpy.data.images.load(str(ROOT/'tools/weapon_sources/oga/sniper/Sniper_Pallet.png'),check_existing=False)
  material=bpy.data.materials.new('FFMStudios original olive palette');material.use_nodes=True
  bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.65
  tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest'
  material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
 else:
  for material in bpy.data.materials:
   legacy=next((n for n in material.node_tree.nodes if n.type=='BSDF_DIFFUSE'),None) if material.node_tree else None
   color=tuple(legacy.inputs['Color'].default_value) if legacy else tuple(material.diffuse_color);material.use_nodes=True
   material.node_tree.nodes.clear()
   shader=material.node_tree.nodes.new('ShaderNodeBsdfPrincipled');output=material.node_tree.nodes.new('ShaderNodeOutputMaterial');material.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface'])
   bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=color;bsdf.inputs['Metallic'].default_value=.45;bsdf.inputs['Roughness'].default_value=.55
 triangles=0
 for o in objects:
  world=o.matrix_world.copy()
  for v in o.data.vertices:
   p=world@v.co
   # Sniper -X forward / +Z up; gatling -Y forward / +Z up.
   v.co=Vector((p.y*.15,(2-p.x)*.15,(p.z-.65)*.15)) if kind=='sniper' else Vector((-p.x*.16,-p.y*.16,p.z*.16))
  o.matrix_world=Matrix.Identity(4)
  if kind=='sniper':
   o.data.materials.clear();o.data.materials.append(material)
   for p in o.data.polygons:p.material_index=0
  o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles);o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
 report[kind]={'triangles':triangles,'source':source}
 print('WEAPON_EXPORT',kind,triangles,flush=True)
(OUT/'sniper-turret-audit.json').write_text(json.dumps(report,indent=2)+'\n')
