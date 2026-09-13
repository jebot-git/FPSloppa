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
func place(distance: float) -> void:
	g.match_mode.reset();g.intermission=0.;g.match_mode.titanball.advance_time(60.)
	var r: Dictionary=w.robots.test;var pose: Transform3D=w.Route.sample(r.path,distance)
	r.distance=distance;r.position=pose.origin;r.yaw=pose.basis.get_euler().y
	w.bodies.test.global_transform=w.transform(r);w._update_body(w.bodies.test,r)
	g.match_mode.titanball.observe("test",r)
	g.players[1].dead=false;g.players[1].spectator=false;g.players[1].team=0;g.players[1].input_blocked=false
	g.fighters[1].position=w.transform(r)*w.LADDER
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.start_host("Endpoint tests",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	Fixture.build(g);w=g.match_mode.fortress.walkers
	for id in g.players:
		g.players[id].spectator=id!=1;g.fighters[id].position=Vector3(1000,0,0)
	for distance in [298.8,299.21,299.477243765379,299.8,299.95]:
		place(distance);await physics_frame;await physics_frame
		check(w.try_board(1,"test"),"Board stationary payload at %.3f m"%distance)
		step(480);var r: Dictionary=w.robots.test
		check(r.distance>=299.98 and r.distance<=r.path.get_baked_length() and r.speed==0. and g.match_mode.titanball.winner==0,"Restart at %.3f m reaches delivery and stops without overshoot"%distance)
	place(299.0);await physics_frame;await physics_frame;w.try_board(1,"test");step(60)
	g._damage(1,1,5000,"TEST",true);step(120)
	var r: Dictionary=w.robots.test
	check(w.ladder_visible(r) and r.pilot==0 and r.distance<299.98,"Interrupted final approach stops short with an available ladder")
	g.players[1].dead=false;g.players[1].input_blocked=false;g.fighters[1].position=w.transform(r)*w.LADDER
	check(w.try_board(1,"test"),"Replacement pilot boards after final-approach death")
	step(480)
	check(r.distance>=299.98 and r.speed==0. and g.match_mode.titanball.winner==0,"Replacement pilot completes interrupted final approach")
	FileAccess.open("res://test-results/ba2/gameplay/endpoint-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BA2_ENDPOINT_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
