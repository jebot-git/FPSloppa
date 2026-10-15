extends Node
var qa_arena
func _qa_finished(result:Dictionary)->void:
	var args:=OS.get_cmdline_user_args();var index:=args.find("--authority-client-report")
	if index>=0 and index+1<args.size():FileAccess.open(args[index+1],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	# Exit every RPC root before resetting Godot 4.7.2's transport cache.
	# Defer until the client's test callback has returned.
	await get_tree().process_frame
	var api:MultiplayerAPI=qa_arena.multiplayer
	get_tree().root.remove_child(qa_arena);qa_arena.queue_free()
	api.multiplayer_peer=OfflineMultiplayerPeer.new()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	get_tree().quit(0 if result.failures.is_empty() else 1)
func _ready() -> void:
	if OS.get_cmdline_user_args().has("--authority-arena-client"):
		var text:=FileAccess.get_file_as_string("res://tools/voxel_battle/class_arena.tscn").replace('path="res://tools/voxel_battle/class_arena.gd"','path="res://tools/authority_core/arena_client.gd"')
		var temporary:="user://resident-client-%d.tscn"%OS.get_process_id()
		var file:=FileAccess.open(temporary,FileAccess.WRITE);file.store_string(text);file.close()
		var packed:PackedScene=load(temporary);qa_arena=packed.instantiate()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		qa_arena.test_complete.connect(_qa_finished);get_tree().root.add_child.call_deferred(qa_arena)
	elif OS.get_cmdline_user_args().has("--resident-suite"):
		var probe=load("res://tools/frontier_vps/resident_driver.gd").new();probe.name="ResidentSuite";add_child(probe)
	elif OS.get_cmdline_user_args().has("--clients"):
		add_child(load("res://tools/frontier_vps/clients.gd").new())
	elif OS.get_cmdline_user_args().has("--capacity"):
		var probe=load("res://tools/frontier_vps/capacity.gd").new();add_child(probe)
	else:
		var arena=load("res://tools/voxel_battle/class_arena.tscn").instantiate();
		if OS.get_cmdline_user_args().has("--profile-players"):arena.set_script(load("res://tools/frontier_vps/metered_arena.gd"))
		get_tree().root.add_child.call_deferred(arena)
