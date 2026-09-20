extends SceneTree
const Policy=preload("res://deathmatch/rendering_policy.gd")
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty() or not ProjectSettings.load_resource_pack(args[0]):push_error("Cannot mount client pack");quit(1);return
	var file:=FileAccess.open("res://project.binary",FileAccess.READ)
	if not file or file.get_buffer(4).get_string_from_ascii()!="ECFG":push_error("Missing exported project settings");quit(1);return
	var count:=file.get_32();var values: Dictionary={}
	for i in count:
		var key:=file.get_buffer(file.get_32()).get_string_from_utf8()
		values[key]=bytes_to_var(file.get_buffer(file.get_32()))
	var error:=Policy.settings_error(values)
	if not error.is_empty():push_error(error);quit(1);return
	if not FileAccess.file_exists("res://deathmatch/rendering_policy.gd") and not FileAccess.file_exists("res://deathmatch/rendering_policy.gd.remap"):push_error("Missing runtime renderer guard");quit(1);return
	print("EXPORTED_RENDERER_POLICY ",JSON.stringify({"pack":args[0],"method":"mobile","driver":"vulkan","passed":true}));quit()
