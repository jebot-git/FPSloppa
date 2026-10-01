"""Measure actual mesh proximity to preserved VR palm anchors, not metadata alone."""
import bpy,json,sys,os
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parent;sys.path.insert(0,str(ROOT))
from workshop import clear,load_gltf
from dimensions import anchors as fitted_anchors
anchors=fitted_anchors();report=[]
for key,row in anchors.items():
 path=ROOT/'refined'/(key+'.glb')
 if not path.exists():continue
 clear();objects=load_gltf(path);bpy.context.view_layer.update();vertices=[];faces=[]
 for ob in objects:
  if ob.type!='MESH':continue
  offset=len(vertices);vertices.extend(ob.matrix_world@v.co for v in ob.data.vertices);faces.extend(tuple(i+offset for i in p.vertices) for p in ob.data.polygons)
 grip=Vector((row['grip'][0],-row['grip'][2],row['grip'][1]));tree=BVHTree.FromPolygons(vertices,faces);hit=tree.find_nearest(grip)
 muzzle=Vector((row['muzzle'][0],-row['muzzle'][2],row['muzzle'][1]));front=tree.find_nearest(muzzle)
 report.append({'key':key,'palm_surface_distance_m':hit[3] if hit else None,'nearest':list(hit[0]) if hit else None,'muzzle_surface_distance_m':front[3] if front else None,'physical_front_m':max(v.y for v in vertices),'muzzle_forward_m':muzzle.y})
out=ROOT.parents[2]/'test-results/weapon-fidelity/physical-fit.json';out.write_text(json.dumps(report,indent=2))
print('PALM_FIT',[(r['key'],round(r['palm_surface_distance_m'],4)) for r in report if r['palm_surface_distance_m']>.055],flush=True)
os._exit(0)
