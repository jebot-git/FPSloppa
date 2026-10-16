extends "res://tools/voxel_battle/landscape.gd"
## Keep authored source/bake fingerprints unchanged; native sampling has parity tests.
var native_world
func _init()->void:
 prepare_roads();Hydrology.prepare()
 native_world=preload("res://deathmatch/native/world.gd").create()
 if native_world:
  native_world.terrain_configure({"extent":EXTENT,"tile":TILE,"roads":road_bins,"access":access_bins,"earthworks":earthwork_bins,"rivers":Hydrology.bins,"centers":CENTERS,"radii":RADII,"rocks":ROCK_FORMATIONS,"cover":COVER})
func generate_tile(coord:Vector2i)->Dictionary:
 if not native_world:return super.generate_tile(coord)
 var started:=Time.get_ticks_usec()
 var data:Dictionary=native_world.terrain_tile(coord)
 var heights:PackedFloat32Array=data.heights.to_float32_array()
 data.features=native_world.vegetation_trees(coord);data.grass=native_world.vegetation_grass(coord,heights)
 data.generation_ms=(Time.get_ticks_usec()-started)/1000.0
 return data
