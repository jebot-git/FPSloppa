extends RefCounted
const Profile=preload("res://deathmatch/profile.gd")
const Bounds=preload("res://deathmatch/vr/preferences.gd")
const Platform=preload("res://deathmatch/haptics/platform.gd")
const DEFAULTS={"enabled":false,"backend":"ble","intensity":.25,"host":"127.0.0.1","port":9001,"recoil":true,"damage":true,"environment":true,"healing":true,"pickups":false}
static func defaults() -> Dictionary:
	var result:=DEFAULTS.duplicate();result.backend=Platform.default_backend();return result
static func valid_endpoint(host: String,port: int) -> bool:
	return host.is_valid_ip_address() and host not in ["0.0.0.0","::","255.255.255.255"] and port>=1 and port<=65535
static func sanitize(values: Dictionary) -> Dictionary:
	var result:=defaults()
	for key in ["enabled","recoil","damage","environment","healing","pickups"]:
		if values.get(key) is bool:result[key]=values[key]
	var backend: Variant=values.get("backend",result.backend)
	if backend in ["osc","ble"]:result.backend=backend
	else:result.enabled=false
	result.intensity=Bounds.bounded(values.get("intensity",.25),0,1,.25)
	if values.get("host") is String:result.host=values.host.strip_edges()
	var port_value: Variant=values.get("port",9001)
	result.port=int(Bounds.bounded(port_value,0,65536,0))
	if result.backend=="osc" and not valid_endpoint(result.host,result.port):result.enabled=false
	return result
static func read_settings(path: String="") -> Dictionary:
	var cfg:=ConfigFile.new();cfg.load(Profile.config_path() if path.is_empty() else path)
	var values: Dictionary={}
	var fallback:=defaults()
	for key in DEFAULTS:values[key]=cfg.get_value("bhaptics",key,fallback[key])
	return sanitize(values)
static func save_settings(values: Dictionary,path: String="") -> Error:
	var cfg:=ConfigFile.new()
	if path.is_empty():path=Profile.config_path()
	var err:=cfg.load(path)
	if err!=OK and err!=ERR_FILE_NOT_FOUND:return err
	var safe:=sanitize(values)
	for key in DEFAULTS:cfg.set_value("bhaptics",key,safe[key])
	return cfg.save(path)
