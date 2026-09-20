extends Node
## CQ package entrypoint. No default arena server, lobby or alternate mode.
func _ready() -> void:run.call_deferred()
func option(args: PackedStringArray,key: String) -> String:
	var index:=args.find(key)
	return args[index+1] if index>=0 and index+1<args.size() else ""
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.has("--cluster-worker"):
		var arena=load("res://deathmatch/arena.tscn").instantiate();get_tree().root.add_child(arena);queue_free();return
	var service:=option(args,"--cq-service")
	if service=="vrm":
		var inspected: Dictionary=preload("res://deathmatch/avatars/library.gd").inspect(option(args,"--file"))
		if inspected.has("error"):print("VRM_REJECT ",inspected.error);get_tree().quit(2);return
		print("VRM_ACCEPT");get_tree().quit();return
	if service=="edge":
		var settings=JSON.parse_string(FileAccess.get_file_as_string(option(args,"--config")))
		if not settings is Dictionary or not settings.has_all(["backend","listen","routes"]):get_tree().quit(2);return
		var edge=preload("res://deathmatch/server/cluster/edge.gd").new();edge.name="ClusterEdge";get_tree().root.add_child(edge)
		if edge.host(settings)!=OK:get_tree().quit(2);return
		Engine.max_fps=120;print("CLUSTER_ENET_READY port=",settings.listen[1]);return
	push_error("This package runs CQ workers, CQ gateways or VRM validation only. Use a CQ .cfg deployment.")
	get_tree().quit(2)
