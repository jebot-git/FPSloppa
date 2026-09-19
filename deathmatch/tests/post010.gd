extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	for fps in [60,72,90,120,144]:
		var jump=preload("res://deathmatch/vr/physical_jump.gd").new();var dt:float=1.0/fps
		for i in fps/2:jump.sample(1.65,dt,true,true)
		for i in fps/5:jump.sample(1.65-.1*(i+1)/(fps/5.0),dt,true,true)
		for i in fps/4:jump.sample(1.55+.25*(i+1)/(fps/4.0),dt,true,true)
		check(jump.consume() and not jump.consume(),"Natural dip and jump emits once at %d Hz"%fps)
		jump.reset()
		for i in fps:jump.sample(1.65+sin(i*dt*3)*.015,dt,true,true)
		for i in fps:jump.sample(1.65-.45*(i+1)/fps,dt,true,true)
		for i in fps:jump.sample(1.2,dt,true,true)
		for i in fps:jump.sample(1.2+.45*(i+1)/fps,dt,true,true)
		check(not jump.consume(),"Crouch and stand does not jump at %d Hz"%fps)
	var skel:=Skeleton3D.new();root.add_child(skel)
	for i in 57:skel.add_bone("Bone%d"%i)
	var pose=preload("res://deathmatch/avatars/pose.gd").new()
	check(pose.reference_basis(skel,-1)==Basis.IDENTITY and pose.reference_basis(skel,57)==Basis.IDENTITY,"Missing optional chest bone does not query skeleton rest out of bounds")
	pose.free()
	skel.set_bone_pose_position(0,Vector3(1,2,3))
	var logic=preload("res://addons/vrm/vrm_spring_bone_logic.gd").new(skel,0,Transform3D.IDENTITY,Vector3.UP*.1,skel.get_bone_global_pose(0))
	check(logic.get_global_pose(skel).origin==Vector3(1,2,3),"57-bone root spring handles parent -1")
	var spring=preload("res://addons/vrm/vrm_spring_bone.gd").new();spring.joint_nodes=PackedStringArray(["Bone40","Bone41"])
	skel.set_bone_parent(41,40);skel.set_bone_pose_position(40,Vector3(3,4,5));skel.set_bone_rest(41,Transform3D(Basis.IDENTITY,Vector3.UP*.2))
	skel.force_update_all_bone_transforms()
	var runtime=preload("res://addons/vrm/vrm_spring_bone.gd").SpringBoneRuntimeState.new(spring,skel);runtime.skel=skel
	var chain=runtime.create_vertlet(0,Transform3D.IDENTITY)
	check(chain.bone_idx==40 and chain.initial_transform.origin==Vector3(3,4,5),"Spring uses live skeleton index instead of obsolete override cache or chain index")
	runtime.joint_nodes=PackedStringArray(["Missing","Bone41"]);check(runtime.create_vertlet(0,Transform3D.IDENTITY)==null,"Missing spring bone is skipped")
	skel.free()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/assets/base_manifest.json"))
	var archive: String=ProjectSettings.globalize_path("res://../Builds/FPSloppa-0.10v-Base-Assets.zip")
	var directory:="/tmp/fpsloppa-base-install-test"
	var installer=preload("res://deathmatch/assets/base_install.gd")
	check(installer.install(data,archive,directory)=="Base assets installed.","Offline base archive installs all assets")
	var all_valid:=true
	for row in data.files:all_valid=all_valid and FileAccess.get_sha256(directory.path_join(row.path))==row.sha256
	check(all_valid,"Every installed map, cache and model matches its checksum")
	var corrupt: String=directory.path_join(data.files[-1].path)
	var file:=FileAccess.open(corrupt,FileAccess.WRITE);file.store_string("broken");file.close()
	check(installer.install(data,archive,directory)=="Base assets installed." and FileAccess.get_sha256(corrupt)==data.files[-1].sha256,"Reopening repairs a damaged bundled asset")
	var bad:Dictionary=data.duplicate(true);bad.files[0].path="../escape"
	check(installer.install(bad,archive,directory)=="Invalid asset path.","Installer rejects archive traversal")
	root.size=Vector2i(1024,640)
	var list=preload("res://deathmatch/ui/drag_list.gd").new();root.add_child(list);list.size=Vector2(300,200);list.vr_mode_override=true
	for i in 40:list.add_item("Model %d"%i)
	list.select(0);var selected:Array=[];list.item_selected.connect(func(index):selected.append(index))
	await process_frame;await process_frame
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(50,130);root.push_input(press,true)
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(50,30);motion.relative=Vector2(0,-100);root.push_input(motion,true)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=Vector2(50,30);root.push_input(release,true)
	check(list.scroll_vertical>=90 and selected.is_empty(),"Model list trigger drag scrolls without selecting")
	check(list.entries[0].button_pressed,"Dragging preserves an existing selection or mute checkbox")
	check(not list.get_v_scroll_bar().visible,"VR drag list hides scrollbar")
	list.free()
	var clock=preload("res://deathmatch/audio/round_clock.gd").new()
	var ticks:=0
	for i in range(1100,0,-1):
		if clock.advance(i/100.0,true,"round1"):ticks+=1
	check(ticks==10,"Final ten seconds emit exactly ten audible ticks")
	check(not clock.advance(1.1,true,"round1") and not clock.advance(.9,true,"round1"),"Clock correction cannot repeat a played second")
	check(not clock.advance(5,false,"lobby") and clock.advance(10,true,"round2"),"Lobby/intermission stay silent and a new round rearms ticking")
	clock.free()
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	g.start_host("Regression",0,100,30,true,"koth");g._add_player(2,"Opponent")
	g.players[1].team=0;g.players[2].team=1;g.players[1].kills=7;g.players[1].dead=false;g.players[2].dead=false
	g.match_mode.kind="tf";g.players[1].tf_class="soldier";g.match_mode.fortress.cooldowns[1]=g.clock+2.5;g.match_mode.flags[1].carrier=1
	var info:Dictionary=preload("res://deathmatch/ui/player_status.gd").read(g,1)
	check(info.team_text=="RED TEAM" and info.carrier.contains("BLUE FLAG") and info.ability.contains("2.5s"),"TF HUD shows own team, carried enemy flag and authoritative cooldown")
	g.match_mode.fortress.cooldowns[1]=g.clock
	check(preload("res://deathmatch/ui/player_status.gd").read(g,1).ability=="GRENADE · READY","Ability display changes to READY when cooldown expires")
	g.match_mode.kind="ctf"
	check(not preload("res://deathmatch/ui/player_status.gd").read(g,1).carrier.is_empty(),"CTF flag carrier gets the same persistent notification")
	g.match_mode.flags[1].carrier=0
	check(preload("res://deathmatch/ui/player_status.gd").read(g,1).carrier.is_empty(),"Flag capture/drop immediately clears carrier notification")
	g.match_mode.kind="koth"
	g.match_mode.hill=Vector3(0,100,0);g.match_mode.scores=[0,0];g.match_mode.hill_credit=0;g.match_mode.hill_limit=100
	g.fighters[1].position=g.match_mode.hill;g.fighters[2].position=Vector3(30,100,0)
	g.match_mode.tick(25);check(g.match_mode.scores[0]==25 and g.match_mode.hill==Vector3(0,100,0),"Hill remains at the same site before its 30-second deadline")
	g.fighters[2].position=g.match_mode.hill;g.match_mode.tick(2);check(g.match_mode.scores[0]==25,"Contested hill pauses scoring")
	g.fighters[2].position=Vector3(30,100,0);g.match_mode.tick(1)
	check(g.match_mode.hill==Vector3(0,100,0) and g.match_mode.scores[0]==26,"Uncontested scoring resumes at the same hill")
	g._end_round();var captured:Dictionary=g.lobby.last_results.duplicate(true)
	g.players.erase(2);g.fighters[2].free();g.fighters.erase(2)
	g.lobby.enabled=true;g.map_rotation=["lqdm1"];g.lobby.begin()
	check(g.lobby.active() and g.lobby.snapshot().results==captured and captured.ranked[0].kills==7,"Lobby retains finished scoreboard after resetting players")
	var board=preload("res://deathmatch/ui/scoreboard.gd").new();root.add_child(board);board.setup();board.refresh_data(captured,true)
	check(board.rows[0].cells[3].text=="7" and board.footer.text.begins_with("LAST ROUND"),"Lobby board renders saved frags independently of menu")
	board.free();g.free()
	print("POST010_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
