extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Reload=preload("res://deathmatch/counterstrike/reload_state.gd")
const Models=preload("res://deathmatch/counterstrike/models.gd")
const Art=preload("res://deathmatch/art.gd")
var game
var rig
var cs
var left: XRControllerTracker
var right: XRControllerTracker
var sequence:=0
var failures: Array=[]
var checks:=0
var camera: Camera3D
var label: Label
func _initialize():run.call_deferred()
func check(ok: bool,text: String):
	checks+=1;print("PASS " if ok else "FAIL ",text)
	if not ok:failures.append(text)
func point(at: Vector3) -> Vector3:return Reload.model_pose(rig.sample_pose(),game.players[1].weapon)*at
func step(at: Vector3,grip: bool=false,eject: bool=false,dt: float=.12):
	var other=rig.right if rig.left_handed else rig.left
	var carried_mag: bool=game.armory.effective()=="cs16" and cs.physical(1).carry in [1,Reload.REMOVED_MAG]
	other.transform=Transform3D(Models.ammo_basis(game.players[1].weapon).inverse() if carried_mag else Basis.IDENTITY,at)
	(rig.right_aim if rig.left_handed else rig.left_aim).transform=other.transform
	(left if rig.left_handed else right).set_input("ax_button",eject)
	(right if rig.left_handed else left).set_input("grip",1.0 if grip else 0.0)
	game.clock+=dt;sequence+=1;game.players[1].cooldown=0
	game._accept_input(1,rig.command(sequence));cs.tick_input(1,dt)
	rig.gun.global_transform=Art.held_transform(rig.origin.global_transform*rig.weapon_pose(),game.players[1].weapon,Art.VR_SCALE,"cs16")
	Models.presentation(rig.gun,false,cs.row(1));rig.physical_reload.update(dt,true)
func equip(w: int):
	game.players[1].serial+=1;game.players[1].weapon=w;game.desired_weapon=w
	if is_instance_valid(rig.gun):rig.gun.free()
	rig.gun=Models.make(w);rig.add_child(rig.gun);rig.physical_reload.reset()
	step(Reload.pouch(rig.sample_pose()).origin)
