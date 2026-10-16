extends SceneTree
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Grass=preload("res://tools/voxel_battle/grass_cover.gd")
func _initialize()->void:
 Landscape.prepare_roads()
 var samples:Array=[];var rng:=RandomNumberGenerator.new();rng.seed=1437
 for i in 512:
  var x:=rng.randf_range(-1410,1410);var z:=rng.randf_range(-1410,1410);var p:=Vector3(x,Landscape.surface(x,z).x,z)
  samples.append({"point":[p.x,p.y,p.z],"height":p.y,"grass":Grass.contains(p),"water":[Landscape.Hydrology.sample(p.x,p.z).x,Landscape.Hydrology.sample(p.x,p.z).y]})
 var f:=FileAccess.open("res://native_server/cooked/reference_samples.json",FileAccess.WRITE);f.store_string(JSON.stringify(samples));f.close();print("CQ_REFERENCE_SAMPLES ",samples.size());quit()
