extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	seed(917)
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	g.start_host("Ballot",0,100,30,true);g.practice=false
	g.votes.allowed_modes=["dm","ig","as","tf"]
	g.mode_maplists={"dm":["qsrc_dm1","qsrc_dm6","qsrc_dm3"],"ig":["qsrc_dm1"],"as":["as_hislop"],"tf":["tf_ironspan"]}
	g._end_round()
	check(g.intermission>0 and g.lobby.offered.size()==9,"Round end immediately creates nine match combinations")
	var seen: Dictionary={};var valid:=true
	for row in g.lobby.offered:
		seen[g.votes.match_value(row)]=true
		valid=valid and row.map in g.maps_for_mode(row.mode) and row.rules in g.armory.IDS
		var required:String=g.armory.required(row.mode)
		if not required.is_empty():valid=valid and row.rules==required
	check(seen.size()==9 and valid,"Nine unique options respect map lists and mode/loadout restrictions")
	check(not g.votes.start(1,"match",g.votes.match_value(g.lobby.offered[0])),"Old proposal requests cannot bypass the card generation guard")
	var original:Array=g.lobby.offered.duplicate(true)
	var generation:int=g.lobby.ballot_id
	check(g.lobby.cast_option(1,generation,3),"One click casts an intermission vote without a proposal")
	check(g.lobby.tally()[3]==1 and g.lobby.result()==g.lobby.spec(original[3]),"Vote immediately updates count and leading combination")
	g.lobby.cast_option(1,generation,4)
	check(g.lobby.tally()[3]==0 and g.lobby.tally()[4]==1,"Changing a vote removes the previous count")
	check(not g.lobby.cast_option(1,generation-1,0) and not g.lobby.cast_option(1,generation,9) and not g.lobby.cast_option(1,generation,-1),"Stale and out-of-range card requests are rejected")
	check(not g.lobby.cast_value(1,"dm|unknown|doom"),"Unlisted combinations cannot be submitted")
	g.players[2]=g._new_state("Second",2);g.players[3]=g._new_state("Spectator",3);g.players[3].spectator=true
	check(not g.lobby.cast_option(3,generation,0) and not g.lobby.cast_option(-1,generation,0) and not g.lobby.cast_option(987,generation,0),"Spectators, bots and unknown peers cannot vote")
	g.lobby.cast_option(2,generation,2)
	check(g.lobby.result()==g.lobby.spec(original[2]),"Ties use the shared shuffled grid order")
	g.lobby.remove_peer(2);g.players.erase(2);g.players.erase(3)
	check(g.lobby.tally()[2]==0,"Departing voters no longer affect the result")
	g.lobby.enabled=true;g.lobby.begin()
	check(g.lobby.active() and g.lobby.offered==original and g.lobby.ballot_id==generation and g.lobby.selections.get(1)==4,"Same choices and votes survive intermission-to-lobby map transition")
	g.lobby.until=g.clock
	check(not g.lobby.cast_option(1,generation,0),"Votes arriving after lobby expiry are rejected")
	# No-lobby servers use exactly the same ballot at the end of intermission.
	g.lobby.reset_ballot();g.current_map="qsrc_dm1";g.intermission=0;g.lobby.enabled=false
	g.votes.allowed_modes=["ig"];g.mode_maplists={"ig":["qsrc_dm6"]}
	g._end_round()
	check(g.lobby.offered.size()==1 and g.lobby.offered[0].rules=="doom","Small catalogs expose only valid unique combinations")
	g.intermission=.001;g._server_tick(.01)
	check(g.current_map=="qsrc_dm6" and g.match_mode.kind=="ig" and g.lobby.offered.is_empty(),"Without a lobby the leading option starts when intermission expires")
	g.votes.enabled=false;g._end_round()
	check(g.lobby.offered.is_empty(),"Disabled voting does not create an intermission ballot")
	g.votes.enabled=true;g.votes.allowed_modes=["ctf","tf","tb"];g.mode_maplists.clear()
	g.map_catalog=[{"id":"plain","title":"Plain","path":"res://maps/qsrc_dm1.bsp","sha256":"a".repeat(64),"modes":["dm","tdm","ig","ft","if"],"imported":true}]
	g.lobby.prepare()
	check(g.votes.match_choices().is_empty() and g.lobby.offered.is_empty(),"Empty objective maplists never offer an untagged arena as a fallback")
	g.disconnect_game();g.free();await process_frame
	print("MATCH_BALLOT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
