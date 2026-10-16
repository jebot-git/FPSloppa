extends SceneTree
const Scenery=preload("res://tools/voxel_battle/native_environment.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
class Stream extends Node:
 signal tile_loaded(coord,data)
 signal tile_evicted(coord)
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var stream:=Stream.new();root.add_child(stream)
 var reference:=Scenery.new();reference.native_world=null;stream.add_child(reference);reference.setup(stream)
 var actual:=Scenery.new();stream.add_child(actual);actual.setup(stream)
 var camera:=Camera3D.new();stream.add_child(camera);camera.position=Vector3(-100,5,-100);camera.far=600
 var rng:=RandomNumberGenerator.new();rng.seed=171019
 for z in range(33,50):
  for x in range(33,50):
   var rows:Array=[]
   for i in 16:rows.append({"kind":rng.randi_range(0,2),"position":Vector3(x*Landscape.TILE-Landscape.EXTENT*.5+rng.randf()*Landscape.TILE,0,z*Landscape.TILE-Landscape.EXTENT*.5+rng.randf()*Landscape.TILE),"scale":rng.randf_range(.75,1.25),"angle":rng.randf()*TAU})
   stream.tile_loaded.emit(Vector2i(x,z),{"features":rows,"height_bounds":Vector2(0,0)})
 var reference_us:=0;var native_us:=0;var error:=0.0
 for step in 30:
  camera.position.x+=1.5;camera.rotate_y(.08)
  reference.dirty=true;actual.dirty=true
  var begin:=Time.get_ticks_usec();reference.update(camera);reference_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();actual.update(camera);native_us+=Time.get_ticks_usec()-begin
  check(actual.counts==reference.counts,"stereo culling and LOD counts parity "+str(step))
  var bounds:Array=[]
  for kind in 3:bounds.append(reference.variants.mesh[kind][0].get_aabb())
  # Native buffers remain inspectable headless; compare selected transforms to reference rows.
  var selected:Dictionary=actual.native_world.trees_select(camera.global_position,camera.get_frustum(),true,false,actual.CAPACITY,actual.VIEW_DISTANCE)
  var offsets:Array=[0,0,0,0,0,0,0,0,0]
  for tile in reference.tiles.values():
   if reference.Stream.outside_frustum(tile.bounds,camera.get_frustum()):continue
   for row in tile.rows:
    if Vector2(camera.global_position.x-row.position.x,camera.global_position.z-row.position.z).length()>reference.VIEW_DISTANCE:continue
    var transform:=Transform3D(Basis(Vector3.UP,row.angle).scaled(Vector3.ONE*row.scale),row.position)
    if reference.Stream.outside_frustum(transform*bounds[row.kind],camera.get_frustum()):continue
    var group:int=row.kind*3+row.lod;var data:PackedFloat32Array=selected.buffers[group]
    for r in 3:
     for c in 3:error=maxf(error,absf(data[offsets[group]*12+r*4+c]-transform.basis[c][r]))
     error=maxf(error,absf(data[offsets[group]*12+r*4+3]-transform.origin[r]))
    offsets[group]+=1
 check(error<.0001,"selected tree transforms and ordering parity: "+str(error))
 stream.tile_evicted.emit(Vector2i(40,40));reference.dirty=true;actual.dirty=true;reference.update(camera);actual.update(camera)
 check(actual.counts==reference.counts,"eviction and native residency agree")
 print("CQ_NATIVE_TREES ",JSON.stringify({"checks":checks,"failures":failures,"max_error":error,"reference_mean_us":reference_us/30.,"native_mean_us":native_us/30.}))
 stream.free();quit(0 if failures.is_empty() else 1)
