extends SceneTree
var failures:Array=[]
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	g.start_host("Vote validation",0,100,60,true,"dm","doom");g.practice=false
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	g._add_player(2,"Voter");g._add_player(3,"Observer",true)
	g.votes.allowed_modes=g.match_mode.NAMES.keys()
	for mode in g.match_mode.NAMES:
		g.match_mode.kind=mode;g.armory.select("doom");g.votes.reset();g.votes.cooldown=0
		var accepted:bool=g.votes.start(1,"loadout","ut99")
		check(accepted==g.armory.selectable(mode),mode+" enforces loadout vote eligibility")
		if accepted:check(g.votes.snapshot().title=="LOADOUT: UT99 (RESTART)",mode+" ballot identifies loadout and restart")
	g.match_mode.kind="dm";g.armory.select("doom");g.votes.reset();g.votes.cooldown=0
	check(not g.votes.start(3,"loadout","quake"),"Spectators cannot propose loadout changes")
	for invalid in ["doom","unknown","quake|dm","../../bad"]:check(not g.votes.start(1,"loadout",invalid),"Unchanged or invalid loadout rejected: "+invalid)
	check(g.votes.start(1,"loadout","quake") and g.votes.ballot.needed==2,"Loadout change requires a majority of active human players")
	g._add_player(4,"Late voter")
	check(not g.votes.cast(3,true) and not g.votes.cast(4,true) and not g.votes.cast(1,true),"Spectators, late joins and repeat votes cannot alter electorate")
	g.votes.cast(2,false);check(g.votes.ballot.is_empty() and g.armory.effective()=="doom","Rejected loadout leaves match unchanged")
	g.votes.cooldown=0
	var options:Array=[{"mode":"dm","map":g.current_map},{"mode":"tf","map":"tf_ironspan"},{"mode":"ig","map":g.current_map}]
	check(g.votes.match_spec("dm|"+g.current_map+"|quake",options).rules=="quake","Combined match proposal carries selected loadout")
	check(g.votes.match_spec("tf|tf_ironspan|doom",options).is_empty() and g.votes.match_spec("ig|"+g.current_map+"|ut99",options).is_empty(),"Combined proposals cannot override fixed loadouts")
	check(g.votes.match_spec("tf|tf_ironspan",options).rules=="quake","Legacy mode/map proposals resolve the mode's required loadout")
	g.lobby.build();g.lobby.offered=[{"mode":"dm","map":options[0].map,"rules":"ut99"}];g.lobby.until=g.clock+45;g.votes.ballot.clear();g.votes.cooldown=0
	check(not g.votes.start(1,"loadout","quake"),"Lobby uses a combined next-match vote instead of changing the waiting room")
	g.lobby.cast_option(1,g.lobby.ballot_id,0)
	check(g.lobby.result().rules=="ut99" and g.lobby.snapshot().next.rules=="ut99" and g.lobby.active(),"Selected lobby loadout is visible and waits for lobby expiry")
	g.disconnect_game();g.free();await process_frame
	print("LOADOUT_VOTES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
