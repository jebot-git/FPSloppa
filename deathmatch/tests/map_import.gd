extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(not Maps.validate("res://project.godot").is_empty(),"Non-BSP file rejected")
	var row=Maps.import_custom("res://deathmatch/maps/raw/lqdm1.bsp")
	check(row.get("id","")=="lqdm1","Bundled BSP deduplicates by content hash")
	var bytes=FileAccess.get_file_as_bytes("res://deathmatch/maps/raw/lqdm2.bsp")
	bytes.append_array(" custom import test".to_utf8_buffer())
	var path="user://test_custom.bsp"
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	row=Maps.import_custom(path)
	check(not row.has("error"),"Custom BSP compiles and caches")
	if not row.has("error"):
		check(row.sha256==FileAccess.get_sha256(path),"Custom map identity uses source SHA256")
		check(Maps.catalog().any(func(entry): return entry.id==row.id),"Custom map persists in catalog")
		var game=load("res://deathmatch/arena.tscn").instantiate()
		root.add_child(game)
		check(game._load_map(row.id),"Cached custom scene loads into arena")
		check(game.spawn_points.size()==8,"Custom entity metadata survives scene cache")
		game.queue_free()
	for id in range(9):
		var weapon=load("res://deathmatch/art.gd").weapon(id)
		var meshes=weapon.find_children("*","MeshInstance3D",true,false)
		check(not meshes.is_empty() and meshes.any(func(mesh): return mesh.mesh is ArrayMesh),"Weapon %d uses imported mesh asset"%id)
		weapon.free()
	print("MAP_IMPORT_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
