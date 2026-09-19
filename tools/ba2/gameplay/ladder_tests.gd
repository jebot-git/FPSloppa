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
func ready(id: int) -> void:
	var s: Dictionary=g.players[id]
	s.dead=false;s.spectator=false;s.team=0;s.hp=1;s.invulnerable=0.;s.input_blocked=false
	g.fighters[id].position=w.transform(w.robots.test)*w.LADDER;g.fighters[id].jump_held=false
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.start_host("Ladder tests",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	Fixture.build(g);w=g.match_mode.fortress.walkers
	for cause in ["exit","death","disconnect"]:
		g.match_mode.reset();g.intermission=0.;g.match_mode.titanball.advance_time(60.)
		for id in g.players:g.players[id].spectator=true;g.fighters[id].position=Vector3(10,0,-10)
		ready(1);await physics_frame;await physics_frame
		check(w.try_board(1,"test"),cause+": original pilot boards")
		step(600);var r: Dictionary=w.robots.test
		if cause=="exit":check(w.leave(1),"Original pilot exits after boarding lock")
		elif cause=="death":g._damage(1,1,5000,"TEST",true)
		else:w.departed(1)
		g.players[1].spectator=true;g.fighters[1].position=Vector3(10,0,-10)
		ready(-1)
		check(not w.reboard_until.has(-1),cause+": replacement has no personal reboarding cooldown")
		check(r.pilot==0 and r.speed>0. and not w.ladder_visible(r),cause+": empty moving robot keeps ladder retracted")
		check(not w.try_board(-1,"test") and g.players[-1].hp==1,cause+": direct replacement claim cannot bypass retracted ladder or heal")
		check(not w.handle_player(-1,true) and r.pilot==0,cause+": replacement jump cannot board during braking")
		step(150);ready(-1)
		check(not w.try_board(-1,"test") and not w.ladder_visible(r),cause+": boarding remains blocked halfway through braking")
		step(331);ready(-1)
		check(r.speed==0. and w.ladder_visible(r),cause+": stopped empty robot redeploys ladder after the settling delay")
		check(w.handle_player(-1,true) and r.pilot==-1 and g.players[-1].hp==g.match_mode.fortress.max_health(-1),cause+": new pilot boards through deployed ladder and receives normal heal")
		check(not w.ladder_visible(r),cause+": new reservation retracts ladder immediately")
	FileAccess.open("res://test-results/ba2/gameplay/ladder-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BA2_LADDER_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
