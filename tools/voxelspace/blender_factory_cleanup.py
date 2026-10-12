"""Run through Blender MCP in the isolated CQ Factory Optimization scene."""
import bpy,json,math
from pathlib import Path
from mathutils import Euler,Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/factory-optimization'
tokens=(OUT/'factory-union.off').read_text().split()
nv,nf=map(int,tokens[1:3]);cursor=4
vertices=[tuple(float(v) for v in tokens[4+3*i:7+3*i]) for i in range(nv)]
cursor+=3*nv
faces=[]
for i in range(nf):
 n=int(tokens[cursor]);faces.append(tuple(map(int,tokens[cursor+1:cursor+1+n])));cursor+=n+1
base=bpy.data.meshes.new('Factory union source');base.from_pydata(vertices,[],faces);base.update()
results=[]
for label,ratio in [('planar',None),('lod1',.55),('lod2',.2)]:
 obj=bpy.data.objects.new('Factory '+label,base.copy());bpy.context.scene.collection.objects.link(obj)
 planar=obj.modifiers.new('Merge coplanar surfaces','DECIMATE');planar.decimate_type='DISSOLVE';planar.angle_limit=.0001;planar.delimit={'NORMAL'};planar.use_dissolve_boundaries=True
 if ratio is not None:
  decimate=obj.modifiers.new('Visual distance LOD','DECIMATE');decimate.decimate_type='COLLAPSE';decimate.ratio=ratio;decimate.use_collapse_triangulate=True
 depsgraph=bpy.context.evaluated_depsgraph_get();evaluated=obj.evaluated_get(depsgraph);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
 points=[[float(v.co.x),float(v.co.z),float(-v.co.y)] for v in mesh.vertices]
 indices=[int(i) for tri in mesh.loop_triangles for i in tri.vertices]
 (OUT/('factory_blender_'+label+'.json')).write_text(json.dumps({'vertices':points,'indices':indices},separators=(',',':')))
 results.append({'variant':label,'vertices':len(points),'triangles':len(indices)//3,'bounds':[[min(p[a] for p in points),max(p[a] for p in points)] for a in range(3)]})
 evaluated.to_mesh_clear()
 if ratio is not None:obj.hide_set(True);obj.hide_render=True
 else:bpy.context.view_layer.objects.active=obj;obj.select_set(True)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_location=Vector((0,0,13));area.spaces.active.region_3d.view_distance=150;area.spaces.active.region_3d.view_rotation=Euler((math.radians(67),0,math.radians(35))).to_quaternion()
(OUT/'blender-cleanup.json').write_text(json.dumps({'blender':bpy.app.version_string,'variants':results},indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'factory-optimization.blend'))
print(json.dumps(results))
