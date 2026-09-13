extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
var g
var w
var failures: Array=[]
var checks: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func step(seconds: float) -> void:
	for i in ceili(seconds*60):g.clock+=1./60.;w.tick(1./60.)
func fire_step(seconds: float) -> void:
	for i in ceili(seconds*60):g.clock+=1./60.;w._tick_cannons(w.robots.test,1./60.,w.bodies.test.get_rid())
func ready(id: int) -> void:
	var s: Dictionary=g.players[id];s.dead=false;s.spectator=false;s.hp=10000;s.armor=0;s.invulnerable=0.;s.input_blocked=false;s.use_at=0.;s.team=0 if id==1 else 1
	g.fighters[id].position=Vector3(9,0,-10);g.fighters[id].collision_mask=3;g.fighters[id].jump_held=false
func _initialize():call_deferred("run")
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1"
	g.start_host("BA2 tests",0,100,60,true,"tb","ut99");g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	var tf=g.match_mode.fortress
	check(g.match_mode.kind=="tb" and g.match_mode.NAMES.tb=="TITANBALL" and g.match_mode.team_game(),"TB identity and team assignment are available")
	check(tf.enabled() and g.armory.kind=="quake","TB enforces TF classes and Quake weapons even when UT99 was requested")
	g.armory.select("doom")
	check(tf.enabled() and g.armory.kind=="quake","TB also rejects Doom loadouts and retains TF/Quake")
	var loadouts={"scout":[0,2,5],"sniper":[0,2,9],"soldier":[0,2,3,6],"demoman":[0,2,4],"medic":[0,2,3,7],"heavy":[0,2,3,7],"pyro":[0,2,6,7],"spy":[0,2,3,5],"engineer":[0,2,3]}
	for role in loadouts:
		g.players[1].tf_next=role;g._spawn(1)
		check(g.players[1].owned==loadouts[role] and g.players[1].hp==tf.CLASSES[role].hp,"TB "+role+" receives TF health and Quake class loadout")
	g.players[1].tf_next="soldier";g._spawn(1)
	Fixture.build(g);g.match_mode.titanball.advance_time(60.);w=g.match_mode.fortress.walkers
	for id in g.players:ready(id)
	g.players[-2].spectator=true
	await physics_frame;await physics_frame
	var r: Dictionary=w.robots.test
	check(r.path.get_baked_length()>220.,"Long winding test route built")
	check(w.ladder_visible(r) and is_equal_approx(w.LADDER.y,.08) and w.LADDER.z==0,"Parked robot deploys belly ladder ending 8 cm above ground")
	var origin: Vector3=r.position;step(3)
	check(r.position==origin and r.speed==0.,"Unmanned robot stays stationary")
	check(not w.try_board(1,"test"),"Remote boarding rejected")
	var base: Vector3=w.transform(r)*w.LADDER
	g.fighters[1].position=base;g.fighters[-1].position=base+Vector3(.6,0,0)
	check(not w.handle_player(1,false) and r.pilot==0,"Proximity alone does not board")
	g.players[1].dead=true;check(not w.try_board(1,"test"),"Dead players cannot board");g.players[1].dead=false
	g.players[1].spectator=true;check(not w.try_board(1,"test"),"Spectators cannot board");g.players[1].spectator=false
	var serial: int=g.players[1].serial
	check(w.handle_player(1,true),"Jump at ladder boards cockpit")
	check(not w.try_board(-1,"test") and r.pilot==1,"Simultaneous second claimant cannot take occupied cockpit")
	check(not w.ladder_visible(r) and g.players[1].serial==serial+1 and g.fighters[1].position.distance_to(w.transform(r)*w.SEAT)<.001,"Boarding teleports pilot and retracts ladder atomically")
	check(g.fighters[1].collision_mask==0 and not g.match_mode.fortress.can_fire(1,2) and not g.match_mode.fortress.can_act(1),"Mounted player movement and personal combat are disabled")
	g.fighters[-1].position=Vector3(9,0,-10)
	step(1);check(r.speed>0.1 and r.speed<.5,"Boarded robot accelerates gradually")
	step(1);check(absf(r.speed-.8)<.001 and absf(r.distance-.8)<.01,"Cruise speed reached after two seconds")
	check(g.fighters[1].position.distance_to(w.transform(r)*w.SEAT)<.001,"Pilot remains attached while moving")
	var route_clear:=true
	for i in range(0,int(r.path.get_baked_length()),2):
		var pose: Transform3D=w.Route.sample(r.path,float(i))
		if w.bodies.test.test_move(pose,Vector3.ZERO):route_clear=false;break
	check(route_clear,"Robot collision envelope clears the full winding corridor")
	var moving_speed: float=r.speed;r.speed=0.
	var left: Vector3=w.cannon_origin(r,0);var right: Vector3=w.cannon_origin(r,2)
	g.fighters[-1].position=w.transform(r)*Vector3(2.3362,0,30);g.fighters[-3].position=w.transform(r)*Vector3(-2.3362,0,30)
	check(g.match_mode.fortress.sentry_target(left,0,18,[w.bodies.test.get_rid()])==0 and g.match_mode.fortress.sentry_target(left,0,w.CANNON_RANGE,[w.bodies.test.get_rid()])!=0,"Robot engages beyond the ordinary 18-metre sentry range")
	var hp_before: int=g.players[-1].hp;var ammo_before: Array=g.players[1].ammo.duplicate()
	var overheated:=false
	for i in 900:
		fire_step(1./60.)
		if r.overheated.all(func(hot):return hot):overheated=true;break
	check(overheated and r.heat.all(func(h):return h>=99.9),"Both linked cannon pairs overheat after sustained fire")
	check(hp_before-g.players[-1].hp==192 and g.players[1].ammo==ammo_before,"Each left cannon fires eight 12-damage shots without consuming player ammo")
	check(not r.has("hp") and g.match_mode.fortress.buildings.values().all(func(b):return b.get("tb_station",false)),"Cannons have no HP or destructible building state")
	var before_cooling: int=g.players[-1].hp;fire_step(1)
	check(g.players[-1].hp==before_cooling and r.heat[0]<80 and r.overheated[0],"Overheated cannons stop shooting while cooling")
	fire_step(2.1);check(not r.overheated[0],"Cannon resumes eligibility only after lower heat threshold")
	g.players[-1].invulnerable=g.clock+10
	check(not tf.sentry_enemy(-1,0),"Invulnerable opponents are not targeted")
	g.players[-1].invulnerable=0;g.players[-1].tf_disguise={"team":0}
	check(not tf.sentry_enemy(-1,0),"Friendly disguises suppress cannon targeting")
	g.players[-1].tf_disguise={};tf.effects[-1]={"kind":"spy","until":g.clock+10}
	check(not tf.sentry_enemy(-1,0),"Cloaked spies are not targeted")
	tf.effects.erase(-1)
	g.players[-1].team=0;check(not tf.sentry_enemy(-1,0),"Cannons reject friendly players");g.players[-1].team=1
	var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(24,12,.3);shape.shape=box;wall.add_child(shape);wall.position=Vector3(0,6,20);g.get_node("Map").add_child(wall)
	await physics_frame
	r.scan_at=0.;var hp_blocked: int=g.players[-1].hp;var heat_before: float=r.heat[0];fire_step(1)
	check(g.players[-1].hp==hp_blocked and r.heat[0]<heat_before,"World occlusion blocks firing and idle cannons cool")
	wall.free();await physics_frame
	r.speed=moving_speed
	# Cannon-only ticks above deliberately skipped movement and boarding timers.
	step(1)
	g._use_for(1)
	await physics_frame;await physics_frame
	check(r.pilot==0 and g.fighters[1].collision_mask==3,"Use exits cockpit and restores player collision")
	check(r.speed>0 and not w.ladder_visible(r),"Ladder stays retracted during unmanned braking")
	step(1);check(r.speed>0.1 and r.speed<.5,"Dismount slows robot instead of stopping instantly")
	step(1);check(r.speed==0. and w.ladder_visible(r),"Robot halts and redeploys ladder")
	g.fighters[1].position=w.transform(r)*w.LADDER;g.fighters[1].jump_held=false
	check(w.try_board(1,"test"),"Stopped robot can be boarded again")
	step(2);g.players[1].hp=100;g._damage(1,-1,1000,"TEST",true)
	check(r.pilot==0 and g.players[1].dead,"Pilot death releases cockpit immediately")
	await physics_frame;await physics_frame
	step(1);check(r.speed>.1 and r.speed<.5,"Dead pilot collision does not interrupt gradual braking")
	step(1);check(r.speed==0. and w.ladder_visible(r),"Pilot death leads to gradual halt and boarding availability")
	ready(1);g.fighters[1].position=w.transform(r)*w.LADDER
	check(w.try_board(1,"test"),"Replacement pilot can board after death")
	step(2);w.departed(1);step(2)
	check(r.pilot==0 and r.speed==0.,"Disconnect cleanup releases pilot and stops robot")
	var idle_hp: int=g.players[-1].hp;r.heat=[50.,50.];step(1)
	check(g.players[-1].hp==idle_hp and r.heat.all(func(h):return absf(h-25.)<.001),"Unmanned cannons only cool and never fire")
	# Reset remains opt-in and restores an occupied pilot's normal collision.
	ready(1);g.fighters[1].position=w.transform(r)*w.LADDER;w.try_board(1,"test")
	w.reset();r=w.robots.test
	check(r.pilot==0 and g.fighters[1].collision_mask==3,"Round reset clears occupied cockpit and restores pilot collision")
	var wire: Array=w.snapshot();check(not wire[0].has("path") and wire[0].heat.size()==2,"Replication contains serializable authority state and two shared pair heat values")
	var route_length: float=r.path.get_baked_length()
	ready(1);g.fighters[1].position=w.transform(r)*w.LADDER;w.try_board(1,"test")
	r.distance=route_length-1.;var end_pose: Transform3D=w.Route.sample(r.path,r.distance)
	r.position=end_pose.origin;r.yaw=end_pose.basis.get_euler().y;r.speed=w.SPEED;r.from_speed=w.SPEED;r.to_speed=w.SPEED;r.transition=w.TRANSITION
	w._update_body(w.bodies.test,r);w.pin(1);await physics_frame;await physics_frame
	step(2)
	check(r.speed>0. and r.speed<w.SPEED,"Open route endpoint starts braking before the end")
	step(3)
	check(r.speed==0. and absf(r.distance-route_length)<.02,"Open route stops near its endpoint without overshoot")
	check(g.match_mode.titanball.winner==0 and g.intermission>0,"Reaching defender base awards attacker victory")
	g.intermission=0
	var prior_life: int=g.players[1].serial
	var pose: Dictionary=preload("res://deathmatch/vr/poses.gd").neutral()
	check(tf.physical.request_for(1,g.map_epoch,prior_life,1,"ability",pose,Vector3.ZERO) and r.pilot==0,"VR ability gesture dismounts from inside the hull")
	check(not tf.physical.request_for(1,g.map_epoch,prior_life,1,"ability",pose,Vector3.ZERO),"Stale VR dismount action is rejected")
	w.reset();r=w.robots.test;ready(1);g.fighters[1].position=w.transform(r)*w.LADDER;w.try_board(1,"test")
	var obstacle:=StaticBody3D.new();var obstacle_shape:=CollisionShape3D.new();var obstacle_box:=BoxShape3D.new();obstacle_box.size=Vector3(24,14,.3);obstacle_shape.shape=obstacle_box;obstacle.add_child(obstacle_shape);obstacle.position=Vector3(0,7,4);g.get_node("Map").add_child(obstacle)
	await physics_frame;await physics_frame;step(10)
	check(r.state=="blocked" and r.speed==0. and r.distance<2.5,"Robot halts at a solid obstacle instead of crossing it")
	obstacle.free();await physics_frame;await physics_frame;step(2)
	check(r.speed>.799,"Manned robot resumes after the route clears")
	w.configure([]);await physics_frame;await physics_frame
	check(w.bodies.is_empty() and w.robots.is_empty(),"Maps without explicit robot definitions contain no robot")
	# Ordinary engineer sentries retain their damage, cooldown and destructibility.
	for id in g.players:ready(id)
	g.players[-2].spectator=true;g.players[-3].spectator=true
	g.fighters[-1].position=Vector3(2,0,8);g.fighters[1].position=Vector3(0,0,-8)
	tf.buildings[123]={"owner":1,"team":0,"position":Vector3.ZERO,"kind":"sentry","hp":150,"ready":0.,"next":0.,"expires":g.clock+100}
	tf.tick_sentries();var sentry_hp: int=g.players[-1].hp
	g.clock+=.2;tf.tick_sentries()
	check(sentry_hp==9988 and g.players[-1].hp==sentry_hp,"Engineer sentries still deal 12 damage and respect shot cooldown")
	tf.damage_building(123,-1,150)
	check(not tf.buildings.has(123),"Ordinary engineer sentries remain destructible")
	var result={"checks":checks,"failures":failures,"route_m":route_length,"speed_mps":w.SPEED,"ladder_gap_m":w.LADDER.y,"sentry_range_m":w.CANNON_RANGE}
	var f:=FileAccess.open("res://test-results/ba2/gameplay/results.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("BA2_GAMEPLAY_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
