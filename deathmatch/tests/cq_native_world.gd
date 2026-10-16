extends SceneTree
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const NativeLandscape=preload("res://tools/voxel_battle/native_landscape.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var native_source=NativeLandscape.new();check(native_source.native_world!=null,"native world available")
 var rng:=RandomNumberGenerator.new();rng.seed=171017
 var maximum:=0.0;var color_error:=0.0
 for i in 2000:
  var x:=rng.randf_range(-1400,1400);var z:=rng.randf_range(-1400,1400)
  var reference:=Landscape.surface(x,z);var actual:Vector4=native_source.native_world.terrain_surface(x,z)
  maximum=maxf(maximum,absf(reference.x-actual.x));color_error=maxf(color_error,Vector3(reference.y-actual.y,reference.z-actual.z,reference.w-actual.w).length())
 check(maximum<.01,"native terrain height parity: "+str(maximum))
 check(color_error<.005,"native terrain color parity: "+str(color_error))
 var reference_source:=Landscape.new()
 var reference_us:=0;var native_us:=0
 for coord in [Vector2i(12,35),Vector2i(44,44),Vector2i(24,68),Vector2i(68,22)]:
  var begin:=Time.get_ticks_usec();var old:Dictionary=reference_source.generate_tile(coord);reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();var next:Dictionary=native_source.generate_tile(coord);native_us+=Time.get_ticks_usec()-begin
  var a:PackedFloat32Array=old.heights.to_float32_array();var b:PackedFloat32Array=next.heights.to_float32_array()
  var error:=0.0
  for i in a.size():error=maxf(error,absf(a[i]-b[i]))
  check(error<.01,"tile height parity "+str(coord))
  var trees_match:bool=old.features.size()==next.features.size()
  for i in mini(old.features.size(),next.features.size()):
   var a_tree:Dictionary=old.features[i];var b_tree:Dictionary=next.features[i]
   trees_match=trees_match and a_tree.kind==b_tree.kind and a_tree.scale==b_tree.scale and a_tree.angle==b_tree.angle and a_tree.position.distance_to(b_tree.position)<.01
  check(trees_match,"seeded tree identity and terrain-height parity "+str(coord))
  check(old.grass.size()==next.grass.size(),"grass density preserved "+str(coord))
 var camera:=Camera3D.new();root.add_child(camera)
 var stream=load("res://tools/streamed_heightfield/stream.gd").new();root.add_child(stream)
 stream.extent=Landscape.EXTENT;stream.grid=Landscape.GRID;stream.tile_side=Landscape.TILE
 for i in 20:
  camera.position=Vector3(rng.randf_range(-1300,1300),0,rng.randf_range(-1300,1300))
  stream.select_tiles(camera)
  var plan:Dictionary=native_source.native_world.terrain_plan(camera.position,[],[],Landscape.TILE,Landscape.EXTENT,Landscape.GRID,false)
  check(plan.desired.size()==stream.desired.size() and plan.desired.all(func(k):return stream.desired.has(k)),"native streaming residency parity "+str(i))
  check(plan.queue.size()==stream.queue.size() and plan.queue[0]==stream.queue[0],"nearest-first generation admission parity "+str(i))
 var selected:Dictionary=native_source.native_world.terrain_select([Vector2i(44,44),Vector2i(45,44)],[AABB(Vector3(-20,-1,-20),Vector3(40,10,40)),AABB(Vector3(10,-1,-20),Vector3(40,10,40))],PackedInt32Array([7,8]),Vector3.ZERO,[],false,false,Landscape.TILE,Landscape.EXTENT,384)
 check(selected.counts[0]==2 and selected.buffers[0][12]==7 and selected.buffers[0][28]==8,"terrain bulk transform and atlas slot layout")
 stream.coarse_node.free();stream.free();camera.free()
 print("CQ_NATIVE_WORLD ",JSON.stringify({"checks":checks,"failures":failures,"height_error":maximum,"color_error":color_error,"reference_tile_mean_us":reference_us/4.,"native_tile_mean_us":native_us/4.}))
 quit(0 if failures.is_empty() else 1)
