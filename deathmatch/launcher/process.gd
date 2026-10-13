extends RefCounted
## Launch the same installed runtime/project; never invoke a shell.
const Paths=preload("res://deathmatch/assets/paths.gd")
const Profile=preload("res://deathmatch/profile.gd")
static func arguments(scene: String,headless: bool=false,vr: bool=false) -> PackedStringArray:
	var args:=PackedStringArray()
	if OS.has_feature("editor"):args.append_array(["--path",ProjectSettings.globalize_path("res://")])
	# Exported clients may have been started with a separately located PCK.
	var original:=OS.get_cmdline_args();var index:=original.find("--main-pack")
	if index>=0 and index+1<original.size():args.append_array(["--main-pack",original[index+1]])
	args.append_array(["--xr-mode","on" if vr else "off"])
	if headless:args.append_array(["--headless","--audio-driver","Dummy"])
	args.append_array(["--","--asset-root",Paths.root(),"--client-config",ProjectSettings.globalize_path(Profile.config_path())])
	if scene.ends_with("worker.tscn"):args.append("--launcher-worker")
	elif scene.ends_with("launcher.tscn"):args.append("--launcher")
	return args
static func launch(scene: String,extra: PackedStringArray,headless: bool=false,vr: bool=false) -> int:
	var args:=arguments(scene,headless,vr);args.append_array(extra)
	return OS.create_process(OS.get_executable_path(),args)
static func endpoint(address: String,port: int) -> Dictionary:
	address=address.strip_edges()
	if address.begins_with("[") and address.ends_with("]"):address=address.substr(1,address.length()-2)
	if address.is_empty() or address.length()>253 or port<1 or port>65535:return {"error":"Enter a hostname or IP address and a port from 1 to 65535."}
	if not address.is_valid_ip_address():
		var regex:=RegEx.new();regex.compile("^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$")
		if not regex.search(address) or address.contains(".."):return {"error":"Use a hostname or IP address; enter the port separately."}
	return {"address":address,"port":port}
