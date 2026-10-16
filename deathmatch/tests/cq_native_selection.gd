extends SceneTree
const Grass=preload("res://tools/voxel_battle/grass.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
class Stream extends Node:
 signal tile_loaded(coord,data)
 signal tile_evicted(coord)
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var source:=Stream.new();root.add_child(source)
 var reference:=Grass.new();reference.native_world=null;source.add_child(reference);reference.setup(source)
 var actual:=Grass.new();source.add_child(actual);actual.setup(source)
 check(actual.native_world!=null,"native selection available")
 var camera:=Camera3D.new();source.add_child(camera);camera.position=Vector3(-100,1.7,-100)
 var rng:=RandomNumberGenerator.new();rng.seed=171025
 var total:=0
 for z in range(37,46):
  for x in range(37,46):
   var rows:=PackedVector4Array()
   for i in 400:
    rows.append(Vector4(x*Landscape.TILE-Landscape.EXTENT*.5+rng.randf()*Landscape.TILE,0,z*Landscape.TILE-Landscape.EXTENT*.5+rng.randf()*Landscape.TILE,rng.randf()*TAU))
   source.tile_loaded.emit(Vector2i(x,z),{"grass":rows,"height_bounds":Vector2(0,1)})
   total+=rows.size()
 var ref_us:=0;var native_us:=0;var error:=0.0
 for i in 18:
  camera.position.x+=.6;camera.position.z+=.3
  reference.dirty=true;actual.dirty=true
  var begin:=Time.get_ticks_usec();reference.update(camera);ref_us+=Time.get_ticks_usec()-begin
  begin=Time.get_ticks_usec();actual.update(camera);native_us+=Time.get_ticks_usec()-begin
  check(actual.counts==reference.counts and actual.candidates==reference.candidates,"selection counts and budgets match "+str(i))
  for group in 12:
   for j in reference.counts[group]*12:
    error=maxf(error,absf(reference.buffers[group][j]-actual.buffers[group][j]))
 check(error<.0001,"selected transforms match: "+str(error))
 source.tile_evicted.emit(Vector2i(40,40));reference.dirty=true;actual.dirty=true;reference.update(camera);actual.update(camera)
 check(actual.counts==reference.counts and actual.candidates==reference.candidates,"eviction removes native candidates")
 actual.set_enabled(false);actual.update(camera);check(actual.visible_tufts==0,"disabled grass empty")
 print("CQ_NATIVE_SELECTION ",JSON.stringify({"checks":checks,"failures":failures,"resident":total,"max_transform_error":error,"reference_mean_us":ref_us/18.,"native_mean_us":native_us/18.}))
 source.free();quit(0 if failures.is_empty() else 1)
