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
	other.transform=Transform3D(Basis.IDENTITY,at)
	(rig.right_aim if rig.left_handed else rig.left_aim).transform=other.transform
	(left if rig.left_handed else right).set_input("grip",1.0 if eject else 0.0)
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
	label.text=title;camera.make_current()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/reload/"+name+".png")
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.set_process(false);game.set_physics_process(false)
	rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(rig);game.xr_rig=rig;rig.setup(game,true)
	rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.blackout.hide()
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
	await capture("01-pouch","USP · Eject magazine to reveal the offhand pouch")
	step(bag);step(bag,true)
	check(ui.carried.visible and not ui.bag_ammo.visible and ui.hint.text=="INSERT MAGAZINE","Offhand grip takes a visible magazine from the pouch")
	check(ui.carried.global_position.is_equal_approx(rig.left.global_position),"Carried magazine follows the offhand grip position")
	step(bag+Vector3.UP*.20,true)
	await capture("02-draw","USP · Hold offhand grip and bring the magazine to the grip")
	step(point(Reload.MAG_POINTS[2]),true);step(point(Reload.MAG_POINTS[2]))
	check(not ui.carried.visible and not ui.bag.visible and ui.hint.text=="GRAB + PULL TO RACK","Seating the magazine changes the contextual hint to racking")
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
	step(bag);step(bag,true);check(ui.carried.global_position.is_equal_approx(rig.right.global_position),"Left-handed reload uses the physical right controller")
	rig.left_handed=false;equip(3)
	var primary: Transform3D=rig.right.transform;var support:=Transform3D(Basis.IDENTITY,point(Reload.RACK_POINTS[3]))
	check(not ui.claims_hand(primary,support,true),"Loaded M3 fore-end remains available for two-hand aiming")
	cs.physical(1).ready=false;check(ui.claims_hand(primary,support,true),"M3 needing a pump reserves the offhand for its action")
	step(support.origin);step(support.origin,true);step(point(Reload.RACK_POINTS[3]+Vector3.BACK*.105),true)
	await capture("04-pump","M3 · Pull the fore-end back, then push forward while gripping")
	equip(8);var cover: Vector3=point(Reload.cover_point(0));step(cover);step(cover,true);step(point(Reload.cover_point(1)),true);step(point(Reload.cover_point(1)))
	check(ui.hint.text=="EJECT BOX · RELOAD" and rig.gun.get_node("ChamberAction").parts.FeedCover.rotation.x<-1.3,"M249 cover visibly lifts and prompts box ejection")
	await capture("05-cover","M249 · Lift the hinged feed cover before replacing the box")
	bag=Reload.pouch(rig.sample_pose()).origin;step(bag,false,true);step(bag);step(bag,true);step(bag+Vector3.UP*.20,true)
	await capture("06-box","M249 · Seat a new box, close the cover, then charge the gun")
	ui.reset();check(ui.debris.is_empty() and not ui.bag.visible and not ui.carried.visible,"Spawn reset removes reload visuals and disposable magazines")
	XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/reload-ui.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_RELOAD_UI_RESULT ",JSON.stringify(result));game.disconnect_game();game.queue_free()
	for i in 8:await process_frame
	Models.cache.clear();quit(0 if failures.is_empty() else 1)
