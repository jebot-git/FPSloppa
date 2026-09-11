extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args();var path: String=args[1]
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	var hash:=FileAccess.get_sha256(path);var key:=path.get_file().get_basename()
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-tf-replay.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}]
	var demo=game.demos;check(demo.open_demo(args[0]),"Recorded Turtler TF match opens through the production parser")
	if not demo.playing:print(demo.message);game.free();quit(1);return
	var classes: Dictionary={};var fx: Dictionary={};var charges: Dictionary={};var buffs: Dictionary={};var cooldowns: Dictionary={};var objective:=0;var stable:=true;var buildings: Dictionary={};var spy_hash:=false
	for offset in demo.offsets:
		demo.input.seek(offset);var frame: Dictionary=demo.read_frame();stable=stable and frame.roster.size()==8
		var state: Dictionary=frame.snapshot[10].fortress
		for player in state.get("players",{}).values():
			classes[player["class"]]=true
			if player.cooldown>0:cooldowns[player["class"]]=true
			spy_hash=spy_hash or not player.disguise.get("hash","").is_empty()
		for row in state.get("charges",{}).values():charges[row.kind]=true
		for row in state.get("buildings",{}).values():buildings[row.kind]=true
		for row in state.get("effects",{}).values():buffs[row.kind]=true
		for event in frame.events:
			if event[0]=="_ability_fx":fx[event[1][0]]=int(fx.get(event[1][0],0))+1
			if event[0]=="_announcer_cue" and event[1][0]=="objective_completed":objective+=1
		game.clock=frame.time;demo.position_seconds=frame.time;demo.apply_frame(frame,true);demo.update_camera(0);await physics_frame
	check(stable and game.players.size()==8,"All replay frames retain the eight-player roster")
	check(classes.size()==9,"Replay includes all nine classes through the Spy class change")
	check(cooldowns.size()==9,"Every class records its ability cooldown")
	for name in ["grenade","pipe","napalm"]:check(charges.has(name),"Replay restores moving "+name+" projectile")
	for name in ["scout","sniper","heavy","spy"]:check(buffs.has(name),"Replay restores "+name+" ability state")
	for name in ["heal","repair","build","sentry_fire","explosion","napalm","flame","spy","scout","sniper","heavy"]:check(fx.has(name),"Replay plays "+name+" visual effect")
	check(buildings.has("sentry") and buildings.has("dispenser"),"Replay restores both engineer structures")
	check(spy_hash,"Replay retains copied VRM identity for Spy disguise")
	check(game.match_mode.scores==[1,0] and game.intermission>0 and objective==1,"Replay ends in RED capture victory with one objective voice")
	for at in [0.0,demo.duration*.5,demo.duration]:
		demo.seek(at)
		for id in game.players:
			for view in ["first","chase"]:
				demo.selected_player=id;demo.viewpoint=view;demo.update_camera(0)
				if not demo.camera.global_position.is_finite():failures.append("Invalid viewpoint")
	check(failures.is_empty(),"Seek and first/chase viewpoints work for all eight players")
	var result={"failures":failures,"duration":demo.duration,"frames":demo.offsets.size(),"classes":classes.keys(),"cooldowns":cooldowns.keys(),"projectiles":charges.keys(),"effects":fx,"buffs":buffs.keys(),"objective_calls":objective,"map_sha256":hash}
	FileAccess.open(args[0].get_basename()+"-replay.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TF_REPLAY_RESULT ",JSON.stringify(result));demo.stop_playback();game.free();quit(0 if failures.is_empty() else 1)