func capture(name: String,title: String):
	if not camera:return
	if name.begins_with("09-"):
		var center: Vector3=rig.gun.to_global(Vector3(0,-.1,-.35))
		camera.position=center+Vector3(1.15,.55,1.1);camera.look_at(center);camera.size=.9
	label.text=title;camera.make_current()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/reload/"+name+".png")
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.set_process(false);game.set_physics_process(false)
	rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(rig);game.xr_rig=rig;rig.setup(game,true)
	rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.blackout.hide()
	rig.pump_auto_transfer=false # Baseline manual-grab cases; auto transfer tested below.
	game._add_player(1,"Physical reload test");game.active=true;game.menu_open=false;game.armory.select("cs16");game.match_mode.kind="dm"
	game.players[1].merge({"owned":range(12),"ammo":[240,64,300,40],"dead":false,"spectator":false,"vr_device":true},true)
	cs=game.variant_combat.cs
	left=XRControllerTracker.new();left.name="left_hand";XRServer.add_tracker(left)
	right=XRControllerTracker.new();right.name="right_hand";XRServer.add_tracker(right)
	await process_frame
	rig.global_position=Fixture.point();rig.origin.transform=Transform3D.IDENTITY
	rig.right.transform=Transform3D(Basis.IDENTITY,Vector3(.22,1.18,-.3));rig.right_aim.transform=rig.right.transform
	rig.panel.hide();rig.keyboard.hide();rig.status_surface.hide();rig.damage_overlay.hide()
	for pointer in rig.pointers:pointer.hide()
	for actor in game.fighters.values():actor.hide()
	if "--render" in OS.get_cmdline_user_args():
		for layer in game.find_children("*","CanvasLayer",true,false):layer.hide()
		root.size=Vector2i(1200,900);root.content_scale_size=root.size
		DirAccess.make_dir_recursive_absolute("res://test-results/cs16/reload")
		camera=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.15
		var center: Vector3=rig.global_position+Vector3(-.02,1.15,-.3)
		camera.position=center+Vector3(1.15,.55,1.1);camera.look_at(center);camera.near=.01
		camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color("263441");camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;camera.environment.ambient_light_color=Color.WHITE;camera.environment.ambient_light_energy=.75
		var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-40,-40,0);light.light_energy=1.6
		label=Label.new();root.add_child(label);label.position=Vector2(24,24);label.add_theme_font_size_override("font_size",28)
	equip(2)
	var ui=rig.physical_reload;var bag: Vector3=Reload.pouch(rig.sample_pose()).origin
	check(not ui.bag.visible and not ui.carried.visible,"Loaded weapon has no contextual pouch")
	step(bag,false,true)
	check(ui.bag.visible and ui.bag_ammo.visible and not ui.carried.visible,"Ejection reveals the hip pouch and replacement magazine")
	check(not rig.gun.get_node("ChamberAction").parts.Magazine.visible and ui.debris.size()==1,"Old magazine detaches and falls from the rendered gun")
	var button_drop: Node3D=ui.debris[0].node.get_node("ReloadAmmunition")
	for i in 8:await physics_frame
	check(button_drop.global_basis.get_scale().is_equal_approx(rig.gun.global_basis.get_scale()),"Button-ejected magazine keeps the loaded gun scale after physics steps")
	await capture("01-pouch","USP · Eject magazine to reveal the offhand pouch")
	step(bag);step(bag,true)
	check(ui.carried.visible and not ui.bag_ammo.visible and not ui.hint.visible,"Offhand grip takes a visible magazine from the pouch")
	check(ui.carried.global_transform.is_equal_approx(Models.ammo_pose(rig.left.global_transform,2,true)),"Carried magazine follows the offhand grip position")
	step(bag+Vector3.UP*.20,true)
	await capture("02-draw","USP · Hold offhand grip and bring the magazine to the grip")
	step(point(Reload.MAG_POINTS[2]),true);step(point(Reload.MAG_POINTS[2]))
	check(not ui.carried.visible and not ui.bag.visible and not ui.hint.visible,"Seating the magazine changes the contextual hint to racking")
	var rack: Vector3=point(Reload.RACK_POINTS[2]);step(rack);step(rack,true)
	step(point(Reload.RACK_POINTS[2]+Vector3.BACK*.065),true)
	check(rig.weapon_pose().is_equal_approx(rig.right.transform),"Racking suppresses two-hand aim correction")
	await capture("03-rack","USP · Pull the slide with the offhand, then release")
	step(point(Reload.RACK_POINTS[2]+Vector3.BACK*.065))
	check(cs.physical(1).ready and not ui.target.visible,"Completed rack chambers and clears the action prompt")
	game.menu_open=true;var command: Dictionary=rig.command(100)
	check(command.input_blocked and not command.reload_grip and not command.reload,"Menu blocks both magazine eject and offhand manipulation")
	ui.update(.01,false);check(not ui.bag.visible and not ui.carried.visible and not ui.hint.visible,"Blocked interaction hides pouch, held ammo and hints")
	game.menu_open=false;rig.simulated=false
	command=rig.command(101);check(command.input_blocked and not command.reload_grip,"Missing controller tracking blocks physical reload input")
	rig.simulated=true;rig.left_handed=true
	rig.left.transform=Transform3D(Basis.IDENTITY,Vector3(-.22,1.18,-.3));rig.left_aim.transform=rig.left.transform
	equip(7);bag=Reload.pouch(rig.sample_pose()).origin;step(bag,false,true)
	check(ui.bag.visible and ui.bag.position.x>0,"Left-handed weapon places pouch on the right hip")
	step(bag);step(bag,true);check(ui.carried.global_transform.is_equal_approx(Models.ammo_pose(rig.right.global_transform,7,false)),"Left-handed reload uses the physical right controller")
	rig.left_handed=false;right.set_input("grip",0.0);equip(3)
	var primary: Transform3D=rig.right.transform;var support:=Transform3D(Basis.IDENTITY,point(Reload.RACK_POINTS[3]))
	check(not ui.claims_hand(primary,support,true),"Loaded M3 fore-end remains available for two-hand aiming")
	cs.physical(1).ready=false;check(ui.claims_hand(primary,support,true),"M3 needing a pump reserves the offhand for its action")
	step(support.origin);step(support.origin,true);step(point(Reload.RACK_POINTS[3]+Vector3.BACK*.105),true)
	await capture("04-pump","M3 · Pull the fore-end back, then push forward while gripping")
	check(ui.pump_held,"Releasing weapon grip transfers the empty M3 to the offhand pump")
	var attached: Transform3D=rig.weapon_pose()
	rig.right.position+=Vector3(.3,.2,0);rig.right_aim.transform=rig.right.transform
	check(rig.weapon_pose().is_equal_approx(attached),"Offhand-held shotgun ignores weapon-hand movement")
	rig.left.position+=Vector3(0,.12,.10);rig.left_aim.transform=rig.left.transform
	var followed: Transform3D=rig.weapon_pose()
	check(followed.origin.distance_to(attached.origin+Vector3(0,.12,.10))<.001,"Offhand-held shotgun follows the pump hand")
	right.set_input("grip",1.0);rig.weapon_pose()
	check(not ui.pump_held,"Weapon-hand grip takes the shotgun back")
	equip(8);var cover: Vector3=point(Reload.cover_point(0));step(cover);step(cover,true);step(point(Reload.cover_point(1)),true);step(point(Reload.cover_point(1)))
	check(not ui.hint.visible and rig.gun.get_node("ChamberAction").parts.FeedCover.rotation.x<-1.3,"M249 cover visibly lifts and prompts box ejection")
	await capture("05-cover","M249 · Lift the hinged feed cover before replacing the box")
	bag=Reload.pouch(rig.sample_pose()).origin;step(bag,false,true);step(bag);step(bag,true);step(bag+Vector3.UP*.20,true)
	await capture("06-box","M249 · Seat a new box, lay its belt, close the cover, then charge")
	step(point(Reload.MAG_POINTS[8]),true);step(point(Reload.MAG_POINTS[8]))
	check(not ui.hint.visible,"M249 prompts belt placement after seating the box")
	step(point(Reload.BELT_PICKUP),true);step(point(Reload.BELT_PICKUP)+Vector3.UP*.04,true)
	check(rig.gun.get_node("ChamberAction").belt.visible and not ui.carried.visible,"Held belt stays connected to the M249 box")
	await capture("07-belt","M249 · Lay the attached belt across the open feed tray")
	# Trigger is a complete alternative to support grip, with no alternate-fire leak.
	equip(2);bag=Reload.pouch(rig.sample_pose()).origin;step(bag,false,true);step(bag)
	left.set_input("trigger",1.0)
	game.clock+=.12;sequence+=1;var trigger_command: Dictionary=rig.command(sequence)
	check(trigger_command.reload_grip and not trigger_command.alt_fire,"Offhand trigger grabs reload items without toggling alternate fire")
	game._accept_input(1,trigger_command);cs.tick_input(1,.12);ui.update(.12,true)
	check(cs.physical(1).carry==1 and ui.carried.visible,"Offhand trigger draws a visible magazine")
	left.set_input("trigger",0.0);step(bag)
	equip(3);cs.state(1).clips[3]=1;bag=Reload.pouch(rig.sample_pose()).origin;step(bag);step(bag,true)
	check(cs.physical(1).carry==2 and ui.carried.visible,"Shotgun shell is visibly held after drawing from the pouch")
	check(ui.carried.global_position.distance_to(rig.left.global_position)>.065 and ui.carried.global_basis.x.length()>.95,"Full-sized shell sits beyond the curled palm instead of inside it")
	step(bag+Vector3.UP*.24,true)
	await capture("08-shell","M3 · Shell held outside the fingers")
	check(not ui.hint.visible and not ui.target.visible,"Physical reload has no floating guide text or target rings")
	var anchor:=Transform3D(Basis.IDENTITY,Fixture.point()+Vector3(0,1,-.15))
	check(rig.clear_weapon_pose(anchor,3)==anchor,"Wall clearance preserves the rendered weapon's palm anchor")
	check(game.bindings.vr.reload=="weapon:ax_button" and game.bindings.vr.jump=="move:primary_click" and game.bindings.vr.slow=="move:none","Updated defaults use A/X magazine release and movement-stick jump without slow conflict")
	step(bag);equip(6);right.set_input("grip",1.0)
	step(point(Models.support(6)),true);rig.weapon_pose()
	check(rig.support_aim.engaged,"Real rig acquires support at the authored AK handguard")
	rig._process(.016)
	game.players[1].cooldown=0;check(cs.shoot(1),"Supported AK fires an authoritative shot")
	rig.kick_weapon(6);rig._process(.016)
	var local_actor=game.fighters[1]
	check(rig.support_aim.engaged and local_actor.xr_pose.get("snapped_hands",{}).has("left"),"Shot keeps support latched and the rendered offhand attached")
	check(not rig.sample_pose().has("snapped_hands"),"Visual hand attachment never replaces raw authority tracking")
	rig.left.position+=Vector3(.15,.15,.1);rig.weapon_pose()
	check(rig.support_aim.engaged,"Natural wrist drift preserves held support in the live rig")
	left.set_input("grip",.4);rig.weapon_pose();check(rig.support_aim.engaged,"Support grip hysteresis survives moderate analog relaxation")
	left.set_input("grip",0.0);rig.weapon_pose();check(not rig.support_aim.engaged,"Releasing the controller detaches support")
	for handed in [false,true]:
		rig.global_position=Fixture.point();rig.origin.transform=Transform3D.IDENTITY
		rig.left_handed=handed;equip(3)
		var off=right if handed else left;var main=left if handed else right
		var other=rig.right if handed else rig.left
		other.position=Vector3(.35 if handed else -.35,1.2,-.2)
		off.set_input("grip",1.0);main.set_input("grip",0.0)
		rig.pump_auto_transfer=false;rig.weapon_pose()
		check(not ui.pump_held,"Disabled auto transfer leaves a loaded M3 in the weapon hand")
		rig.pump_auto_transfer=true;var held: Transform3D=rig.weapon_pose()
		check(ui.pump_held and (Art.held_transform(held,3,.65,"cs16")*Models.support(3)).distance_to(other.position)<.001,"Held offhand automatically receives the loaded M3 at its pump, left="+str(handed))
		game.clock+=.02;sequence+=1;game._accept_input(1,rig.command(sequence));cs.tick_input(1,.02)
		check(cs.physical(1).pump_hold and not game.players[1].xr.is_empty(),"Authority accepts the automatic offhand hold")
		main.set_input("grip",1.0);rig.weapon_pose();check(not ui.pump_held,"Weapon grip takes the automatically transferred shotgun back")
		off.set_input("grip",0.0)
	rig.turn_panel.pump.pressed.emit();check(not rig.pump_auto_transfer,"VR menu toggle disables automatic transfer immediately")
	check(not preload("res://deathmatch/vr/preferences.gd").read_settings().pump_auto_transfer,"Automatic transfer preference persists")
	for handed in [false,true]:
		rig.left_handed=handed;left.set_input("trigger",0.0);right.set_input("trigger",0.0)
		rig.left.transform=Transform3D(Basis.IDENTITY,Vector3(-.22,1.18,-.3));rig.left_aim.transform=rig.left.transform
		rig.right.transform=Transform3D(Basis.IDENTITY,Vector3(.22,1.18,-.3));rig.right_aim.transform=rig.right.transform
		equip(7);var at: Vector3=Reload.MAG_POINTS[7];step(point(at))
		var support_tracker: XRControllerTracker=right if handed else left
		support_tracker.set_input("trigger",1.0);step(point(at))
		check(cs.physical(1).grab=="magazine" and ui.busy() and not rig.support_aim.engaged,"Offhand trigger reserves magazine instead of handguard: "+str(handed))
		check(not rig.command(sequence+1).alt_fire,"Magazine grab cannot toggle the M4 suppressor")
		step(point(at+Vector3.DOWN*.14))
		check(cs.physical(1).carry==Reload.REMOVED_MAG and ui.carried.visible and ui.debris.is_empty(),"Pulled magazine stays visibly in the hand without a duplicate falling copy")
		check(ui.hint.visible and ui.hint.text=="29 rounds" and ui.hint.global_position.distance_to(ui.carried.global_position)<.16,"Held magazine shows a small nearby count excluding the chamber")
		check(not rig.gun.get_node("ChamberAction").parts.Magazine.visible,"Pulled magazine leaves the rendered magwell empty")
		await capture("09-pulled-magazine-"+str(handed),"M4 · Offhand trigger holds the removed magazine")
		step(point(at))
		check(cs.physical(1).mag and not ui.carried.visible and not ui.hint.visible and ui.debris.is_empty(),"Reinsertion hides held magazine/count without spawning a dropped duplicate")
		support_tracker.set_input("trigger",0.0);step(point(at));support_tracker.set_input("trigger",1.0);step(point(at));step(point(at+Vector3.DOWN*.14))
		support_tracker.set_input("trigger",0.0);step(point(at+Vector3.DOWN*.14))
		check(not ui.carried.visible and not ui.hint.visible and ui.debris.size()==1,"Releasing trigger drops the removed magazine and clears the count")
		var support_hand: XRController3D=rig.right if handed else rig.left
		var released: Node3D=ui.debris[0].node.get_node("ReloadAmmunition")
		check(released.global_transform.is_equal_approx(Models.ammo_pose(support_hand.global_transform,7,not handed)),"Released magazine starts at the held magazine pose")
		for i in 8:await physics_frame
		check(released.global_basis.get_scale().is_equal_approx(Vector3.ONE*Art.VR_SCALE),"Physics steps preserve released magazine size")
	# Every removable CS magazine uses the same visual scale in either drop path.
	for w in [1,2,5,6,7,8,9,10,11]:
		equip(w)
		for from_hand in [false,true]:
			ui.reset();ui.eject_visual(w,from_hand)
			var body: RigidBody3D=ui.debris[0].node
			var visual: Node3D=body.get_node("ReloadAmmunition")
			for i in 8:await physics_frame
			check(body.global_basis.get_scale().is_equal_approx(Vector3.ONE) and visual.global_basis.get_scale().is_equal_approx(Vector3.ONE*Art.VR_SCALE),"Dropped magazine retains VR scale: slot="+str(w)+" from_hand="+str(from_hand))
	ui.reset();check(ui.debris.is_empty() and not ui.bag.visible and not ui.carried.visible,"Spawn reset removes reload visuals and disposable magazines")
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/reload-ui.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_RELOAD_UI_RESULT ",JSON.stringify(result));game.disconnect_game();game.queue_free()
	for i in 8:await process_frame
	Models.cache.clear();quit(0 if failures.is_empty() else 1)
