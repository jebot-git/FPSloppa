extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	DirAccess.make_dir_recursive_absolute("res://test-results/st-command")
	root.size=Vector2i(1280,900);root.position=Vector2i(6000,6000)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance";g.start_host("PDA VR",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	var r=g.match_mode.tribes;r.set_process(false);var rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.focused=true;rig.blackout.hide()
	var left:=XRControllerTracker.new();left.name="left_hand";XRServer.add_tracker(left)
	var right:=XRControllerTracker.new();right.name="right_hand";XRServer.add_tracker(right)
	rig.head.position=Vector3(0,1.65,0);rig.left.position=Vector3(-.3,1.1,-.4);rig.right.position=Vector3(.3,1.1,-.4)
	var s: Dictionary=g.players[1];s.team=0;s.dead=false;s.spectator=false;s.input_blocked=false
	var actor=g.fighters[1];var pads=r.stations();actor.position=pads.rows[0].position+Vector3(15,0,0);rig.position=actor.position
	g._add_player(-21,"Friendly runner");g.players[-21].team=0;g.players[-21].dead=false
	g._add_player(-22,"Hidden enemy");g.players[-22].team=1;g.players[-22].dead=false
	g.fighters[-21].position=actor.position+Vector3(10,0,-10);g.fighters[-22].position=actor.position+Vector3(20,0,-10)
	await process_frame;await physics_frame
	check(rig.weapon_wheel.inventory().any(func(row):return row.id==7000),"Portable PDA entry is available in carried weapon wheel")
	r.open_pda();var view=r.command_view
	check(view.opened and not rig.weapon_wheel.input.opened,"PDA replaces wheel instead of layering input")
	for i in 64:view.update(.02)
	view.refresh();await process_frame;await RenderingServer.frame_post_draw
	check(view.surface.visible and not view.layer.visible and view.terrain.size()>100,"VR PDA renders bounded real-map terrain on hand panel")
	check(view.objects().any(func(row):return row.tag=="p-21") and not view.objects().any(func(row):return row.tag=="p-22"),"PDA includes allies and excludes unseen enemies")
	r.deployables.contacts[0]=[-22];check(view.objects().any(func(row):return row.tag=="p-22"),"Sensor contact appears on tactical map");r.deployables.contacts[0]=[]
	var packet: Dictionary=rig.command(1);check(packet.input_blocked and not packet.fire,"PDA blocks ordinary firing and locomotion")
	view.viewport.get_texture().get_image().save_png("res://test-results/st-command/pda-vr.png")
	var center_hit: Transform3D=view.surface.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,.5))
	check(view.ray_point(view.surface.global_transform,center_hit).distance_to(view.SIZE*.5)<.01,"VR pointing ray maps exactly to panel centre")
	check(not view.ray_point(view.surface.global_transform,view.surface.global_transform*Transform3D(Basis.IDENTITY,Vector3(2,0,.5))).is_finite(),"Off-panel ray cannot click controls")
	var saved: Transform3D=rig.head.global_transform
	for mirrored in [false,true]:
		rig.left_handed=mirrored;rig.left_controls=mirrored
		var trigger=left if mirrored else right;var other=right if mirrored else left;var aim=rig.left_aim if mirrored else rig.right_aim
		trigger.set_input("trigger",false);view.update(.02)
		var button: Dictionary=view.buttons.filter(func(row):return row.action=="sensors")[0];var pixel: Vector2=button.rect.get_center()
		var local:=Vector3((pixel.x/view.SIZE.x-.5)*view.PANEL_SIZE.x,(.5-pixel.y/view.SIZE.y)*view.PANEL_SIZE.y,.5)
		aim.global_transform=view.surface.global_transform*Transform3D(Basis.IDENTITY,local)
		var previous: bool=view.sensors;trigger.set_input("trigger",true);view.update(.02)
		check(view.sensors!=previous,"Tracked trigger activates PDA button (%s)"%mirrored)
		view.update(.02);check(view.sensors!=previous,"Held trigger does not repeatedly toggle PDA (%s)"%mirrored)
		trigger.set_input("trigger",false)
		other.set_input("ax_button",true);rig.poll_controls();check(not view.opened,"Use closes PDA (%s)"%mirrored)
		other.set_input("ax_button",false);rig.poll_controls();r.open_pda();view.update(.02)
	check(rig.head.global_transform==saved,"PDA never moves headset camera")
	view.close();rig.left_handed=false;rig.left_controls=false
	# Desktop shares the exact map, click targets and state.
	rig.enabled=false;r.open_pda();view.update(.02);view.refresh();await process_frame;await RenderingServer.frame_post_draw
	check(view.layer.visible and not view.surface.visible,"Desktop PDA uses flat panel")
	var screen=view.layer.get_node("Screen");var pixel: Vector2=screen.position+view.SIZE*.5*screen.scale
	check(view.screen_point(pixel).distance_to(view.SIZE*.5)<.01,"Desktop scaled panel maps pointer correctly")
	view.viewport.get_texture().get_image().save_png("res://test-results/st-command/pda-desktop.png")
	view.selected=[-21];view.action("move");var point: Vector3=g.fighters[-21].position;var target: Vector2=view.project(point)
	view.click(target)
	check(r.commander.orders.has(-21) and r.commander.orders[-21].status=="accepted","PDA map issues accepted bot waypoint through authority")
	view.close();rig.enabled=true
	# Camera and turret manual control use controller aim in either hand.
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(100,1,100));actor.position=Fixture.ORIGIN+Vector3(0,0,10);rig.position=actor.position
	for key in [1,2]:
		var kind: String="camera" if key==1 else "turret";r.deployables.rows[key]={"kind":kind,"team":0,"owner":1,"position":Fixture.ORIGIN+Vector3(key*3,0,0),"normal":Vector3.UP,"yaw":0.0,"hp":r.deployables.Data.hp(kind),"energy":float(r.deployables.Data.KINDS[kind].reserve),"ready":0.0,"aim":Vector3.FORWARD}
	r.deployables.sync();await physics_frame
	for mirrored in [false,true]:
		rig.left_handed=mirrored;rig.left_controls=mirrored
		var aim=rig.left_aim if mirrored else rig.right_aim;var trigger=left if mirrored else right;var other=right if mirrored else left
		for key in [1,2]:
			s.input_blocked=false;r.control_remote(key);r._process(0)
			aim.global_basis=Basis(Vector3.UP,.35)*Basis(Vector3.RIGHT,.1);trigger.set_input("trigger",true);g.clock+=.1;r.turret_view.update()
			check(r.remote.operated(1)==key and r.remote.claims[key].aim.is_equal_approx(-aim.global_basis.z),"Remote %d uses dominant aim (%s)"%[key,mirrored])
			var personal: Dictionary=g._local_command();g.sequence+=1;g._physics_process(0)
			check(not s.fire and s.move==Vector2.ZERO,"Remote control suppresses personal weapon/movement (%s)"%mirrored)
			other.set_input("ax_button",true);rig.poll_controls();r.turret_view.update();check(r.remote.operated(1)<0 and r.turret_view.key<0,"Use releases remote device (%s)"%mirrored)
			other.set_input("ax_button",false);trigger.set_input("trigger",false);rig.poll_controls()
	var c=r.vehicles
	c.rows[1]={"kind":"scout","position":Fixture.ORIGIN+Vector3.UP*10,"velocity":Vector3.ZERO,"yaw":0.0,"pitch":-.12,"bank":0.0,"hp":c.Data.HP,"pilot":1,"life":s.serial,"passengers":[],"passenger_lives":[],"team":0,"owner_team":0,"ready":0.0,"next_fire":0.0,"idle_until":1000.0}
	c.make_body(1);c.pin(1)
	for mirrored in [false,true]:
		rig.left_handed=mirrored;rig.left_controls=mirrored
		var turn=left if mirrored else right;var move=right if mirrored else left;var aim=rig.left_aim if mirrored else rig.right_aim
		aim.basis=Basis(Vector3.UP,.35)*Basis(Vector3.RIGHT,.25);move.set_input("primary",Vector2(.3,.7));turn.set_input("primary",Vector2(0,1));turn.set_input("trigger",true)
		var command: Dictionary=g._local_command()
		check(command.fly==1 and command.pitch==0 and not command.jetpack and command.move.length()>.7,"Scout independent stick lift preserves thrust/strafe (%s)"%mirrored)
		check(not command.xr.is_empty() and command.xr.weapon.basis.is_equal_approx((rig.origin.transform*aim.transform).basis),"Scout packet uses raw dominant aim rather than hidden personal weapon support (%s)"%mirrored)
	c.reset()
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	g.disconnect_game();g.free();print("ST_COMMAND_VR ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
