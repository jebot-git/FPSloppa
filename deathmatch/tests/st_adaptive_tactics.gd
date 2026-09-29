extends SceneTree
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	seed(7129)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("ST adaptation",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for i in 6:g._add_player(-i-1,"Adaptive %d"%i);g.players[-i-1].team=0
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var st=ai.tribes;var t=st.tactics;var rules=g.match_mode.tribes
	st.routes.build();g.clock=100;t.epoch=g.map_epoch;t.next_tick=0
	for id in g.players.keys().filter(func(key):return key<0):
		g.players[id].team=0;rules.apply_equipment(id,"light",[3,2,0],"none")
		g.fighters[id].position=g.match_mode.bases[0];ai.brains[id]=ai.new_brain(id);st.assignments[id]="capper"
	var id:=-1;var s: Dictionary=g.players[id];var a=g.fighters[id];var b: Dictionary=ai.brains[id]
	b.goal_key="st:flag";b.goal_kind="objective";b.goal=g.match_mode.bases[1]
	var before: int=t.lane(id);s.dead=true;t.tick()
	check(t.lane(id)!=before,"Failed attack changes the next lane")
	var chosen: int=t.lane(id);g.clock+=1;t.tick();check(t.lane(id)==chosen,"A corpse records one failure rather than rotating each tick")
	s.dead=false;s.serial+=1;ai.brains[id]=ai.new_brain(id);g.clock+=1;t.tick()
	check(t.lane(id)==chosen,"Attack experience survives a fresh bot brain and respawn")
	var point: Vector3=g.match_mode.bases[0]+Vector3(40,-15,0)
	t.reject_stage(id,g.match_mode.bases[0],point)
	check(t.stage_cost(id,g.match_mode.bases[0],point)>0,"Failed tower launch remains discouraged after brain replacement")
	rules.apply_equipment(id,"heavy",[3,2,0],"none");check(t.stage_cost(id,g.match_mode.bases[0],point)==0,"Launch experience is specific to armour flight capability")
	rules.apply_equipment(id,"light",[3,2,0],"none")
	g.clock+=181;check(t.stage_cost(id,g.match_mode.bases[0],point)==0,"Failed launch memory expires")
	# Replanning the same circle cannot reset progress merely by changing nodes.
	b=ai.new_brain(id);ai.brains[id]=b;b.goal_key="st:flag";b.goal_kind="objective";b.goal=g.match_mode.bases[1]
	a.position=Vector3(32,100.56,0);b.path=st.routes.path(a.position,b.goal);b.step=1
	var m: Dictionary=t.record(id);m.watches.clear();m.failures.clear()
	for i in 41:
		g.clock+=1;a.position=Vector3(32,100.56,0)+Vector3(sin(i)*1.5,0,cos(i)*1.5)
		b.route_at=g.clock+10;t.watch(id,b,m)
	check(m.recoveries>0 and m.failures.size()>0,"Circling with fresh route timers triggers bounded progress recovery")
	check(b.has("st_recovery") and st.routes.clear(a.position,b.st_recovery.point),"Recovery backs out along a real clear terrain corridor")
	if b.has("st_recovery"):
		g.clock=b.st_recovery.until+.1;t.recover(id,b)
		check(not b.has("st_recovery") and b.plan_at==0,"Recovery expires and requests a fresh route")
	var route: PackedVector3Array=st.routes.path(g.match_mode.bases[0],g.match_mode.bases[1])
	var penalized: PackedVector3Array=st.routes.path(g.match_mode.bases[0],g.match_mode.bases[1],0,[{"point":route[route.size()/2],"until":g.clock+100}])
	check(penalized!=route and penalized[-1]==route[-1],"Experienced trouble changes the approach without abandoning the objective")
	check(st.routes.path(g.match_mode.bases[0],g.match_mode.bases[1])==route,"Route penalties do not leak into another bot's search")
	# Turning after steering used to send correct movement backwards relative
	# to the view, hiding the flag defender throughout the final jet approach.
	b=ai.new_brain(id);b.goal=g.match_mode.bases[1];b.goal_kind="objective";b.goal_key="st:flag"
	a.position=b.goal+Vector3(0,-12,30);a.velocity=Vector3(0,4,-11);s.yaw=PI
	b.tower={"goal":b.goal,"stage":a.position,"phase":"flight","at":g.clock}
	st.steer(id,b)
	check(absf(angle_difference(s.yaw,0))<PI-.1,"Final tower flight turns perception toward the flag deck")
	s.yaw=PI;b.equipment_aim_until=g.clock+1;st.steer(id,b)
	check(is_equal_approx(s.yaw,PI),"Tower steering preserves an active equipment firing aim")
	for friend in ai.brains:
		g.fighters[friend].position=g.match_mode.bases[0];ai.brains[friend]=ai.new_brain(friend)
	b=ai.brains[id];b.goal_key="st:flag";b.goal_kind="objective";b.goal=g.match_mode.bases[1];b.role="capper"
	a.position=b.goal+Vector3(0,-12,40);t.record(id).erase("attempt_after");t.watch(id,b,t.record(id));st.assignment_state.clear();st.assignments.clear()
	check(t.committed(id) and st.role(id)=="capper","Capper near the enemy flag is not diverted into optional siege or maintenance")
	g.match_mode.flags[0].dropped=true;g.match_mode.flags[0].position=a.position
	check(st.role(id)=="chaser","Public flag emergency interrupts an approach commitment")
	g.match_mode.return_flag(0);g.clock+=56
	check(not t.committed(id),"Approach commitment expires instead of making a permanent role")
	await wave_cases()
	carrier_cases()
	refill_cases()
	screen_cases()
	await rear_check_case()
	if "logic-only" not in OS.get_cmdline_user_args():await recovery_cases()
	print("ST_ADAPTIVE_TACTICS ",JSON.stringify({"checks":checks,"failures":failures,"stats":t.stats}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
func screen_cases():
	var ai=g.bots;var st=ai.tribes;var mode=g.match_mode
	var b: Dictionary=ai.new_brain(-1);b.role="siege";b.enemy=-2;b.visible=[-2]
	g.players[-1].team=0;g.players[-2].team=1;g.players[-2].dead=false
	mode.return_flag(0);mode.return_flag(1)
	g.fighters[-1].position=mode.bases[1]+Vector3(50,0,0);g.fighters[-2].position=mode.bases[1]
	check(st.offense.screen_enemy(-1,b),"Siege support prioritises a visible flag defender over equipment")
	b.visible=[];check(not st.offense.screen_enemy(-1,b),"Remembered or hidden defender cannot interrupt equipment targeting")
	b.visible=[-2];g.fighters[-2].position=mode.bases[1]+Vector3(180,0,0)
	check(not st.offense.screen_enemy(-1,b),"Distant player does not distract support from its base attack")
	g.fighters[-1].position=mode.bases[0];g.fighters[-2].position=mode.bases[0]+Vector3(40,0,0)
	b.role="escort";mode.flags[1].carrier=-1
	check(st.offense.screen_enemy(-1,b),"Carrier's visible pursuer takes precedence away from the flag stand")
	mode.return_flag(1);b.role="repairer"
	check(not st.offense.screen_enemy(-1,b),"Ordinary maintenance retains its existing threat policy")
func rear_check_case():
	var ai=g.bots;var st=ai.tribes;var mode=g.match_mode
	var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b
	var s: Dictionary=g.players[-1];s.team=0;s.yaw=0;s.pitch=0
	g.players[-2].team=1;g.players[-2].dead=false
	var actor=g.fighters[-1];actor.position=Vector3(0,230,0);actor.velocity=Vector3(0,0,-10)
	g.fighters[-2].position=Vector3(0,230,40)
	b.goal=Vector3(0,230,-100);b.goal_kind="objective";b.goal_key="st:capture";b.path=PackedVector3Array([b.goal]);b.step=0
	mode.flags[1].carrier=-1;g.clock=350;await physics_frame
	ai.perceive(-1,b);check(-2 not in b.visible,"Carrier does not initially see a distant pursuer behind it")
	for frame in 45:
		g.clock=350+frame/60.0;st.steer(-1,b)
	var world_move: Vector3=Basis(Vector3.UP,s.yaw)*Vector3(s.move.x,0,s.move.y)
	check(world_move.z<0,"Rear view check preserves forward escape steering")
	ai.perceive(-1,b);check(-2 in b.visible,"Periodic carrier look-back acquires a pursuer through normal perception")
	mode.return_flag(1)
func wave_cases():
	var ai=g.bots;var st=ai.tribes;var t=st.tactics;var mode=g.match_mode
	t.waves.clear();mode.return_flag(0);mode.return_flag(1)
	var route: PackedVector3Array=st.routes.path(mode.bases[0],mode.bases[1]);var anchor:=Vector3.ZERO
	for p in route:
		if p.distance_to(mode.bases[1])>100 and p.distance_to(mode.bases[1])<135:anchor=p;break
	for id in ai.brains:
		g.players[id].dead=false;g.players[id].hp=100;ai.brains[id]=ai.new_brain(id);st.assignments[id]="flag_defense"
	for id in [-1,-2]:
		st.assignments[id]="capper";g.fighters[id].position=anchor+Vector3(0,0,20);ai.brains[id].path=route
	t.update_wave(0)
	check(t.waves.has(0) and t.waves[0].members.size()==2,"Nearby attackers form a bounded coordinated push")
	if not t.waves.has(0):return
	var wave: Dictionary=t.waves[0];var rows: Array=[]
	check(wave.phase=="attack" and not t.push_goal(-1,rows) and rows.is_empty(),"Coordinated push keeps the existing ski route without a stopping objective")
	check(t.committed(-1) and t.committed(-2),"Moving attackers retain their roles for the bounded approach")
	g.players[-2].dead=true;t.update_wave(0)
	check(wave.members==[-1] and wave.phase=="attack","Partner death never makes the survivor wait")
	g.clock=wave.until+.1;t.update_wave(0)
	check(wave.members.is_empty(),"Moving attack commitment expires")
	wave.members=[-1,-2];wave.until=g.clock+22;mode.flags[0].dropped=true;t.update_wave(0)
	check(t.waves[0].members.is_empty() and not t.push_goal(-1,[]),"Flag emergency immediately cancels attack grouping")
	mode.return_flag(0);t.waves.clear();await physics_frame
func carrier_cases():
	var ai=g.bots;var st=ai.tribes;var t=st.tactics;var mode=g.match_mode
	var b: Dictionary=ai.brains[-1];var rows: Array=[]
	g.fighters[-1].position=mode.bases[0];mode.flags[1].carrier=-1;mode.flags[0].carrier=-2
	t.carrier_goal(-1,b,rows)
	check(rows.size()==1 and rows[0].kind=="st_hold" and rows[0].position.distance_to(mode.bases[0])>10,"Carrier seeks bunker cover while its own flag is stolen")
	var hold: Vector3=rows[0].position;rows=[];t.carrier_goal(-1,b,rows)
	check(rows[0].position==hold,"Carrier hold does not oscillate between stations each planning tick")
	mode.return_flag(0);rows=[];t.carrier_goal(-1,b,rows)
	check(rows[0].key=="st:capture","Own flag return immediately restores capture objective")
	mode.flags[0].dropped=true;mode.flags[0].position=g.fighters[-1].position+Vector3(4,0,0);rows=[];t.carrier_goal(-1,b,rows)
	check(rows[0].key=="st:carrier-return","Carrier can touch-return a nearby dropped home flag")
	mode.return_flag(0);st.assignments[-2]="escort";st.assignments[-3]="escort"
	b.path=st.routes.path(mode.bases[0]+Vector3(60,-20,0),mode.bases[0]);b.step=1
	g.fighters[-1].position=b.path[0]
	var first: Vector3=t.escort_point(-2,-1);var second: Vector3=t.escort_point(-3,-1)
	check(first.distance_to(second)>6 and first.distance_to(g.fighters[-1].position)>4,"Carrier escorts use separate screening and trailing positions")
	mode.return_flag(1)
func refill_cases():
	var ai=g.bots;var st=ai.tribes;var rules=g.match_mode.tribes
	var b: Dictionary=ai.brains[-1];g.fighters[-1].position=rules.stations().rows[0].position+Vector3(0,0,4)
	g.players[-1].hp=40;g.players[-1].tribes_kit=false;var rows: Array=[];st.goals(-1,b,rows)
	check(b.get("refilling",false) and rows.any(func(row):return row.kind=="supply"),"Injured bot commits to resupply")
	g.players[-1].hp=60;rows=[];st.goals(-1,b,rows)
	check(b.refilling and rows.any(func(row):return row.kind=="supply"),"Partial healing above the entry threshold does not restart the attack")
	g.players[-1].hp=90;rows=[];st.goals(-1,b,rows)
	check(not b.refilling,"Healthy and rearmed bot releases its resupply commitment")
func recovery_cases():
	var ai=g.bots;var st=ai.tribes;var t=st.tactics;var rules=g.match_mode.tribes;var pads=rules.stations()
	for id in g.players.keys():
		if id<0 and id!=-1:g._peer_left(id)
	var cases: Array=[
		{"name":"blue bunker outer approach","team":0,"armour":"light","start":Vector3(159.1326,121.3605,-78.56419),"goal":st.generator(1).position+st.generator(1).frame.basis.z*6},
		{"name":"blue inventory below roof","team":1,"armour":"light","start":Vector3(155.8512,121.8844,-117.1212),"goal":pads.rows[3].position},
		{"name":"red heavy tower foothill","team":0,"armour":"heavy","start":Vector3(-170.6291,111.1844,102.6849),"goal":g.match_mode.bases[0]},
		{"name":"blue flag low approach","team":0,"armour":"light","start":Vector3(129.5355,108.9624,-120.5305),"goal":g.match_mode.bases[1]}]
	var report: Array=[];var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	for row in cases:
		if "heavy-only" in OS.get_cmdline_user_args() and row.armour!="heavy":continue
		s.team=row.team;s.dead=false;s.serial+=1;s.yaw=0;s.pitch=0;rules.apply_equipment(-1,row.armour,[3,2,0],"none")
		actor.position=row.start;actor.velocity=Vector3.ZERO;actor.jump_held=false;t.memory.clear()
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=row.goal;b.goal_key="recovery-fixture";b.goal_kind="objective"
		b.path=st.routes.path(actor.position,b.goal);var passed:=false;var elapsed:=0.0;var samples: Array=[]
		for frame in 15000:
			g.clock+=1.0/60;elapsed+=1.0/60
			if frame%30==0:t.watch(-1,b,t.record(-1))
			if g.clock>=b.route_at and not b.has("st_recovery"):
				b.path=st.routes.path(actor.position,b.goal,0,t.detours(-1));b.step=0;b.route_at=g.clock+10
			st.steer(-1,b);s.last_input=g.clock;g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			if actor.position.distance_to(row.goal)<1.5:passed=true;break
			if frame%300==0 or "detail" in OS.get_cmdline_user_args() and frame%30==0:samples.append({"seconds":elapsed,"position":actor.position,"phase":b.get("travel_phase",""),"recoveries":t.record(-1).recoveries,"energy":actor.tribes_state.energy,"velocity":actor.velocity,"tower_phase":b.get("tower",{}).get("phase",""),"stage":b.get("tower",{}).get("stage",Vector3.ZERO)})
			if frame%600==0:await process_frame
		check(passed,"Real physics escapes recorded midmatch position: "+row.name)
		report.append({"case":row.name,"passed":passed,"seconds":elapsed,"recoveries":t.record(-1).recoveries,"samples":samples})
	FileAccess.open("res://test-results/st-tribes/research/adaptive-recovery.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
