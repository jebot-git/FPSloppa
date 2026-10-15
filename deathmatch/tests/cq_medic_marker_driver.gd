extends SceneTree
func _initialize():run.call_deferred()
func run():
 var source:=FileAccess.get_file_as_string("res://tools/voxel_battle/medic_test.tscn").replace("res://tools/voxel_battle/medic_test_arena.gd","res://deathmatch/tests/cq_medic_marker_client.gd")
 var path:="user://medic-marker-render-%d.tscn"%OS.get_process_id()
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(source);file.close()
 var scene:PackedScene=load(path);var game=scene.instantiate();DirAccess.remove_absolute(ProjectSettings.globalize_path(path));root.add_child(game)
 game.start_join("Medic marker QA","127.0.0.1",27781)
