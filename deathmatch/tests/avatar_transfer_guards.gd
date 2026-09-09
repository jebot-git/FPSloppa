extends SceneTree
const Network = preload("res://deathmatch/avatars/network.gd")
const Library = preload("res://deathmatch/avatars/library.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var service := Network.new()
	root.add_child(service)
	DirAccess.make_dir_recursive_absolute(Library.CACHE)
	var hash := "b".repeat(64)
	for scenario in ["out_of_order","chunk_limit","declared_size"]:
		var path := Library.CACHE+"guard-test.part"
		var file := FileAccess.open(path,FileAccess.WRITE)
		service.incoming[hash] = {"peer":0,"file":file,"path":path,"offset":0,"size":100,"time":0}
		var bytes := PackedByteArray()
		bytes.resize(Network.CHUNK+1 if scenario=="chunk_limit" else 101 if scenario=="declared_size" else 10)
		service._chunk(hash,1 if scenario=="out_of_order" else 0,bytes)
		check(not service.incoming.has(hash) and not FileAccess.file_exists(path),"reject "+scenario+" and remove partial file")
	service.expected[hash] = {"peer":0,"size":Library.MAX_BYTES+1}
	service._begin(hash,Library.MAX_BYTES+1)
	check(service.incoming.is_empty(),"25 MB enforced at transfer start")
	service.expected[hash] = {"peer":99,"size":10}
	service._begin(hash,10)
	check(service.incoming.is_empty(),"only expected sender can start transfer")
	service._begin("../escape",10)
	check(service.incoming.is_empty(),"unsolicited filename cannot create a file")
	service.free()
	print("AVATAR_GUARDS_RESULT failures=",failures)
	quit(1 if failures else 0)
