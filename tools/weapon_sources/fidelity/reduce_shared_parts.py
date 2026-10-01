"""Reduce selected donor parts in editable blends; export only replacements.
Run with Blender --background --python. Backups make reruns deterministic.
"""
import bpy, json, sys, shutil, math
from pathlib import Path
from mathutils.bvhtree import BVHTree
from mathutils import Vector
from mathutils.geometry import barycentric_transform
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from shared_part_budgets import TARGETS, part_budget
OUT = ROOT.parents[2] / 'test-results/weapon-shared-reduction'
OUT.mkdir(exist_ok=True)
def triangles(ob): return sum(len(p.vertices)-2 for p in ob.data.polygons)
def geometry(ob):
    ob.data.calc_loop_triangles()
    return [ob.matrix_world @ v.co for v in ob.data.vertices], [tuple(t.vertices) for t in ob.data.loop_triangles]
def samples(verts, faces):
    return verts + [sum((verts[i] for i in f), verts[0]*0)/3 for f in faces]
def deviation(old, new):
    values=[]
    for source, target in ((old,new), (new,old)):
        tree=BVHTree.FromPolygons(*target, all_triangles=True)
        values += [tree.find_nearest(v)[3] for v in samples(*source)]
    values.sort()
    return {'sample_count':len(values), 'p99_m':values[int(len(values)*.99)], 'max_m':values[-1]}
rows=[]
for key, names in TARGETS.items():
    path=ROOT/'refined'/(key+'.blend'); backup=OUT/(key+'-before.blend')
    if not backup.exists(): shutil.copy2(path, backup)
    bpy.ops.wm.open_mainfile(filepath=str(backup))
    bpy.context.view_layer.update()
    parts=[]
    for name in names:
        ob=bpy.data.objects.get(name); assert ob is not None, (key,name)
        for obj in list(bpy.context.scene.objects):
            if obj is not None: obj.select_set(False)
        ob.hide_set(False); ob.select_set(True); bpy.context.view_layer.objects.active=ob
        old=geometry(ob); before=triangles(ob); budget=part_budget(key,name)
        # Decimate drops custom split normals. Transfer the authored shading
        # back so broad planar panels do not turn into smooth, lumpy surfaces.
        original_vertices=[v.co.copy() for v in ob.data.vertices]
        original_faces=[tuple(t.vertices) for t in ob.data.loop_triangles]
        original_normals=[tuple(ob.data.corner_normals[i].vector.copy() for i in t.loops) for t in ob.data.loop_triangles]
        normal_tree=BVHTree.FromPolygons(original_vertices,original_faces,all_triangles=True)
        mod=ob.modifiers.new('Shared donor triangle budget','DECIMATE')
        mod.ratio=min(1, budget/before); mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        normals=[None]*len(ob.data.loops)
        for face in ob.data.polygons:
            center=sum((ob.data.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
            for loop_index in face.loop_indices:
                vertex=ob.data.vertices[ob.data.loops[loop_index].vertex_index].co
                # Sample just inside this face, avoiding ambiguous normals on
                # coincident vertices at hard edges and UV seams.
                point,_,triangle,_=normal_tree.find_nearest(vertex.lerp(center,.001))
                coords=[original_vertices[i] for i in original_faces[triangle]]
                normals[loop_index]=barycentric_transform(point,*coords,*original_normals[triangle]).normalized()
        ob.data.normals_split_custom_set(normals)
        assert triangles(ob)<=budget+2, (key,name,triangles(ob),budget)
        parts.append({'name':name,'before':before,'after':triangles(ob),'budget':budget,'surface_deviation':deviation(old,geometry(ob))})
    for obj in list(bpy.context.scene.objects):
        if obj is not None: obj.select_set(obj.name in names)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'-parts.glb')),use_selection=True,export_animations=False,export_extras=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    rows.append({'key':key,'parts':parts})
    print('REDUCED',key,json.dumps(parts),flush=True)
(OUT/'source-counts.json').write_text(json.dumps(rows,indent=2))
