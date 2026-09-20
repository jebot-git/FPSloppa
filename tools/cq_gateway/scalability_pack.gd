extends SceneTree
## Repackage the exact baseline PCK, not possibly edited workspace sources.
func _initialize():
	var args:=OS.get_cmdline_user_args()
	var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not ProjectSettings.load_resource_pack(settings.base_pack,true):quit(2);return
	var project:=FileAccess.get_file_as_string("res://project.godot").replace('run/main_scene="res://deathmatch/arena.tscn"','run/main_scene="res://tools/cq_gateway/scalability.tscn"')
	var file:=FileAccess.open(settings.project,FileAccess.WRITE);file.store_string(project);file.close()
	var pack:=PCKPacker.new();var error:=pack.pck_start(settings.output)
	for path in settings.resources:
		if error!=OK:break
		error=pack.add_file("res://"+path,settings.project if path=="project.godot" else "res://"+path)
	for row in settings.extra:
		if error==OK:error=pack.add_file(row.path,row.source)
	if error==OK:error=pack.flush()
	print("SCALE_PACKAGE ",error_string(error));quit(0 if error==OK else 1)
