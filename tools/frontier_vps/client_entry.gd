extends Node
## Game-only release entry. Explicit connection/practice/server arguments take precedence.
func _ready()->void:
	var args:=OS.get_cmdline_user_args()
	if args.has("--authority-arena-client") or args.has("--resident-suite") or args.has("--clients") or args.has("--capacity"):
		get_tree().root.add_child.call_deferred(load("res://tools/frontier_vps/entry.gd").new());return
	var arena=load("res://tools/voxel_battle/class_arena.tscn").instantiate()
	get_tree().root.add_child.call_deferred(arena)
	if not args.has("--connect") and not args.has("--server") and not args.has("--practice"):
		connect_default.call_deferred(arena)
func connect_default(arena)->void:
	arena.start_join(preload("res://deathmatch/profile.gd").load_name(),ProjectSettings.get_setting("cq/default_server","87.106.27.237"),int(ProjectSettings.get_setting("cq/default_port",7777)))
