extends SceneTree
const Config=preload("res://deathmatch/server/config.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	check(Config.parse("").values.ballot_exclude_modes.is_empty(),"Existing configs exclude no ballot modes")
	check(Config.parse('set sv_ballot_exclude_modes ""').values.ballot_exclude_modes.is_empty(),"Explicit empty exclusion list is valid")
	var config:=Config.parse('set sv_gametypes "dm ig tf"\nset sv_ballot_exclude_modes " IG\t tf ig "')
	check(not config.has("error") and config.values.ballot_exclude_modes==["ig","tf"],"Exclusions normalize case, whitespace and duplicates")
	check(config.values.gametypes==["dm","ig","tf"],"Exclusions preserve the normal mode allowlist")
	check(not Config.parse('set sv_ballot_exclude_modes "de tb"').has("error"),"Known but currently disabled modes can be excluded")
	check(Config.parse('set sv_ballot_exclude_modes "dm unknown"').has("error"),"Unknown excluded mode is rejected")
	check(Config.parse('set sv_ballot_exclude_modes "dm,ig"').has("error"),"Malformed list is rejected with a config error")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Ballot exclusions",0,100,30,true);g.practice=false
	g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	g.votes.allowed_modes=config.values.gametypes;g.lobby.excluded_modes=config.values.ballot_exclude_modes
	g.mode_maplists={"dm":["qsrc_dm1","qsrc_dm6"],"ig":["qsrc_dm1"],"tf":["tf_ironspan"]}
	g.map_rotation=["qsrc_dm1","qsrc_dm6"];g.rotation_index=0
	check(g.lobby.choices().all(func(row):return row.mode=="dm"),"Post-game candidate pool excludes every listed mode")
	check(g.votes.match_choices().any(func(row):return row.mode=="ig") and g.votes.match_choices().any(func(row):return row.mode=="tf"),"Normal match-vote choices retain excluded but enabled modes")
	# Keep a second voter so proposing does not immediately execute a transition.
	g.players[2]=g._new_state("Second voter",2)
	for kind in ["mode","match"]:
		g.votes.cooldown=0
		check(g.votes.start(1,kind,"ig" if kind=="mode" else "ig|qsrc_dm1|doom"),"Normal "+kind+" vote accepts a post-game-excluded mode")
		g.votes.reset()
	g.players.erase(2)
	g._end_round()
	check(g.lobby.offered.size()==mini(g.lobby.OPTION_COUNT,2*g.armory.IDS.size()) and g.lobby.offered.all(func(row):return row.mode=="dm"),"Round end offers available distinct combinations only from non-excluded modes")
	check(not g.lobby.cast_value(1,"ig|qsrc_dm1|doom"),"Excluded post-game combination cannot be submitted directly")
	var offered: Array=g.lobby.offered.duplicate(true);var generation: int=g.lobby.ballot_id
	check(g.lobby.cast_option(1,generation,2),"Allowed post-game choice accepts a vote")
	g.lobby.enabled=true;g.lobby.begin()
	check(g.lobby.active() and g.lobby.offered==offered and g.lobby.ballot_id==generation and g.lobby.selections.get(1)==2,"Filtered ballot and votes survive the waiting-room transition")
	g.lobby.launch()
	check(g.match_mode.kind=="dm" and g.current_map in ["qsrc_dm1","qsrc_dm6"],"Lobby launches only an offered non-excluded mode")
	# Excluding all enabled modes is allowed: fall back to ordinary rotation,
	# with no hidden excluded card or empty lobby that traps players.
	g.lobby.excluded_modes=["dm","ig","tf"]
	for waiting_room in [false,true]:
		g.lobby.enabled=waiting_room;g.map_rotation=[g.current_map];g.rotation_index=0
		g._end_round()
		check(g.lobby.offered.is_empty() and g.lobby.snapshot().is_empty(),"All excluded means no ballot, lobby="+str(waiting_room))
		g.intermission=.001;g._server_tick(.01)
		check(not g.lobby.active() and g.intermission==0 and g.round_left>0,"Empty ballot resumes normal play, lobby="+str(waiting_room))
	g.lobby.enabled=false;g.map_rotation=[g.current_map,"qsrc_dm6" if g.current_map=="qsrc_dm1" else "qsrc_dm1"];g.rotation_index=0
	var next: String=g.map_rotation[1]
	g._end_round();g.intermission=.001;g._server_tick(.01)
	check(g.current_map==next,"Empty ballot advances the existing rotation")
	g.votes.enabled=false;g.lobby.prepare()
	check(g.lobby.offered.size()==1 and g.lobby.offered[0].mode=="dm","Disabled voting retains normal waiting-room rotation even for an excluded mode")
	g.lobby.reset_ballot();g.votes.enabled=true;g.lobby.excluded_modes.clear()
	check(g.lobby.choices().any(func(row):return row.mode=="ig") and g.lobby.choices().any(func(row):return row.mode=="tf"),"Clearing exclusions restores the full post-game pool")
	var admin=preload("res://deathmatch/server/rcon.gd").new();admin.game=g
	g.lobby.excluded_modes=["ig"]
	check(admin.execute("status").ballot_exclude_modes==["ig"] and admin.execute("status").allowed_modes==["dm","ig","tf"],"RCON reports exclusions separately from enabled modes")
	admin.free();g.disconnect_game();g.free()
	var result:={"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://test-results/ballot-exclusions")
	FileAccess.open("res://test-results/ballot-exclusions/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n")
	print("BALLOT_EXCLUSIONS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
