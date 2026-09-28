extends SceneTree
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST tactics",0,20,30,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for i in 12:g._add_player(-i-1,"ST Tactics %d"%i)
	if not is_instance_valid(g.bots):g.bots=load("res://deathmatch/bots.gd").new();g.add_child(g.bots);g.bots.setup(g)
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var tribes=ai.tribes;var mode=g.match_mode;var rules=mode.tribes;var pads=rules.stations()
	for team in [0,1]:
		var members: Array=g.players.keys().filter(func(id):return id<0 and g.players[id].team==team)
		var jobs: Array=members.map(func(id):return tribes.role(id));jobs.sort()
		check(jobs.count("flag_defense")==1 and jobs.count("repairer")==1 and jobs.count("capper")>=2,"Healthy base frees multiple attackers for team %d"%team)
		for id in members:
			var kit: Dictionary=tribes.outfit(tribes.role(id));check(rules.Arsenal.valid_loadout(kit.armour,kit.guns,kit.pack),"Legal role loadout %d"%id)
		var runner: int=members.filter(func(id):return tribes.role(id)=="capper")[0]
		mode.flags[1-team].carrier=runner;g.players[runner].hp=10
		var rows: Array=[];tribes.goals(runner,ai.new_brain(runner),rows)
		check(rows.size()==1 and rows[0].key=="st:capture","Carrier ignores purchases and unrelated fights %d"%team)
		# Low-health carrier logic may have initiated a pass above. Restore
		# possession for the separate two-flag role assignment assertion.
		mode.flags[1-team].carrier=runner;mode.flags[1-team].dropped=false
		mode.flags[team].carrier=g.players.keys().filter(func(id):return id<0 and g.players[id].team!=team)[0]
		var escort: int=members.filter(func(id):return tribes.role(id)=="escort")[0]
		rows=[];tribes.goals(escort,ai.new_brain(escort),rows)
		check(rows.any(func(r):return r.kind=="escort") and not rows.any(func(r):return r.kind=="intercept"),"One escort protects the carrier during the recovery push %d"%team)
		mode.return_flag(team);mode.return_flag(1-team)
		var repairer: int=members.filter(func(id):return tribes.role(id)=="repairer")[0]
		var base: Dictionary=tribes.generator(team);var s: Dictionary=g.players[repairer];var actor=g.fighters[repairer]
		pads.health[team]=0;s.tribes_pack="none";actor.tribes_state.pack="none";s.owned.erase(8)
		actor.position=base.repair_position+Vector3(0,0,4)
		check(not pads.recover_pack(repairer),"Emergency rack rejects distant player %d"%team)
		actor.position=base.repair_position;s.dead=true
		check(not pads.recover_pack(repairer),"Emergency rack rejects dead player %d"%team);s.dead=false
		var paid: int=s.tribes_paid;var energy: float=actor.tribes_state.energy;var hp: int=s.hp
		check(pads.recover_pack(repairer) and s.tribes_pack=="repair" and 8 in s.owned,"Unpowered base supplies normal repair pack %d"%team)
		check(s.tribes_paid==paid and actor.tribes_state.energy==energy and s.hp==hp,"Emergency pack grants no currency, healing or energy %d"%team)
		check(not pads.recover_pack(repairer),"Rack cannot stack or replace equipped backpack %d"%team)
		rows=[];var brain: Dictionary=ai.new_brain(repairer);tribes.goals(repairer,brain,rows)
		var repairs: Array=rows.filter(func(r):return r.kind=="st_repair")
		check(repairs.size()==1,"Repairer prioritises generator recovery %d"%team)
		actor.position=base.position+base.frame.basis.z*3.8;brain.goal_kind="st_repair";brain.support=team
		var point: Vector3=base.frame*Vector3(0,0,1.05)
		ai.aim(repairer,point,1);tribes.combat(repairer,brain,1.0/60)
		check(s.fire and s.weapon==8,"Bot aims repair gun at actual generator collider %d"%team)
		for frame in 101:rules.combat.beam(repairer,8,ai.eye(repairer),(point-ai.eye(repairer)).normalized(),1)
		check(pads.powered(team),"Bot repair beam restores real station power %d"%team)
		pads.health[team]=pads.GENERATOR_HP
	dynamic_cases()
	await build_case()
	# Route connectivity includes elevated flags and indoor inventory pads.
	for team in [0,1]:
		for row in pads.rows:
			if row.team!=team:continue
			var route: PackedVector3Array=tribes.path(mode.bases[1-team],row.position)
			check(route.size()>2 and route[-1].distance_to(row.position)<.1,"Cross-map route reaches interior station %d"%team)
		var route: PackedVector3Array=tribes.path(mode.bases[team],mode.bases[1-team])
		check(route.size()>2 and route[-1].distance_to(mode.bases[1-team])<.1,"Cross-map flag route %d"%team)
		var lane: PackedVector3Array=tribes.routes.path(mode.bases[team],mode.bases[1-team],1)
		var visited: Array=[];var repeats:=false
		for point in lane.slice(1,lane.size()-1):
			if point in visited:repeats=true
			visited.append(point)
		check(not repeats,"Alternate flag lane has no out-and-back graph loops %d"%team)
	check(not tribes.routes.clear(Vector3.ZERO,Vector3(1,40,0)),"Graph rejects excessive single-edge climb")
	print("ST_BOT_TACTICS ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)

func dynamic_cases():
	var ai=g.bots;var tribes=ai.tribes;var mode=g.match_mode;var rules=mode.tribes;var pads=rules.stations()
	mode.return_flag(0);mode.return_flag(1)
	var group: Array=ai.objectives.members(-1)
	var enemies: Array=ai.objectives.members(-2)
	var home: Vector3=mode.bases[0]
	for i in group.size():
		var id: int=group[i];rules.apply_equipment(id,"light",[3,2,4],"energy")
		g.players[id].hp=100;g.fighters[id].position=home+Vector3(i*25,0,0);ai.brains[id]=ai.new_brain(id)
	tribes.assignments.clear();tribes.assignment_state.clear()
	var defender: int=group.filter(func(id):return tribes.role(id)=="flag_defense")[0]
	g.fighters[enemies[0]].position=home+Vector3(4,0,0);mode.flags[0].carrier=enemies[0]
	ai.brains[defender].plan_at=g.clock+100
	check(tribes.role(defender)=="chaser" and ai.brains[defender].plan_at==0,"Nearest former defender immediately switches to flag interception")
	check(group.filter(func(id):return tribes.role(id)=="chaser").size()==2,"Stolen flag sends two pursuers, not the entire team")
	mode.flags[0].carrier=0;mode.flags[0].dropped=true;mode.flags[0].position=g.fighters[group[-1]].position
	check(tribes.role(group[-1])=="chaser","Dropped flag recruits a nearer former attacker")
	var goals: Array=[];tribes.goals(group[-1],ai.brains[group[-1]],goals)
	check(goals.size()==1 and goals[0].key=="st:return","Flag recovery preempts armour shopping")
	mode.return_flag(0);var runner: int=group[-1];mode.flags[1].carrier=runner
	check(tribes.role(runner)=="capper" and group.filter(func(id):return tribes.role(id)=="escort").size()==2,"Carrier gets two available escorts while keeping the capture job")
	mode.return_flag(1);pads.health[0]=0
	for id in group.slice(0,2):rules.apply_equipment(id,"light",[3,2,4],"none")
	var repairs: Array=group.filter(func(id):return tribes.role(id)=="repairer")
	check(repairs.size()==2 and repairs.all(func(id):return id in group.slice(0,2)),"Power outage recruits two players able to recover a repair pack")
	var lost: int=repairs[0];g.players[lost].dead=true;rules.apply_equipment(group[2],"light",[3,2,4],"none")
	check(tribes.role(group[2])=="repairer","A repairer's death immediately recruits an eligible replacement")
	g.players[lost].dead=false;pads.health[0]=pads.GENERATOR_HP
	check(group.filter(func(id):return tribes.role(id)=="chaser" or tribes.role(id)=="escort").is_empty() and group.filter(func(id):return tribes.role(id)=="capper").size()>=2,"Resolved emergencies release bots back to attack")
	for id in enemies.slice(0,2):g.fighters[id].position=home+Vector3(10,0,0)
	ai.brains[group[0]].visible=enemies.slice(0,2);g.clock+=2
	check(group.filter(func(id):return tribes.role(id)=="flag_defense").size()==2,"Visible pressure on home base recruits a second defender")
	ai.brains[group[0]].visible=[];g.clock+=2
	check(group.filter(func(id):return tribes.role(id)=="flag_defense").size()==1,"Defensive reinforcement ends after visible pressure clears")
	var attacker: int=group.filter(func(id):return tribes.role(id)=="capper")[0]
	rules.apply_equipment(attacker,"heavy",[3,2,4],"energy");g.players[attacker].hp=rules.definition(attacker).hp
	goals=[];tribes.goals(attacker,ai.brains[attacker],goals)
	check(not goals.any(func(row):return row.kind=="supply"),"Equipped attacker uses current armour instead of detouring for role refits")
	rules.apply_equipment(attacker,"light",[3,2,0],"none")
	g.fighters[attacker].position=pads.rows[0].position+Vector3(0,0,5)
	goals=[];tribes.goals(attacker,ai.brains[attacker],goals)
	check(goals.any(func(row):return row.kind=="supply"),"Fresh capper can purchase an energy pack at a nearby spawn station")
	tribes.tactics.record(attacker).attempt_until=g.clock+100
	g.clock+=13;g.fighters[attacker].position+=Vector3(35,0,0);goals=[];tribes.goals(attacker,ai.brains[attacker],goals)
	check(goals.any(func(row):return row.kind=="supply"),"Initial refit survives the detour from a roof spawn to its doorway")
	g.clock+=33;goals=[];tribes.goals(attacker,ai.brains[attacker],goals)
	check(tribes.role(attacker)=="capper" and goals.any(func(row):return row.key=="st:flag") and not goals.any(func(row):return row.kind=="supply"),"Expired preparation window releases the capper without repeated shopping")
	for i in group.size():
		var id: int=group[i];rules.apply_equipment(id,"light",[3,2,4],"energy")
		g.fighters[id].position=mode.bases[1]+Vector3(35+i*8,-10,0)
		ai.brains[id]=ai.new_brain(id);ai.brains[id].visible=[enemies[0]];tribes.assignments[id]="capper"
	g.fighters[enemies[0]].position=mode.bases[1];g.players[enemies[0]].dead=false
	tribes.assignment_state.clear();g.clock+=3
	var jobs: Array=group.map(func(id):return tribes.role(id))
	check(jobs.count("escort")==1 and jobs.count("capper")>=1,"Visible flag defender recruits one close supporting attacker while retaining a runner")
	var screen: int=group[jobs.find("escort")] if jobs.has("escort") else 0
	goals=[]
	if screen!=0:tribes.goals(screen,ai.brains[screen],goals)
	check(goals.any(func(row):return row.key=="st:screen"),"Pre-grab support chooses a real firing position with sight of the observed defender")
	for id in group:ai.brains[id].visible=[]
	g.clock+=3;tribes.assignment_state.clear()
	check(not group.any(func(id):return tribes.role(id)=="escort"),"Cleared pressure releases pre-grab support instead of fixing its role")

func build_case():
	var ai=g.bots;var mode=g.match_mode;var rules=mode.tribes;var tribes=ai.tribes
	mode.return_flag(0);mode.return_flag(1)
	var group: Array=ai.objectives.members(-1)
	for id in group:
		rules.apply_equipment(id,"light",[3,2,4],"energy");g.fighters[id].position=mode.bases[0]+Vector3(40,0,0);ai.brains[id].visible=[]
	var builder: int=group[0];rules.apply_equipment(builder,"medium",[3,2,4],"turret");g.clock+=2
	var brain: Dictionary=ai.brains[builder];var goals: Array=[];tribes.goals(builder,brain,goals)
	var targets: Array=goals.filter(func(row):return row.kind=="st_build")
	check(tribes.role(builder)=="repairer" and targets.size()==1,"Maintenance bot retains its purchased turret and chooses a construction site")
	if targets.is_empty():return
	brain.goal=targets[0].position;brain.goal_kind="st_build";g.fighters[builder].position=brain.goal;g.fighters[builder].velocity=Vector3.ZERO
	await physics_frame;await physics_frame
	tribes.combat(builder,brain,1.0/60)
	check(rules.deployables.count(0,"turret")==1 and g.players[builder].tribes_pack=="none","Bot builds a real turret on Stonehenge through ordinary placement checks")
	rules.deployables.reset()
