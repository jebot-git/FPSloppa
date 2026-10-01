"""Reduce the shared sculpted Tribes stock to <1k triangles, preserving baked UVs."""
import bpy,json,sys,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[2]/'test-results/weapon-stock';OUT.mkdir(exist_ok=True)
rows=[]
for key in ['tribes_1','tribes_2','tribes_4','tribes_5','tribes_7']:
 path=ROOT/'refined'/(key+'.blend')
 backup=OUT/(key+'-before.blend')
 if not backup.exists():shutil.copy2(path,backup)
 bpy.ops.wm.open_mainfile(filepath=str(backup))
 ob=bpy.data.objects.get('SculptedShoulderStock');assert ob
 for obj in bpy.context.view_layer.objects:obj.select_set(False)
 ob.hide_set(False);ob.select_set(True);bpy.context.view_layer.objects.active=ob
 count=lambda:sum(len(p.vertices)-2 for p in ob.data.polygons)
 before=count()
 mod=ob.modifiers.new('Stock game budget — 960 triangles','DECIMATE');mod.ratio=960/before;mod.use_collapse_triangulate=True
 bpy.ops.object.modifier_apply(modifier=mod.name)
 assert count()<=1000,(key,count())
 bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'-stock.glb')),use_selection=True,export_animations=False,export_extras=True)
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(path))
 rows.append({'key':key,'before':before,'after':count()})
(OUT/'source-counts.json').write_text(json.dumps(rows,indent=2))
print('STOCK_REDUCED',json.dumps(rows),flush=True)
