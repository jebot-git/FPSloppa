extends SceneTree
const Config=preload("res://deathmatch/server/config.gd")
var failures: Array=[]
func check(ok: bool, label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	var parsed=Config.parse(FileAccess.get_file_as_string("res://tools/deployment/release-server.cfg"))
	check(not parsed.has("error"),"Release configuration parses")
	if parsed.has("error"):push_error(parsed.error);quit(1);return
	var settings: Dictionary=parsed.values
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="de_varq_dust2";g.start_host("Deployment check",0,20,10,true,"de","cs16",int(settings.sv_de_prepare))
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	g.set_process(false);g.set_physics_process(false)
	g.match_mode.defusal.configure(settings)
	check(settings.gametypes.size()==Config.MODES.size(),"All game modes enabled")
	g.votes.allowed_modes=settings.gametypes.duplicate();g.votes.enabled=true
	g.lobby.excluded_modes=settings.ballot_exclude_modes.duplicate()
	var choices: Array=g.lobby.choices()
	check(not choices.is_empty() and choices.all(func(row):return row.mode not in ["tb","tf","cc"]),"Ballot excludes TB, TF and CC")
	check(["tb","tf","cc"].all(func(mode):return mode in g.votes.allowed_modes),"Excluded ballot modes remain available to normal votes")
	var de=g.match_mode.defusal;g.intermission=0;g.match_mode.reset();de.tick(0)
	var first_side: int=de.attacking
	for round_index in 6:
		check(de.phase=="prepare" and de.round_id==round_index+1,"Preparation for round "+str(round_index+1))
		check(is_equal_approx(de.phase_end-g.clock,20),"Twenty-second purchase phase")
		if round_index==3:check(de.attacking!=first_side,"Sides switch after three rounds")
		g.clock=de.phase_end;de.tick(0)
		de.finish_round(round_index%2,"DEPLOYMENT TEST")
		g.clock=de.phase_end;de.tick(0)
	check(de.phase=="finished" and de.round_id==6 and g.match_mode.scores==[3,3] and g.intermission>0,"Tied match ends after exactly six rounds")
	check(settings.sv_maxclients==16 and settings.sv_lobby==1 and settings.sv_query_port==7779,"Capacity, lobby and query configuration")
	check(settings.sv_bot_fill==0 and settings.sv_bot_worker_port==0 and settings.sv_bot_worker_limit==0,"Local and worker bots disabled")
	print("DEPLOYMENT_CHECK_RESULT ",JSON.stringify({"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
