extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
var g
var w
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func step(frames: int) -> void:
	for i in frames:g.clock+=1./60.;w.tick(1./60.)
func prepare(role: String="soldier") -> void:
	w.reset();g.clock+=2.
	var s: Dictionary=g.players[1]
	s.dead=false;s.spectator=false;s.team=0;s.input_blocked=false;s.invulnerable=0.;s.hp=1;s.tf_class=role;s.weapon=6;s.armor=73;s.tier=1
	g.fighters[1].position=w.transform(w.robots.test)*w.LADDER;g.fighters[1].jump_held=false
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.start_host("Boarding tests",0,100,60,true,"tb");g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	Fixture.build(g);w=g.match_mode.fortress.walkers
	for id in g.players:
		g.players[id].spectator=id!=1;g.fighters[id].position=Vector3(10,0,-10)
	await physics_frame;await physics_frame
	var tf=g.match_mode.fortress;var s: Dictionary=g.players[1]
	for role in tf.CLASSES:
		prepare(role)
		check(w.try_board(1,"test") and s.hp==tf.max_health(1),"Wounded %s boards with exact class maximum HP"%role)
		check(w.robots.test.exit_lock==10. and w.snapshot()[0].exit_lock==10.,"%s starts a replicated ten-second exit lock"%role)
		s.hp-=7;w.enforce_pilot(1);w.pin(1)
		check(not w.try_board(1,"test") and s.hp==tf.max_health(1)-7,"Repeated %s boarding/pinning cannot heal again"%role)
	prepare();s.team=1
	check(not w.try_board(1,"test") and s.hp==1,"Defender cannot board or receive a heal")
	s.team=0;g.fighters[1].position=Vector3(10,0,-10)
	check(not w.try_board(1,"test") and s.hp==1,"Out-of-range boarding cannot heal")
	prepare();check(w.handle_player(1,true),"Jump boards for lock boundary test")
	var r: Dictionary=w.robots.test
	check(not w.leave(1),"Use exit rejected immediately after boarding")
	w.handle_player(1,false);w.handle_player(1,true)
	check(w.mounted(1),"Fresh jump exit rejected immediately after boarding")
	var other: int=-1;g.players[other].spectator=false;g.players[other].team=0;g.players[other].hp=1;g.players[other].dead=false;g.players[other].input_blocked=false
	g.fighters[other].position=w.transform(r)*w.LADDER
	check(not w.try_board(other,"test") and g.players[other].hp==1 and r.pilot==1,"Occupied cockpit rejects second player without healing them")
	g.players[other].spectator=true;g.fighters[other].position=Vector3(10,0,-10)
	s.hp=50;step(599)
	check(s.hp==50 and r.exit_lock>0. and not w.leave(1),"Damage persists and voluntary exit stays locked at 9.983 seconds")
	step(1);w.handle_player(1,true)
	check(w.mounted(1) and r.exit_lock==0.,"Held rejected jump does not auto-eject when ten seconds expire")
	w.handle_player(1,false);w.handle_player(1,true)
	check(not w.mounted(1) and s.hp==tf.definition(1).hp and s.weapon==6 and s.armor==73 and s.tier==1,"Fresh jump after ten seconds exits and restores class health and saved equipment")
	check(not w.try_board(1,"test"),"Existing reboarding cooldown remains enforced")
	prepare();w.try_board(1,"test");step(600)
	check(w.leave(1),"Use exit is allowed at exactly ten seconds")
	prepare();w.try_board(1,"test");g._damage(1,1,5000,"TEST",true)
	check(s.dead and not w.mounted(1) and w.robots.test.exit_lock==0. and s.armor==73,"Death ejects immediately during exit lock and restores equipment")
	prepare();w.try_board(1,"test");w.departed(1)
	check(not w.mounted(1) and s.armor==73,"Disconnect releases cockpit immediately during exit lock")
	FileAccess.open("res://test-results/ba2/gameplay/boarding-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BA2_BOARDING_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
