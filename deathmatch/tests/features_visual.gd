extends SceneTree
var game
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,900)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.hud.open_bindings()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/control-bindings.png")
	check(game.hud.bindings_panel.visible and game.hud.bindings_panel.buttons.size()==game.bindings.KEYS.size(),"Control menu renders all desktop bindings")
	game.hud.bindings_panel.hide()
	var picker=game.hud.avatar_picker
	var decoded: int=game.avatars.library.scenes.size()
	picker.open()
	for hash in game.avatars.library.entries:picker.select_model(hash)
	for i in 4:await process_frame
	check(game.avatars.library.scenes.size()==decoded and picker.preview==null,"Opening and browsing VRM menu does not decode models")
	picker.hide()
	game.start_host("Preview",0,100,30,true)
	for i in 20:await process_frame
	game.set_physics_process(false)
	var rig=game.xr_rig
	check(rig.setup(game,true),"Simulated VR controls start")
	rig.left_handed=false;rig.focused=true;rig.scores=false;rig.set_process(false);rig.head.position=Vector3(0,1.65,0);rig.calibration_pending=false;game.menu_open=false
	var left:=XRPositionalTracker.new();left.type=XRServer.TRACKER_CONTROLLER;left.name="left_hand";XRServer.add_tracker(left)
	var right:=XRPositionalTracker.new();right.type=XRServer.TRACKER_CONTROLLER;right.name="right_hand";XRServer.add_tracker(right)
	rig.left.transform=Transform3D(Basis.IDENTITY,Vector3(.23,1.2,-.35));rig.right.transform=Transform3D(Basis.IDENTITY,Vector3(.2,1.2,0));rig.right_aim.transform=rig.right.transform
	game.players[1].weapon=3;game.bindings.two_handed=true;left.set_input("grip",1.0)
	var pose: Dictionary=rig.sample_pose()
	check(not pose.is_empty() and rig.support_aim.engaged,"Tracked support grip changes the transmitted aim pose")
	left.set_input("grip",0.0);pose=rig.sample_pose();check(not rig.support_aim.engaged and pose.weapon.basis.is_equal_approx(rig.right_aim.basis),"Releasing grip returns one-hand aim")
	game.bindings.vr.jump="weapon:trigger";right.set_input("trigger",1.0)
	check(rig.command(1).jump,"VR trigger can be rebound to jump")
	game.bindings.vr.menu="support:grip";left.set_input("grip",1.0);rig.poll_controls();check(game.menu_open,"Analog grip can be rebound to menu")
	rig.poll_controls();check(game.menu_open,"Held analog binding toggles only once")
	left.set_input("grip",0.0);rig.poll_controls();left.set_input("grip",1.0);rig.poll_controls();check(not game.menu_open,"Analog binding rearms on release")
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	rig.enabled=false;rig.hide();game.lobby.build();game.active=true;game.menu_open=false
	game._spawn(1);var camera: Camera3D=game.get_node("Overview");camera.make_current();game.camera=camera;camera.position=Vector3(0,2.5,9);camera.look_at(Vector3(0,1.5,0))
	for actor in game.fighters.values():actor.position=Vector3(0,0,0)
	for i in 20:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/waiting-lobby.png")
	for actor in game.fighters.values():
		if actor.avatar and not actor.avatar_hash.is_empty():check(not actor.avatar.gun.visible,"Lobby hides remote VRM weapons")
	game.disconnect_game();game.free();await process_frame;await process_frame
	print("FEATURE_VISUAL_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
