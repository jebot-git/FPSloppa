extends SceneTree
## Accelerated ordinary 60 Hz physics: no teleports, forced damage or round wins.
var g
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args();var label: String=args[0] if not args.is_empty() else "after"
	var results: Array=[]
	for map in preload("res://deathmatch/modes/defusal_maps.gd").IDS:
		if args.size()>1 and not map in args.slice(1):continue
		seed(7129)
		g=load("res://deathmatch/arena.tscn").instantiate();g.match_mode.defusal=load("res://tools/defusal/series_rules.gd").new();root.add_child(g)
		g.max_clients=16;g.selected_map=map;g.start_host("DE bot review",0,20,60,true,"de")
		g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true;g._spawn(1)
		for id in [-1,-2,-3]:g._peer_left(id)
		for i in 12:
			g._add_player(-1000-i,"Bot "+str(i+1));g.players[-1000-i].team=i%2;g._spawn(-1000-i)
		g.dedicated=true;g.bot_population.count_target=12
		var de=g.match_mode.defusal;de.reset()
		while not g.bots.ready_to_walk or not g.bots.navigation.ready():await physics_frame
		var samples: Array=[];var starts: Dictionary={};var exits: Array=[];var round_seen:=0;var next_sample:=0.0;var phase:=""
		var deadline: float=g.clock+1100
		while de.phase!="finished" and g.clock<deadline:
			await physics_frame;g._physics_process(1.0/60)
			if phase!=de.phase:
				phase=de.phase;print("DE_AI_SOAK ",label," ",map," ",de.round_id," ",phase," ",g.clock)
			if de.phase!="live":continue
			if round_seen!=de.round_id:
				round_seen=de.round_id;starts.clear()
				for id in g.bots.brains:
					starts[id]={"point":g.fighters[id].position,"time":g.clock,"left":false}
			for id in starts:
				if not starts[id].left and g.fighters[id].position.distance_to(starts[id].point)>8:
					starts[id].left=true;exits.append({"round":de.round_id,"id":id,"seconds":g.clock-starts[id].time})
			if g.clock<next_sample:continue
			next_sample=g.clock+.5
			var bots: Array=[]
			for id in g.bots.brains:
				var s: Dictionary=g.players[id];var b: Dictionary=g.bots.brains[id];var c: Dictionary=g.variant_combat.cs.state(id)
				bots.append({"id":id,"dead":s.dead,"hp":s.hp,"position":g.fighters[id].position,"goal":b.goal_key,"target":b.goal,"enemy":b.enemy,"seen":g.clock-b.last_seen_at,"fire":s.fire,"yaw":s.yaw,"weapon":s.weapon,"shots":s.shots,"clip":c.clips.get(s.weapon,0),"reloading":c.reloading,"holstered":de.gun_holstered(id),"path":b.path.size(),"step":b.step})
			samples.append({"time":g.clock,"round":de.round_id,"carrier":de.carrier,"held":de.held,"defuser":de.defuser,"planted":de.planted,"bots":bots})
		var result:={"map":map,"map_sha256":g.map_sha,"completed":de.phase=="finished","rounds":de.round_id,"scores":g.match_mode.scores.duplicate(),"seconds":g.clock,"spawn_exits":exits,"samples":samples}
		FileAccess.open("res://test-results/de-bot-review/"+label+"-"+map+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
		results.append({"map":map,"completed":result.completed,"rounds":de.round_id,"seconds":g.clock})
		g.disconnect_game();g.free();await process_frame;await process_frame
	print("DE_AI_SOAK_RESULT ",JSON.stringify(results));quit(0 if results.all(func(row):return row.completed) else 1)
