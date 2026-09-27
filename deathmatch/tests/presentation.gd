extends SceneTree
const Settings=preload("res://deathmatch/settings/preferences.gd")
class GazeRuntime extends RefCounted:
	var gaze:=true
	var ready:=true
	func is_initialized() -> bool:return ready
	func is_eye_gaze_interaction_supported() -> bool:return gaze
	func is_foveation_supported() -> bool:return false
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var path:="/tmp/entryway-presentation-test.cfg"
	var cfg:=ConfigFile.new();cfg.set_value("profile","name","Keep this");cfg.set_value("vr","turn_speed",150)
	cfg.set_value("presentation","hud_scale",99);cfg.set_value("presentation","hud_y",-99);cfg.set_value("presentation","render_scale",.01);cfg.set_value("presentation","msaa",99);cfg.set_value("presentation","master",NAN);cfg.save(path)
	var values:=Settings.read_settings(path)
	check(values.render_scale==.5 and values.msaa==3 and values.master==1,"Invalid presentation settings are bounded with safe defaults")
	check(values.hud_scale==1.4 and values.hud_y==-.65,"HUD scale and height stay within comfortable bounds")
	values.hud_scale=.8;values.hud_y=.3
	values.effects=.3;values.voice=.6;values.announcer=.4;values.render_scale=.9
	check(Settings.save_settings(values,path)==OK,"Presentation preferences save")
	cfg.load(path)
	check(cfg.get_value("profile","name")=="Keep this" and cfg.get_value("vr","turn_speed")==150,"Saving audio and graphics preserves identity and turn settings")
	check(Settings.read_settings(path).hud_scale==.8 and Settings.read_settings(path).hud_y==.3,"HUD layout survives restart")
	check(Settings.read_settings(path).effects==.3 and Settings.read_settings(path).voice==.6,"Audio preferences survive restart")
	check(Settings.read_settings(path).announcer==.4,"Announcer volume survives restart independently")
	AudioServer.add_bus();var bus:=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"SettingsTest")
	Settings.bus_volume("SettingsTest",.5)
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(.5)),"Volume uses perceptually meaningful bus gain")
	Settings.bus_volume("SettingsTest",0)
	check(AudioServer.is_bus_mute(bus),"Zero volume mutes completely")
	Settings.bus_volume("SettingsTest",1)
	check(not AudioServer.is_bus_mute(bus) and AudioServer.get_bus_volume_db(bus)==0,"Raising volume unmutes playback")
	AudioServer.remove_bus(bus)
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true);g.xr_rig.set_process(false)
	g.xr_rig.apply_hud_preferences({"hud_scale":1.2,"hud_y":.3})
	check(g.xr_rig.status_surface.scale.is_equal_approx(Vector3.ONE*1.2) and is_equal_approx(g.xr_rig.status_surface.position.y,.3),"HUD controls update the actual head-relative surface")
	g.xr_rig.apply_hud_preferences({"hud_scale":NAN,"hud_y":INF})
	check(g.xr_rig.status_surface.scale==Vector3.ONE and is_equal_approx(g.xr_rig.status_surface.position.y,-.46),"Non-finite HUD input returns to safe defaults")
	g._add_player(1,"Player");g._add_player(-4,"Observer",true);g.active=true;g.menu_open=false;g.intermission=10;g.round_message="Player wins"
	await process_frame
	g.xr_rig._process(.016);g.hud._process(.016)
	check(not g.xr_rig.panel.visible and not g.hud.scoreboard.visible,"Intermission does not force a scoreboard without holding its control")
	g.hud.score_table.refresh(g)
	check(g.hud.score_table.observers.text.contains("Observer"),"Scoreboard lists observers separately from ranked players")
	g.intermission=0;g.xr_rig._process(.016);g.hud._process(.016)
	check(not g.xr_rig.panel.visible and not g.hud.scoreboard.visible,"Scoreboard remains closed when the next round starts")
	g.menu_open=true;g.hud.show_menu(true);g.hud.settings_panel.open();g.xr_rig._process(.016)
	await process_frame
	check(g.hud.settings_panel.visible and g.xr_rig.panel.visible,"Audio/graphics settings use the VR menu surface")
	var panel=g.hud.settings_panel
	panel.config_path=path;panel.adjust("master",-.1)
	check(is_equal_approx(Settings.read_settings(path).master,panel.values.master),"Menu adjustment applies and persists")
	var music_before: float=panel.values.music
	panel.controls.music.get_parent().get_child(3).pressed.emit()
	check(is_equal_approx(panel.values.music,music_before+.01) and is_equal_approx(Settings.read_settings(path).music,panel.values.music),"Music button adjusts and persists one-percent increments")
	check(panel.get_rect().size.y<=g.hud.get_child(0).size.y+1,"Settings panel fits the VR canvas")
	check(panel.controls.announcer.get_global_rect().end.y<=640,"Announcer controls fit the VR audio page")
	check(not panel.controls.has('soundtrack'),'Audio menu only exposes the original soundtrack')
	panel.section="haptics";panel.refresh()
	for mode in [0,1]:
		panel.haptics_page.backend.select(mode);panel.haptics_page.refresh()
		await process_frame;await process_frame
		check(panel.get_rect().size.y<=640 and panel.get_global_rect().encloses(panel.haptics_page.notice.get_global_rect()),"Haptics page fits the scaled VR canvas: "+str(mode))
	panel.section="graphics";panel.refresh()
	await process_frame;await process_frame
	check(panel.get_rect().size.y<=640,"Graphics page fits the VR canvas")
	var graphics_scroll: ScrollContainer=panel.graphics_page.get_child(0)
	graphics_scroll.scroll_vertical=10000
	await process_frame;await process_frame
	check(graphics_scroll.get_global_rect().encloses(panel.controls.hud_y.get_global_rect()),"HUD controls remain reachable within the graphics drag-scroll area")
	panel.section="controls";panel.refresh();await process_frame;await process_frame
	check(panel.get_rect().size.y<=640,"Controls page fits the VR canvas")
	check(Settings.ALWAYS_ENABLED.all(func(key):return not panel.controls.has(key) and Settings.read_settings(path)[key]),"Default visual effects have no menu toggles and remain enabled")
	check(panel.controls.has("spring_bones"),"Graphics menu exposes avatar spring bones")
	check(panel.controls.has("foveation_level") and panel.foveation_status.text.contains("Without eye tracking"),"Graphics explains static foveation without a headset")
	for level in 4:
		var before: int=panel.values.foveation_level
		panel.controls.foveation_level.pressed.emit()
		check(panel.values.foveation_level==(before+1)%4 and Settings.read_settings(path).foveation_level==panel.values.foveation_level,"Foveation button cycles and saves each preset")
	var gaze_runtime:=GazeRuntime.new()
	panel.refresh_foveation(gaze_runtime)
	check(panel.controls.fovea_size.visible and not panel.controls.foveation_level.visible and panel.controls.fovea_size.text.begins_with("VR FOVEA SIZE:"),"Gaze replaces the static setting with fovea size")
	var saved_static: int=panel.values.foveation_level
	for size in 4:
		var before: int=panel.values.fovea_size
		panel.controls.fovea_size.pressed.emit();panel.refresh_foveation(gaze_runtime)
		check(panel.values.fovea_size==(before+1)%4 and Settings.read_settings(path).fovea_size==panel.values.fovea_size and panel.values.foveation_level==saved_static,"Fovea size cycles and saves without overwriting static strength")
	panel.section="graphics";panel.refresh();panel.refresh_foveation(gaze_runtime);graphics_scroll.scroll_vertical=0
	await process_frame;await process_frame
	check(panel.get_rect().size.y<=640 and graphics_scroll.get_global_rect().encloses(panel.controls.fovea_size.get_global_rect()),"Replacement fovea control fits the VR graphics canvas")
	gaze_runtime.gaze=false;panel.refresh_foveation(gaze_runtime)
	check(not panel.controls.fovea_size.visible and panel.controls.foveation_level.visible and panel.values.foveation_level==saved_static,"No-eye runtime restores static control and remembered strength")
	gaze_runtime.gaze=true;gaze_runtime.ready=false;panel.refresh_foveation(gaze_runtime)
	check(not panel.controls.fovea_size.visible and panel.controls.foveation_level.visible,"Uninitialized runtime does not expose a gaze control")
	# Exercise the presentation branch despite running this fixture headlessly.
	g.headless=false
	panel.controls.hud_scale.get_parent().get_child(3).pressed.emit()
	g.headless=true
	check(is_equal_approx(g.xr_rig.status_surface.scale.x,panel.values.hud_scale),"HUD size button applies through the menu")
	g.intermission=10;g.hud.show_menu(false);g.menu_open=false
	for id in range(2,16):
		g._add_player(id,"Observer_1234567890",true)
	g.hud._process(.016)
	await process_frame;await process_frame
	check(g.hud.scoreboard.size.x<=g.hud.get_child(0).size.x and g.hud.scoreboard.size.y<=640,"Maximum spectator roster fits the VR scoreboard")
	g.hud.show_menu(false)
	check(not panel.visible,"Closing the menu dismisses settings")
	print("PRESENTATION_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
