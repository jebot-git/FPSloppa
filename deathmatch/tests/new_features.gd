extends SceneTree
var g
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var aim=preload("res://deathmatch/vr/aim_support.gd").new()
	var primary:=Transform3D(Basis.IDENTITY,Vector3(.2,1.2,0));var support:=Transform3D(Basis.IDENTITY,Vector3(.23,1.2,-.35))
	var result: Transform3D=aim.solve(primary,support,3,true,true)
	check(aim.engaged and result.origin==primary.origin and (-result.basis.z).dot((support.origin-primary.origin).normalized())>.999,"Support grip aims along hands without moving firing origin")
	check(aim.solve(primary,support,2,true,true)==primary and not aim.engaged,"Pistols retain independent one-handed aim")
	check(aim.solve(primary,support,1,true,true)!=primary,"Chainsaw accepts support grip")
	check(aim.solve(primary,support,3,false,true)==primary,"Release returns runtime controller aim")
	check(aim.solve(primary,support,3,true,false)==primary,"Tracking loss disengages support")
	var jump=preload("res://deathmatch/vr/physical_jump.gd").new()
	for i in 60:jump.sample(1.65+sin(i*.3)*.008,1.0/72,true,true)
	check(not jump.consume(),"Head bob does not trigger jump")
	for i in 8:jump.sample(1.65+i*.023,1.0/72,true,true)
	check(jump.consume() and not jump.consume(),"Physical rise emits one normal jump command")
	jump.reset();jump.sample(1.65,.014,true,true);jump.sample(2.0,.014,true,true)
	check(not jump.consume(),"Tracking teleport is not a jump")
	var bind=preload("res://deathmatch/settings/bindings.gd").new()
	var event:=InputEventKey.new();event.physical_keycode=KEY_G;event.pressed=true;bind.keys.jump=KEY_G
	check(bind.matches("jump",event) and not bind.matches("use",event),"Remapped physical key dispatch")
	check(not bind.valid_vr("bad:trigger") and bind.valid_vr("support:grip"),"VR role mappings validate")
	var cfg=preload("res://deathmatch/server/config.gd").parse('set sv_lobby "1"\nset sv_lobby_seconds "30"')
	check(not cfg.has("error") and cfg.values.sv_lobby==1,"Lobby server configuration")
	check(not preload("res://deathmatch/server/config.gd").parse('set sv_maxclients "32"').has("error"),"Dedicated server accepts experimental 32 slots")
	check(preload("res://deathmatch/server/config.gd").parse('set sv_maxclients "33"').has("error"),"Dedicated server rejects more than 32 slots")
	check(preload("res://deathmatch/server/config.gd").parse('set sv_lobby_seconds "1"').has("error"),"Lobby duration bounded")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	g.start_host("Recorder",0,100,30,true,"dm");g.map_rotation=["lqdm1","lqdm2"];g.mode_maplists={"dm":["lqdm1","lqdm2"],"ig":["lqdm2"]};g.votes.allowed_modes=["dm","ig"]
	var path: String=ProjectSettings.globalize_path("res://test-results/features.fpsdemo")
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	check(g.demos.start_record(path),"Start demo recording")
	for i in 50:g.clock+=.05;g._server_tick(.05);g._send_snapshot()
	g.lobby.enabled=true;g.lobby.begin();g.map_loading=false
	check(g.lobby.active() and g.pickups.is_empty() and g.spawn_points.size()==32,"Built-in lobby is empty and has spawn positions")
	g.players[1].invulnerable=0;g.players[1].fire=true;g.players[1].cooldown=0
	var ammo: Array=g.players[1].ammo.duplicate();g._fire(1);g._damage(1,1,1000,"test",true)
	check(g.players[1].hp==100 and g.players[1].ammo==ammo and g.projectiles.is_empty(),"Lobby blocks firing and all damage")
	g.players[1].move=Vector2(1,0);g.players[1].last_input=g.clock
	var initial: Vector3=g.fighters[1].position
	for i in 10:g.clock+=.02;g.lobby.tick(.02);await physics_frame
	check(g.fighters[1].position.distance_to(initial)>.1,"Players can move in the lobby")
	check(not g.lobby.cast(1,"ig","lqdm1"),"Lobby rejects map outside mode maplist")
	check(g.lobby.cast(1,"ig","lqdm2"),"Player can vote for valid map and mode")
	g._send_snapshot();g.clock+=.5
	check(g.lobby.cast(1,"dm","lqdm2") and g.lobby.ballots.size()==1,"Changing a vote replaces the previous vote")
	g._send_snapshot();g.lobby.until=g.clock;g.lobby.tick(.02);g._send_snapshot()
	check(g.current_map=="lqdm2" and not g.lobby.active(),"Vote winner starts a normal match")
	g.demos.stop_record()
	check(FileAccess.file_exists(path),"Demo saved outside the game package")
	check(g.demos.open_demo(path),"Recorded demo opens with map changes")
	if g.demos.playing:
		g.demos.seek(g.demos.duration);check(g.current_map=="lqdm2","Demo seeking loads the recorded map")
		g.demos.next_player();g.demos.viewpoint="chase";g.demos.tick(.016)
		check(is_instance_valid(g.demos.camera) and g.demos.camera.global_position.is_finite(),"Demo chase camera and player switching")
		g.demos.stop_playback()
	check(not preload("res://deathmatch/demos/session.gd").valid_frame({"time":INF}),"Malformed demo frame rejected")
	g.disconnect_game();g.free();await process_frame;await process_frame
	print("NEW_FEATURES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
