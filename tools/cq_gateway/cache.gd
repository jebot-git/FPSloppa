extends SceneTree
func _initialize():
	create_timer(60).timeout.connect(func():quit(2))
	run.call_deferred()
func run() -> void:
	var Maps=preload("res://deathmatch/maps/loader.gd")
	var Cache=preload("res://deathmatch/server/districts/geometry_cache.gd")
	var path:="res://maps/Benchmark1km/prototype_km1.bsp"
	assert(FileAccess.get_sha256(path)==Cache.HASH)
	var world=Maps.read(path,true);assert(world!=null)
	preload("res://deathmatch/server/geometry.gd").strip(world)
	var packed:=PackedScene.new();assert(packed.pack(world)==OK)
	DirAccess.make_dir_recursive_absolute(Cache.PATH.get_base_dir())
	assert(ResourceSaver.save(packed,Cache.PATH)==OK)
	print("CQ_COLLISION_CACHE ",FileAccess.get_sha256(Cache.PATH))
	world.free();quit()
