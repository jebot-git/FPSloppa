extends SceneTree
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/assets/base_manifest.json"))
	var installer=preload("res://deathmatch/assets/base_install.gd")
	var result: String=installer.install(data,args[0],args[1])
	if result!="Base assets installed.":push_error(result);quit(1);return
	for row in data.files:
		if FileAccess.get_sha256(args[1].path_join(row.path))!=row.sha256:push_error(row.path);quit(1);return
	var custom:=args[1].path_join("maps/custom.txt")
	var file:=FileAccess.open(custom,FileAccess.WRITE);file.store_string("keep");file.close()
	var maplist:=args[1].path_join("maps/tf_maplist.txt")
	file=FileAccess.open(maplist,FileAccess.WRITE);file.store_string("tf_vesper\n");file.close()
	var repair:=args[1].path_join("maps/tf_vesper.bsp")
	file=FileAccess.open(repair,FileAccess.WRITE);file.store_string("broken");file.close()
	result=installer.install(data,args[0],args[1])
	var expected:=""
	for row in data.files:
		if row.path=="maps/tf_vesper.bsp":expected=row.sha256
	var passed:=result=="Base assets installed." and FileAccess.get_sha256(repair)==expected and FileAccess.get_file_as_string(custom)=="keep" and FileAccess.get_file_as_string(maplist)=="tf_vesper\n"
	print("OFFLINE_INSTALL ",JSON.stringify({"files":data.files.size(),"fresh_install":true,"repair_and_custom_preservation":passed}))
	quit(0 if passed else 1)
