extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	var service=game.map_network
	var hash: String="a".repeat(64)
	service.expected={"hash":hash,"size":128_000_001,"title":"Test"}
	service._begin(hash,128_000_001)
	check(service.incoming.is_empty(),"Oversized BSP rejected at transfer start")
	service.reset()
	service._begin(hash,1024)
	check(service.incoming.is_empty(),"Unsolicited BSP transfer rejected")
	DirAccess.make_dir_recursive_absolute("user://maps")
	var path:="user://maps/test-guard.download"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	service.incoming={"hash":hash,"size":124,"offset":0,"file":file,"path":path}
	service._chunk(hash,1,PackedByteArray([1,2]))
	check(service.incoming.is_empty() and not FileAccess.file_exists(path),"Out-of-order chunk cancels and removes partial file")
	var data:=FileAccess.get_file_as_bytes("res://deathmatch/maps/raw/lqdm1.bsp")
	var texture_offset:=data.decode_u32(20)
	data.encode_u32(texture_offset,1000000)
	file=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
	check(not game.Maps.validate(path).is_empty(),"Malformed texture table rejected before importer")
	DirAccess.remove_absolute(path)
	game.queue_free()
	print("MAP_GUARD_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
