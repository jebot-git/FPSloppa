extends SceneTree
## Packaging helper runs in the editor/runtime tool, never in the shipped server.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var pack:=PCKPacker.new();var error:=pack.pck_start(manifest.output)
	for row in manifest.files:
		if error!=OK:break
		error=pack.add_file(row.path,row.source)
	if error==OK:error=pack.flush()
	print("SERVER_PACKAGE ",error_string(error));quit(0 if error==OK else 1)
