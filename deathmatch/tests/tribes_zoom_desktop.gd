extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames():
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
func mouse(pressed: bool):
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=pressed
	Input.parse_input_event(event)
func run():
	root.size=Vector2i(1280,800);Engine.max_fps=90
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_stonehenge"
	g.start_host("Image enhancer",0,100,30,true,"st","tribes");g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	g.menu_open=false;g.hud.show_menu(false)
	var actor=g.fighters[1];actor.set_physics_process(false)
	actor.position=g.spawn_points[0]+Vector3(0,4,0);actor.reset_physics_interpolation()
	g.local_yaw=g.spawn_yaws[0];g.local_pitch=-.10
	DisplayServer.window_move_to_foreground()
	await create_timer(.5).timeout
	await frames()
	var base: float=g.camera.fov
	check(g.viewmodel.visible and g.hud.cross.visible,"Normal game view shows weapon and standard crosshair")
	root.get_texture().get_image().save_png("res://test-results/tribes-image-enhancer/stonehenge-normal.png")
	mouse(true);await frames()
	check(g.match_mode.tribes.enhancer.active,"Actual alternate-fire input enters zoom")
	check(g.camera.fov<base and not g.viewmodel.visible and g.hud.tribes_zoom.visible and not g.hud.cross.visible,"Game camera, weapon and HUD switch together")
	root.get_texture().get_image().save_png("res://test-results/tribes-image-enhancer/stonehenge-2x.png")
	var green: Color=root.get_texture().get_image().get_pixel(1000,400)
	check(green.g>green.r*1.8 and green.g>.4,"Thin green crosshair remains visible with game antialiasing")
	var key:=InputEventKey.new();key.physical_keycode=KEY_X;key.pressed=true
	Input.parse_input_event(key);await frames()
	check(g.match_mode.tribes.enhancer.magnification()==5,"Actual X input cycles range")
	root.get_texture().get_image().save_png("res://test-results/tribes-image-enhancer/stonehenge-5x.png")
	var yaw: float=g.local_yaw;var motion:=InputEventMouseMotion.new();motion.relative=Vector2(10,0)
	g._unhandled_input(motion)
	check(is_equal_approx(absf(g.local_yaw-yaw),10*.0022/5),"Zoom scales desktop aiming sensitivity")
	g.menu_open=true;g.hud.show_menu(true);await frames()
	check(not g.match_mode.tribes.enhancer.active and is_equal_approx(g.camera.fov,base) and not g.hud.tribes_zoom.visible,"Menu restores FOV and removes scope overlay")
	g.menu_open=false;g.hud.show_menu(false);await frames()
	check(not g.match_mode.tribes.enhancer.active,"Closing menu does not reactivate held zoom")
	mouse(false);await frames();mouse(true);await frames()
	check(g.match_mode.tribes.enhancer.magnification()==5,"Range retained after trigger release")
	mouse(false);await frames()
	check(is_equal_approx(g.camera.fov,base) and g.viewmodel.visible and g.hud.cross.visible,"Release restores full game view")
	var report:={"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/tribes-image-enhancer/desktop.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIBES_ZOOM_DESKTOP ",JSON.stringify(report))
	g.disconnect_game();g.queue_free();key=null;motion=null
	await process_frame;await process_frame;quit.call_deferred(0 if failures.is_empty() else 1)
