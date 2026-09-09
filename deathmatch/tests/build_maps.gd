extends SceneTree
const Loader = preload("res://deathmatch/maps/loader.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for row in Loader.catalog():
		var map := Loader.read(row.path)
		if not map: quit(1); return
		var packed := PackedScene.new()
		var err := packed.pack(map)
		if err==OK: err = ResourceSaver.save(packed,row.scene)
		print("MAP_BUILT ",row.id," ",error_string(err)," children=",map.get_child_count())
		map.free()
		if err!=OK: quit(1); return
	quit()
