"""Prepare audited OGA and LibreQuake donors without running source scripts."""
import sys,os
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from workshop import *

def relink(folder):
 for im in bpy.data.images:
  name=Path(im.filepath.replace('\\','/')).name
  found=list(folder.rglob(name)) if name else []
  if found:
   im.filepath=str(found[0]);im.reload()

for p in (ROOT/'sources/librequake/lq1/progs/src').glob('g*.blend'):
 clear();obs=load_blend_path(p);relink(ROOT/'sources/librequake');canonical(obs,'+X');modern_materials(obs);export(ROOT/'catalog'/('lq_'+p.stem+'.glb'),obs)
for slug,forward in [('retro-style-pistol-lowpoly','+Y'),('sci-fi-rifle','+Y'),('fallout-shelter-laser-pistol','-X'),('3rd-person-blender-sci-fi-pack','-X'),('akira-laser-rifle-st-001','-Y'),('energy-rifle','-Y')]:
 clear();folder=ROOT/'sources'/slug
 if slug in ['fallout-shelter-laser-pistol','energy-rifle']:
  bpy.ops.import_scene.fbx(filepath=str(next(folder.rglob('*.FBX' if slug=='fallout-shelter-laser-pistol' else '*.fbx'))));obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];transform_meshes(obs,Matrix.Identity(4))
 else:obs=load_blend_path(next(folder.rglob('weapons_pack.blend' if slug=='3rd-person-blender-sci-fi-pack' else '*.blend')),['chain_saw'] if slug=='3rd-person-blender-sci-fi-pack' else ['rifle1'] if slug=='akira-laser-rifle-st-001' else None)
 relink(folder);canonical(obs,forward);modern_materials(obs)
 if slug=='3rd-person-blender-sci-fi-pack':
  img=bpy.data.images.load(str(next(folder.rglob('chain_saw_col.dds'))),check_existing=True)
  for ob in obs:
   for mat in ob.data.materials:
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 export(ROOT/'catalog'/('new_'+slug+'.glb'),obs)
os._exit(0)
