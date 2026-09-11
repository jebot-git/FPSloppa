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
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-demo-test.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}]
	var demo=game.demos
	check(demo.open_demo(args[0]),"Recorded AS demo opens through the production parser")
	if not demo.playing:print(demo.message);game.free();quit(1);return
	var cues: Array=[];var stages: Dictionary={};var projectiles:=false;var stable:=true;var deaths:=0;var effects:=0
	for offset in demo.offsets:
		demo.input.seek(offset);var frame: Dictionary=demo.read_frame()
		stable=stable and frame.roster.size()==8
		for event in frame.events:
			if event[0]=="_announcer_cue":cues.append(event[1][0])
			if event[0]=="_ability_fx":effects+=1
		game.clock=frame.time;demo.position_seconds=frame.time;demo.apply_frame(frame,true)
		var rules=game.match_mode.assault;stages[str(rules.leg)+":"+str(rules.stage)]=true
		projectiles=projectiles or not game.projectiles.is_empty()
		for state in game.players.values():deaths=maxi(deaths,state.deaths)
		demo.update_camera(0)
		await physics_frame
	check(stable and game.players.size()==8,"Every recorded frame retains all eight players")
	check(projectiles and deaths>0,"Playback restores projectiles, damage and deaths")
	check(stages.has("0:1") and stages.has("1:0") and stages.has("1:1") and stages.has("1:2"),"Playback restores objectives and automatic role swap")
	check(game.match_mode.assault.finished and game.match_mode.scores==[0,1],"Replay finishes with the recorded BLUE victory")
	check(cues.count("objective_completed")==4,"All four completed AS objectives record their voice event exactly once")
	check(cues.all(func(cue):return cue in game.announcer.CLIPS),"Recorded announcer events contain no retired voices")
	check(effects>0,"Shared turret/explosion effects survive recording and replay")
	for time in [0.0,demo.duration*.5,demo.duration]:
		demo.seek(time)
		for id in game.players:
			for view in ["first","chase"]:
				demo.selected_player=id;demo.viewpoint=view;demo.update_camera(0)
				if not demo.camera.global_position.is_finite():failures.append("Invalid replay camera")
	check(failures.is_empty(),"Seeking and first/chase cameras work for every network player")
	demo.paused=true;var before: float=game.clock;game._physics_process(.1)
	check(game.clock>before,"Replay advances the local effects/audio clock")
	# Old recordings may contain removed cue names; they remain readable and silent.
	demo.input.seek(demo.offsets[0]);var legacy: Dictionary=demo.read_frame();legacy.events=[["_announcer_cue",["start",0]]]
	check(demo.valid_frame(legacy) and not game.announcer.accepts("start"),"Legacy start events remain readable without restoring removed voices")
	var result={"failures":failures,"frames":demo.offsets.size(),"duration":demo.duration,"objective_voices":cues.count("objective_completed"),"announcer_events":cues,"ability_effects":effects,"stages":stages.keys(),"map_sha256":hash}
	FileAccess.open("res://test-results/as-eight-replay.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("AS_DEMO_RESULT ",JSON.stringify(result));demo.stop_playback();game.free();quit(0 if failures.is_empty() else 1)
