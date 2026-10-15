extends SceneTree
var arena
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=120
 var scene_text:=FileAccess.get_file_as_string("res://tools/voxel_battle/class_arena.tscn").replace('path="res://tools/voxel_battle/class_arena.gd"','path="res://tools/authority_core/arena_client.gd"')
 var temporary:="user://resident-client-%d.tscn"%OS.get_process_id();var file:=FileAccess.open(temporary,FileAccess.WRITE);file.store_string(scene_text);file.close()
 var packed:PackedScene=load(temporary);arena=packed.instantiate();DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary));arena.test_complete.connect(finished);root.add_child(arena)
func finished(result:Dictionary)->void:
 var args:=OS.get_cmdline_user_args();var index:=args.find("--authority-client-report")
 if index>=0 and index+1<args.size():var f:=FileAccess.open(args[index+1],FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"))
 arena.disconnect_game("Native QA complete");arena.queue_free();await process_frame;await create_timer(.3).timeout
 quit(0 if result.failures.is_empty() else 1)
