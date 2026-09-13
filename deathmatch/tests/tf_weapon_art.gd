extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Art=preload("res://deathmatch/art.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.start_host("TF model check",0,100,60,true);game.bots.free();game.bots=null;game.set_physics_process(false);game.set_process(false)
	game.menu_open=false;game.hud.show_menu(false);game.match_mode.kind="tf"
	var s: Dictionary=game.players[1];s.weapon=7;s.dead=false;s.tf_class="pyro";s.invulnerable=0
	game.desired_weapon=7;game.fighters[1].position=Fixture.point()
	var remote=load("res://deathmatch/avatars/rig.gd").new();game.fighters[1].add_child(remote);remote.set_process(false)
	for rule in ["doom","quake","ut99"]:
		game.armory.select(rule);s.tf_class="pyro";game._process(.02)
		check(game.viewmodel.has_meta("tf_flamethrower"),rule+" desktop Pyro gets dedicated flamethrower")
		remote.set_weapon(7);check(remote.gun.has_meta("tf_flamethrower"),rule+" remote avatar gets same flamethrower")
		check(game.match_mode.fortress.weapon_data(1,7).name=="FLAMETHROWER",rule+" replacement preserves Pyro weapon mechanics")
		s.tf_class="heavy";game._process(.02);remote.set_weapon(7)
		check(not game.viewmodel.has_meta("tf_flamethrower") and not remote.gun.has_meta("tf_flamethrower"),rule+" class change restores normal slot-7 mesh")
	for rule in ["doom","quake","ut99"]:
		game.armory.select(rule);s.tf_class="sniper";s.weapon=9;game.desired_weapon=9;game._process(.02);remote.set_weapon(9)
		check(game.viewmodel.has_meta("sniper") and remote.gun.has_meta("sniper"),rule+" TF sniper uses replacement locally and remotely")
		s.tf_class="heavy";game._process(.02);remote.set_weapon(9)
		check(game.viewmodel.has_meta("sniper")== (rule=="ut99") and remote.gun.has_meta("sniper")== (rule=="ut99"),rule+" class switch restores profile-specific slot 9")
	s.weapon=7;game.desired_weapon=7
	remote.free()
	game.armory.select("quake");s.tf_class="pyro"
	game.demos.camera=Camera3D.new();game.add_child(game.demos.camera);game.demos.selected_player=1;game.demos.viewpoint="first"
	game.demos.update_camera(.02);check(game.demos.gun.has_meta("tf_flamethrower"),"Demo first-person camera shows TF replacement")
	s.tf_class="heavy";game.demos.update_camera(.02);check(not game.demos.gun.has_meta("tf_flamethrower"),"Demo class change refreshes cached gun")
	game.demos.gun.free();game.demos.gun=null;game.demos.camera.free();game.demos.camera=null
	game.xr_rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(game.xr_rig);check(game.xr_rig.setup(game,true),"Simulated XR rig starts")
	var rig=game.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;rig.focused=true
	s.tf_class="pyro";s.weapon=7;game.desired_weapon=7
	for left in [false,true]:
		rig.left_handed=left;rig._process(.02)
		check(rig.gun.has_meta("tf_flamethrower") and rig.gun_rules=="tf_flame","VR flamethrower follows gun-hand choice: "+str(left))
		var grip: Transform3D=rig.origin.global_transform*rig.weapon_pose()
		var held:=Art.held_transform(grip,7,Art.VR_SCALE,"tf_flame")
		check((held*Vector3(0,-.055,.06)).distance_to(grip.origin)<.0001,"Flamethrower palm anchor matches controller")
		s.xr=rig.sample_pose();s.vr_device=true
		var shot: Dictionary=game._shot_solution(1)
		var expected: Vector3=Art.held_transform(game._weapon_transform(1),7,Art.VR_SCALE,"tf_flame")*Art.muzzle(7,"tf_flame")
		check(not shot.blocked and shot.origin.distance_to(expected)<.001,"Authority uses the visible flamethrower muzzle")
	for left in [false,true]:
		s.tf_class="sniper";s.weapon=9;game.desired_weapon=9;rig.left_handed=left;rig._process(.02)
		check(rig.gun.has_meta("sniper") and rig.gun.has_meta("scope_rear"),"VR sniper mesh and optic follow gun hand: "+str(left))
		var grip: Transform3D=rig.origin.global_transform*rig.weapon_pose()
		check(rig.gun.to_global(Art.SNIPER_GRIP).distance_to(grip.origin)<.001,"Sniper palm anchor matches controller")
		s.xr=rig.sample_pose();s.vr_device=true
		var shot: Dictionary=game._shot_solution(1)
		var expected: Vector3=Art.held_transform(game._weapon_transform(1),9,Art.VR_SCALE,"tf_sniper")*Art.muzzle(9,"tf_sniper")
		check(not shot.blocked and shot.origin.distance_to(expected)<.001,"Authority uses replacement sniper muzzle")
	s.weapon=7;game.desired_weapon=7
	s.tf_class="heavy";rig._process(.02);check(not rig.gun.has_meta("tf_flamethrower"),"VR class change restores the normal weapon")
	game.match_mode.kind="dm";s.tf_class="pyro";check(game.match_mode.fortress.art_rules(1,7)=="quake","Pyro label outside TF cannot replace weapon")
	var axe:=Art.weapon(0,2,"quake");var edge: Vector3=axe.get_child(0).get_meta("cutting_edge")
	check(edge.distance_to(Art.muzzle(0,"quake"))<.00001 and absf(edge.x)<.001 and edge.z<-.3,"Replacement axe cutting edge matches physical sweep and faces forward")
	axe.free()
	check(checks>=24,"All model integration scenarios completed")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/weapon-variants/tf-weapon-art.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TF_WEAPON_ART_RESULT ",JSON.stringify(report));game.disconnect_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
