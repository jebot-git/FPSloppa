"""Build the MCP-procured Desert Bike, with shared runtime/native seat sockets."""
import bpy,json,math,struct,shutil
from pathlib import Path
from mathutils import Matrix,Vector
import sys
sys.path.insert(0,str(Path(__file__).parent))
import build_tiers as assets
ROOT=assets.ROOT;SOURCE=ROOT/'test-results/bike-source';OUT=ROOT/'deathmatch/models/desert_bike';OUT.mkdir(parents=True,exist_ok=True)
assets.OUT=OUT
AUTH=ROOT/'tools/cq_assets/bike_authoring';AUTH.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
objects=assets.load(SOURCE/'desertbike.blend');assets.evaluated(objects)
# Freeze legacy Child Of constraints after evaluating their visible geometry.
for o in objects:
 o.constraints.clear();o.animation_data_clear();o.parent=None;o.matrix_world=Matrix.Identity(4)
bpy.context.view_layer.update()
turn=Matrix.Rotation(math.pi,4,'Z')
for o in objects:
 o.data.transform(turn);o.hide_render=False;o.hide_viewport=False;o.hide_set(False)
lo,hi=assets.bounds(objects);scale=3.4/(hi.y-lo.y);center=Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z))
for o in objects:
 for v in o.data.vertices:
  v.co=(v.co-center)*scale
  if "pedal" in o.name:v.co.x*=.68;v.co.y+=.83
 if 'handle' in o.name:o.name='ChargingHandle'
assets.reduce(objects,6500,preserve_detail=True)
parts=assets.bake(objects,'bike');pivot=Vector((0,.47,.99)) # game Z -0.47, Y 0.99
for part in parts:
 if part.name=='ChargingHandle':
  part.name='Handlebars';part.data.transform(Matrix.Translation(-pivot));part.location=pivot
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.wm.save_as_mainfile(filepath=str(AUTH/'bike.blend'),check_existing=False)
bpy.ops.export_scene.gltf(filepath=str(OUT/'bike.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
raw=(OUT/'bike.glb').read_bytes();g=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
tri=sum(g['accessors'][p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives'])
meta={'source':json.loads((SOURCE/'source.json').read_text()),'triangles':tri,'materials':1,'texture_size':[1024,1024],'size':[1.14,1.25,3.4],'seat':[0,.17,.15],'eye_height':1.65,'steering_pivot':[0,.99,-.47],'grips':[[-.43,0,0],[.43,0,0]],'maximum_steering_degrees':35,'hp':50,'forward_speed':24,'reverse_speed':0,'respawn_seconds':120}
assert tri<=7000
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n');shutil.copyfile(SOURCE/'BLENDSWAP_LICENSE.txt',OUT/'LICENSE.txt');print('CQ_BIKE_BUILT',tri)
