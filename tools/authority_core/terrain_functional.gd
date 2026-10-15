extends SceneTree
const Metadata=preload("res://deathmatch/native/cq_metadata.gd")
const Landscape=Metadata.Landscape
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok and failures.size()<30:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var authority=ClassDB.instantiate("FPSAuthority");check(authority.configure_terrain(Metadata.terrain()),"cold authored terrain import")
 var rng:=RandomNumberGenerator.new();rng.seed=87903421
 for index in 12000:
  var x:=rng.randf_range(-Landscape.EXTENT*.5,Landscape.EXTENT*.5);var z:=rng.randf_range(-Landscape.EXTENT*.5,Landscape.EXTENT*.5)
  var point:=Vector3(x,0,z);var sample:Dictionary=authority.terrain_sample(point);var expected:=Landscape.water_sample(x,z)
  check(absf(sample.water.x-expected.x)<.00005,"water mask native/reference")
  if expected.x>0:check(sample.water.distance_to(expected)<.0002,"water level/depth native/reference")
  for bins in [Landscape.road_bins,Landscape.access_bins]:
   var road:=Landscape.nearest_road(Vector2(x,z),bins)
   if road.is_empty():continue
   point.y=lerpf(road.road.a.y,road.road.b.y,road.t)
   check(authority.terrain_sample(point).road==Landscape.is_road(x,z),"road painted boundary native/reference")
   point.y+=10;check(not authority.terrain_sample(point).road,"upper floors do not inherit asphalt bonus")
 print("AUTHORITY_TERRAIN_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
