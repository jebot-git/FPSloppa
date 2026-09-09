extends RefCounted
## Local callsign preferences, shared by desktop, VR and command-line launches.
const DEFAULT_PATH := "user://deathmatch.cfg"

static func clean(value: String, fallback: String = "Marine") -> String:
	var output := ""
	for character in value.strip_edges().left(64):
		if character.unicode_at(0)>=32 and character.unicode_at(0)!=127 and character not in ["[","]"]:
			output += character
	output = output.strip_edges().left(18)
	return fallback if output.is_empty() else output

static func config_path() -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--client-config")
	return args[index+1] if index>=0 and index+1<args.size() else DEFAULT_PATH

static func system_name() -> String:
	for key in ["USERNAME","USER","LOGNAME"]:
		var candidate := clean(OS.get_environment(key), "")
		if not candidate.is_empty(): return candidate
	return "Marine"

static func load_name(path: String = "") -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--name")
	if index>=0 and index+1<args.size(): return clean(args[index+1],system_name())
	var config := ConfigFile.new()
	if config.load(config_path() if path.is_empty() else path)==OK:
		return clean(str(config.get_value("player","name","")),system_name())
	return system_name()

static func save(value: String, address: String, path: String = "") -> Error:
	if path.is_empty(): path=config_path()
	var config := ConfigFile.new()
	var error := config.load(path)
	if error!=OK and error!=ERR_FILE_NOT_FOUND: return error
	config.set_value("player","name",clean(value,system_name()))
	config.set_value("network","address",address)
	return config.save(path)
