extends RefCounted
const Profile=preload("res://deathmatch/profile.gd")
const DEFAULTS={"smooth_turn":true,"turn_speed":120.0,"snap_angle":30.0}
static func bounded(value: Variant,minimum: float,maximum: float,fallback: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value),minimum,maximum)
static func read_settings(path: String="") -> Dictionary:
	var cfg:=ConfigFile.new();cfg.load(Profile.config_path() if path.is_empty() else path)
	var mode=cfg.get_value("vr","smooth_turn",true)
	return {"smooth_turn":mode if mode is bool else true,"turn_speed":bounded(cfg.get_value("vr","turn_speed",120),30,360,120),"snap_angle":bounded(cfg.get_value("vr","snap_angle",30),15,90,30)}
static func save_settings(values: Dictionary,path: String="") -> Error:
	if path.is_empty():path=Profile.config_path()
	var cfg:=ConfigFile.new();var err:=cfg.load(path)
	if err!=OK and err!=ERR_FILE_NOT_FOUND:return err
	for key in DEFAULTS:cfg.set_value("vr",key,values[key])
	return cfg.save(path)
