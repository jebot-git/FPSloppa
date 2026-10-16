extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 Engine.max_fps=120
 var text:=FileAccess.get_file_as_string("res://tools/voxel_battle/class_arena.tscn").replace('path="res://tools/voxel_battle/class_arena.gd"','path="res://tools/authority_core/services_client.gd"')
 var path:="user://services-client-%d.tscn"%OS.get_process_id();var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
 var packed:PackedScene=load(path);var arena=packed.instantiate();DirAccess.remove_absolute(ProjectSettings.globalize_path(path));arena.test_complete.connect(func(result):
  var args:=OS.get_cmdline_user_args();var at:=args.find("--authority-client-report")
  if at>=0:FileAccess.open(args[at+1],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
  arena.disconnect_game("Native services QA complete");arena.queue_free();quit(0 if result.failures.is_empty() else 1))
 root.add_child(arena)
