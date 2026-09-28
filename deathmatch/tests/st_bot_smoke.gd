extends SceneTree
var g
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST bot routes",0,100,30,true,"st")
	g.players[1].spectator=true;g.players[1].team=-1;g.fighters[1].hide()
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for id in [-1,-2,-3,-4]:g._add_player(id,"ST Bot "+str(-id))
	if not is_instance_valid(g.bots):g.bots=load("res://deathmatch/bots.gd").new();g.add_child(g.bots);g.bots.setup(g)
	var samples: Dictionary={}
	for id in [-1,-2,-3,-4]:samples[id]={"start":g.fighters[id].position,"distance":0.0,"jets":0,"ski":0,"fired":0,"bought":false}
	Engine.time_scale=4
	for frame in 1800:
		await physics_frame
		for id in samples:
			var a=g.fighters[id];var s: Dictionary=g.players[id];var row: Dictionary=samples[id]
			row.distance=maxf(row.distance,a.position.distance_to(row.start));row.jets+=int(a.tribes_state.jetting);row.ski+=int(a.tribes_state.skiing);row.fired=maxi(row.fired,s.shots);row.bought=row.bought or s.tribes_pack!="none"
		if frame%600==0:print("ST_BOT_PROGRESS ",frame," scores=",g.match_mode.scores)
	Engine.time_scale=1
	for id in samples:
		samples[id]["goal"]=g.bots.brains[id].goal;samples[id]["kind"]=g.bots.brains[id].goal_kind;samples[id]["position"]=g.fighters[id].position;samples[id]["path"]=g.bots.brains[id].path;samples[id]["step"]=g.bots.brains[id].step
	var ok:=true
	for row in samples.values():ok=ok and row.distance>20 and row.jets>0
	var result:={"passed":ok,"players":samples,"captures":g.match_mode.scores}
	FileAccess.open("res://test-results/st-tribes/bots.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("ST_BOTS ",JSON.stringify(result))
	g.disconnect_game();g.free();quit(0 if ok else 1)
