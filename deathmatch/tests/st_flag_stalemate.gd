extends SceneTree
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	seed(9305);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST flag recovery",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for i in 12:g._add_player(-i-1,"Recovery %d"%i)
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var st=ai.tribes;var mode=g.match_mode;var rules=mode.tribes;var pads=rules.stations()
	g.clock=100
	var groups: Array=[ai.objectives.members(-1),ai.objectives.members(-2)]
	for team in [0,1]:
		for i in groups[team].size():
			var id: int=groups[team][i];rules.apply_equipment(id,"light",[3,2,4],"energy")
			g.fighters[id].position=mode.bases[team]+Vector3(i*3,0,0);g.fighters[id].velocity=Vector3.ZERO
			g.players[id].hp=100;g.players[id].dead=false;ai.brains[id]=ai.new_brain(id)
		mode.flags[1-team].carrier=groups[team][0];mode.flags[1-team].position=g.fighters[groups[team][0]].position
	await physics_frame
	for team in [0,1]:
		var group: Array=groups[team];var jobs: Array=group.map(func(id):return st.role(id))
		check(jobs.count("chaser")==4 and jobs.count("escort")==1 and jobs.count("capper")==1,"Two-flag stalemate assigns four recovery bots and one escort on team %d"%team)
		for id in group:
			var b: Dictionary=ai.brains[id];b.visible=groups[1-team];b.enemy=groups[1-team][-1];b.seen_position=g.fighters[b.enemy].position
			g.players[id].hp=20;g.players[id].tribes_kit=false;b.refilling=true
			# Optional support, low health and nearby station refits must not
			# replace a recovery mission in the complete planner.
			b.equipment_target=0;b.equipment_aim_until=g.clock+1
			var rows: Array=[];st.goals(id,b,rows)
			check(not rows.any(func(row):return row.key=="st:flag"),"Bot %d never targets the flag on its friendly carrier"%id)
			if st.role(id)=="chaser":
				ai.plan(id,b)
				check(b.goal_key=="st:intercept","Recovery bot %d keeps interception under supply and combat pressure"%id)
	# With the home flag dropped, recovery bots must touch it, not guard it.
	mode.flags[0].carrier=0;mode.flags[0].dropped=true;mode.flags[0].position=mode.bases[0]+Vector3(0,0,20)
	for id in groups[0]:
		if st.role(id)!="chaser":continue
		var rows: Array=[];st.goals(id,ai.brains[id],rows)
		check(rows.size()==1 and rows[0].key=="st:return","Recovery bot %d switches immediately to the dropped home flag"%id)
	# Essential power recovery gets at most one eligible specialist; the
	# remaining attackers still hunt the carrier. Equipped energy packs
	# cannot be exchanged at a powerless inventory station.
	mode.flags[0].dropped=false;mode.flags[0].carrier=groups[1][0]
	var repairer: int=groups[0][-1];rules.apply_equipment(repairer,"medium",[3,2,4,1],"repair")
	pads.health[0]=0;st.assignment_state.clear()
	var jobs: Array=groups[0].map(func(id):return st.role(id))
	check(jobs.count("repairer")==1 and st.role(repairer)=="repairer" and jobs.count("chaser")==3,"Power outage reserves one capable repairer and preserves three pursuers")
	pads.health[0]=pads.GENERATOR_HP
	var escort: int=groups[0].filter(func(id):return st.role(id)=="escort")[0]
	g.players[escort].dead=true
	jobs=groups[0].filter(func(id):return not g.players[id].dead).map(func(id):return st.role(id))
	check(jobs.count("escort")==1 and jobs.count("chaser")==3,"Escort death replaces protection without reclaiming the recovery squad")
	var survivor: int=groups[0].filter(func(id):return not g.players[id].dead and id!=groups[0][0])[0]
	for id in groups[0]:g.players[id].dead=id not in [groups[0][0],survivor]
	check(st.role(survivor)=="chaser","Last non-carrier teammate recovers the flag instead of escorting")
	for id in groups[0]:g.players[id].dead=false;ai.brains[id].visible=[]
	mode.return_flag(0);mode.return_flag(1)
	jobs=groups[0].map(func(id):return st.role(id))
	check(jobs.count("capper")>=2 and jobs.count("chaser")==0 and jobs.count("flag_defense")==1,"Flag recovery restores ordinary attack and defence assignments")
	print("ST_FLAG_STALEMATE ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
