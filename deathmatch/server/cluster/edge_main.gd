extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	var settings=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not settings is Dictionary or not settings.has_all(["backend","listen","routes"]):quit(2);return
	var edge=preload("res://deathmatch/server/cluster/edge.gd").new();edge.name="ClusterEdge";root.add_child(edge)
	if edge.host(settings)!=OK:quit(2);return
	Engine.max_fps=120;print("CLUSTER_ENET_READY port=",settings.listen[1])
