extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
var g
var w
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func person(id: int,at: Vector3,team: int=1) -> void:
	var s: Dictionary=g.players[id];s.team=team;s.hp=100;s.armor=0;s.dead=false;s.spectator=false;s.invulnerable=0.;s.input_blocked=false;s.tf_disguise={}
	g.fighters[id].position=at;g.fighters[id].collision_layer=2;g.fighters[id].collision_mask=3;g.fighters[id].jump_held=false
func arrange() -> Dictionary:
	w.reset();g.intermission=0;g.clock+=3;g.match_mode.titanball.preparation_left=0;g.match_mode.titanball.update_gate()
	for id in g.players:person(id,Vector3(900+id,0,0),0 if id==1 else 1)
	var r: Dictionary=w.robots.test
	person(1,w.transform(r)*w.LADDER,0);assert(w.try_board(1,"test"));return r
func wall(at: Vector3,size: Vector3) -> StaticBody3D:
	var b:=StaticBody3D.new();var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;c.shape=shape;b.add_child(c);g.get_node("Map").add_child(b);b.position=at;return b
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1";g.start_host("Cannon/crush",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	Fixture.build(g);w=g.match_mode.fortress.walkers
	var r:=arrange();await physics_frame;await physics_frame
	var target: Vector3=w.transform(r)*Vector3(2.3362,0,30)
	person(-1,target);person(-2,target+Vector3(.8,0,0));person(-3,target+Vector3(-.8,0,0),0)
	var origin: Vector3=w.cannon_origin(r,0);var point: Vector3=g.match_mode.fortress.sentry_target_point(-1);var delta:=point-origin
	r.pitches[0]=-atan2(delta.y,Vector2(delta.x,delta.z).length())
	w.cannon_impact(r,0,-1,point,w.bodies.test.get_rid())
	check(g.players[-1].hp==88,"Direct cannon hit stays at 12 damage without double splash")
	check(g.players[-2].hp<100 and g.players[-2].hp>88,"Nearby defender receives smaller splash damage")
	check(g.players[-3].hp==100,"Cannon splash respects disabled friendly fire")
	person(-2,target+Vector3(2,0,0));person(-1,target)
	w.cannon_impact(r,0,-1,point,w.bodies.test.get_rid())
	check(g.players[-2].hp==100,"Player beyond the small splash radius is unaffected")
	person(-2,target+Vector3(.8,0,0));g.players[-2].invulnerable=g.clock+5
	w.cannon_impact(r,0,-1,point,w.bodies.test.get_rid())
	check(g.players[-2].hp==100,"Splash retains normal spawn invulnerability")
	person(-2,target+Vector3(.8,0,0));var cover:=wall(target+Vector3(.4,1.2,0),Vector3(.1,2.4,3));await physics_frame
	w.cannon_impact(r,0,-1,point,w.bodies.test.get_rid())
	check(g.players[-2].hp==100,"Thin cover blocks cannon splash")
	cover.free();await physics_frame
	person(-2,target+Vector3(8,0,0));person(-3,target+Vector3(-8,0,0),0)
	var edge: Vector3=w.transform(r)*Vector3(32.3*tan(w.CANNON_CONE)+.6,0,32.3)
	person(-1,edge);r.ready=0;r.next=[0.,9999.];r.scan_at=0.;r.heat=[0.,0.]
	for i in 600:
		g.clock+=1./60.;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
		if g.players[-1].hp<100:break
	check(g.players[-1].hp<100,"Small splash reaches a defender just outside the old aiming cone")
	check(absf(r.pitches[0])<=w.PITCH_LIMIT,"Splash assistance retains the X hinge limit")
	# Preparation and no motion: even standing on the ladder is safe.
	r=arrange();person(-1,Vector3(.7,0,0));g.match_mode.titanball.preparation_left=60
	await physics_frame;await physics_frame
	w.tick(.1);check(not g.players[-1].dead and r.distance==0,"Preparation keeps defender underfoot safe while robot is parked")
	g.match_mode.titanball.advance_time(60.)
	person(-2,Vector3(-2,0,0),0);g.players[-1].armor=200;g.players[-1].invulnerable=g.clock+20
	await physics_frame;await physics_frame
	w.tick(.1)
	check(g.players[-1].dead and r.distance>0,"Moving robot kills ladder camper despite armour and temporary protection")
	check(g.fighters[-1].gibbed,"Squashed defender is marked gibbed on authority")
	check(g.players[-2].hp==100 and not g.players[1].dead,"Crush zone leaves nearby attacker and pilot unharmed")
	r=arrange();person(-1,Vector3(3.8,0,1.1));await physics_frame;await physics_frame
	await physics_frame;await physics_frame
	w.tick(.1)
	check(g.players[-1].dead and r.distance>0,"Defender touching a leg is crushed instead of blocking advancement")
	for side in [-1.,1.]:
		r=arrange()
		person(-1,w.transform(r)*(w.CRUSH_OFFSET+Vector3(side*5.25,0,0)))
		person(-2,w.transform(r)*(w.CRUSH_OFFSET+Vector3(side*5.75,0,0)))
		await physics_frame;await physics_frame;w.tick(.1)
		check(g.players[-1].dead,"Expanded footprint crushes defender 5.25 m from centre on side "+str(side))
		check(not g.players[-2].dead,"Defender 5.75 m from footprint centre remains outside on side "+str(side))
	r=arrange();person(-1,Vector3(0,0,-7));person(-2,Vector3(0,3,0));person(-3,Vector3(0,-3,0))
	await physics_frame;await physics_frame
	w.tick(.1)
	check(not g.players[-1].dead and not g.players[-2].dead and not g.players[-3].dead,"Crush radius excludes distant, elevated and below-floor defenders")
	r=arrange();person(-1,Vector3(2,0,0));cover=wall(Vector3(1,1.2,0),Vector3(.1,2.4,2));await physics_frame
	await physics_frame;await physics_frame
	w.tick(.1);check(not g.players[-1].dead,"Crush zone does not reach through a wall")
	cover.free();await physics_frame
	r=arrange();person(-1,Vector3(.7,0,0));cover=wall(Vector3(0,5,1),Vector3(20,10,.5));await physics_frame
	await physics_frame;await physics_frame
	w.tick(.1);check(r.state=="blocked" and not g.players[-1].dead,"A blocked robot does not activate crushing")
	cover.free();await physics_frame
	r=arrange();person(-1,Vector3(.7,0,0));g.players[-1].tf_disguise={"team":0};g.match_mode.fortress.effects[-1]={"kind":"spy","until":g.clock+10}
	await physics_frame;await physics_frame;w.tick(.1)
	check(g.players[-1].dead,"Crushing uses real defender team, including disguised cloaked campers")
	g.match_mode.fortress.effects.erase(-1)
	r=arrange();await physics_frame;await physics_frame;w.tick(1.0);w.leave(1,true);person(-1,w.transform(r)*Vector3(.7,0,0));await physics_frame;await physics_frame;w.tick(.1)
	check(g.players[-1].dead and r.speed>0,"Unmanned braking continues crushing only while still advancing")
	for i in 60:w.tick(.1)
	person(-1,w.transform(r)*Vector3(.7,0,0));w.tick(.1)
	check(not g.players[-1].dead and r.speed==0,"Stopped unmanned robot leaves the ladder zone safe")
	# Isolated open firing lane, so the range test measures the cannons rather than a city bend.
	w.configure([{"id":"test","points":[Vector3(1000,0,0),Vector3(1000,0,100)],"team":0,"loop":false}])
	r=arrange();person(-1,Vector3(1002.3362,0,55));r.ready=0
	for i in 300:
		g.clock+=1./60.;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
		if g.players[-1].hp<100:break
	check(g.players[-1].hp<100 and w.CANNON_RANGE==60,"Turrets engage distant targets beyond the previous 36-metre range")
	person(-1,Vector3(1002.3362,0,65));r.scan_at=0.;r.next=[0.,0.]
	for i in 120:g.clock+=1./60.;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
	check(g.players[-1].hp==100 and r.targets==[0,0],"Targets beyond 60 metres are not acquired or damaged")
	person(-1,Vector3(1002.3362,0,55));cover=wall(Vector3(1000,5,40),Vector3(20,10,.3));await physics_frame;await physics_frame;r.scan_at=0.
	for i in 120:g.clock+=1./60.;w._tick_cannons(r,1./60.,w.bodies.test.get_rid())
	check(g.players[-1].hp==100,"Distant suppression still respects intervening cover")
	cover.free()
	FileAccess.open("res://test-results/titanball/cannon-crush.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"splash_radius_m":w.SPLASH_RADIUS,"crush_radius_m":w.CRUSH_RADIUS},"  "))
	print("BA2_CANNON_CRUSH_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
