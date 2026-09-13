extends RefCounted
const Profile=preload("res://deathmatch/profile.gd")
const Bounds=preload("res://deathmatch/vr/preferences.gd")
const ALWAYS_ENABLED=["train_motion","surface_animation","surface_variation"]
const MUSIC_TRIM_DB := -12.0
static func defaults() -> Dictionary:
	return {"train_motion":true,"spatial_audio":"steam_audio","master":1.0,"music":.3,"effects":1.0,"voice":.8,"announcer":.8,"output":"Default","render_scale":1.0,"msaa":1 if OS.has_feature("android") else 2,"texture_filter":2,"contrast_lighting":false,"surface_animation":true,"surface_variation":true,"shadows":false,"fullscreen":false,"fov":85.0,"hud_scale":1.0,"hud_y":-.46}
static func limits(key: String) -> Array:
	return [0,2] if key=="texture_filter" else [.7,1.4] if key=="hud_scale" else [-.65,.55] if key=="hud_y" else [.5,1.25] if key=="render_scale" else [0,3] if key=="msaa" else [60,110] if key=="fov" else [0,1]
static func read_settings(path: String="") -> Dictionary:
	var cfg:=ConfigFile.new();cfg.load(Profile.config_path() if path.is_empty() else path)
	var values:=defaults()
	for key in values:
		if key in ALWAYS_ENABLED:continue # Ignore disabled values from older configurations.
		var value=cfg.get_value("presentation",key,values[key])
		if values[key] is bool: values[key]=value if value is bool else values[key]
		elif values[key] is String: values[key]=value if value is String else values[key]
		else:
			var bounds:=limits(key)
			values[key]=Bounds.bounded(value,bounds[0],bounds[1],values[key])
	if not values.spatial_audio in ["steam_audio","stereo"]:values.spatial_audio="steam_audio"
	values.msaa=int(values.msaa);values.texture_filter=int(values.texture_filter)
	return values
static func save_settings(values: Dictionary,path: String="") -> Error:
	if path.is_empty():path=Profile.config_path()
	var cfg:=ConfigFile.new();var err:=cfg.load(path)
	if err!=OK and err!=ERR_FILE_NOT_FOUND:return err
	if cfg.has_section_key("presentation","map_atmosphere"):cfg.erase_section_key("presentation","map_atmosphere")
	for key in defaults():cfg.set_value("presentation",key,true if key in ALWAYS_ENABLED else values.get(key,defaults()[key]))
	return cfg.save(path)
static func bus_volume(bus_name: String,amount: float) -> void:
	var bus:=AudioServer.get_bus_index(bus_name)
	if bus<0:return
	AudioServer.set_bus_mute(bus,amount<=0)
	# Keep music behind gameplay even at the lowest saved nonzero settings.
	# Bus trim survives track changes and both sides of a crossfade.
	var gain: float=linear_to_db(amount) if amount>0 else -80.0
	if bus_name=="ArenaMusic" and amount>0:gain+=MUSIC_TRIM_DB
	AudioServer.set_bus_volume_db(bus,gain)
static func apply(game: Node,values: Dictionary) -> void:
	if game.voice:game.voice.volume=values.voice
	if game.headless:return
	var filtering:=int(values.get("texture_filter",2))
	var contrast:=bool(values.get("contrast_lighting",false))
	if game.get_meta("texture_filter",-1)!=filtering or game.get_meta("contrast_lighting",null)!=contrast:
		load("res://deathmatch/maps/filtering.gd").new().apply(game,filtering,false,int(contrast))
		game.set_meta("texture_filter",filtering)
		game.set_meta("contrast_lighting",contrast)
	var surfaces:=game.get_node_or_null("Map/MapRuntime/SurfaceMotion")
	if surfaces:surfaces.apply(values)
	bus_volume("Master",values.master);bus_volume("ArenaEffects",values.effects);bus_volume("ArenaMusic",values.music);bus_volume("ArenaAnnouncer",values.get("announcer",.8))
	if values.output in AudioServer.get_output_device_list() and AudioServer.output_device!=values.output:AudioServer.output_device=values.output
	var viewport: Viewport=game.get_viewport()
	viewport.msaa_3d=int(values.msaa)
	game.get_node("DuskSun").shadow_enabled=values.shadows
	if game.is_vr():
		game.xr_rig.apply_hud_preferences(values)
		var xr=XRServer.find_interface("OpenXR")
		if xr and xr.is_initialized() and not is_equal_approx(xr.render_target_size_multiplier,values.render_scale):xr.render_target_size_multiplier=values.render_scale
		viewport.scaling_3d_scale=1.0
	else:
		viewport.scaling_3d_scale=values.render_scale
		if is_instance_valid(game.camera):game.camera.fov=values.fov
		if not OS.has_feature("android"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
