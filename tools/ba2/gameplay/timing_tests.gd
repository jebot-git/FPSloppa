extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
const Config=preload("res://deathmatch/server/config.gd")
var g
var w
var tb
var checks: Array=[]
var failures: Array=[]
var runs: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func simulate(label: String,on_seconds: float,off_seconds: float,initial_idle: float=0.,expect_finish: bool=true) -> void:
	g.match_mode.reset();g.match_mode.titanball.advance_time(60.);g.intermission=0.;g.round_left=600.;g.players[1].dead=false;g.players[1].spectator=false;g.players[1].input_blocked=false
	g.fighters[1].position=Vector3(1000,0,0)
	await physics_frame;await physics_frame
	var r: Dictionary=w.robots.test
	var elapsed:=0.;var manned:=0.;var checkpoint_times: Array=[];var old_cleared:=0
	var dt:=1./60.;var length: float=r.path.get_baked_length()
	while elapsed<960 and g.round_left>0 and not (r.distance>=length-.02 and r.speed==0):
		var want: bool=elapsed>=initial_idle and (off_seconds==0 or fposmod(elapsed-initial_idle,on_seconds+off_seconds)<on_seconds)
		if want and r.pilot==0 and w.ladder_visible(r):
			g.fighters[1].position=w.transform(r)*w.LADDER
			if not w.try_board(1,"test"):failures.append(label+" boarding failed");break
		elif not want and r.pilot!=0:
			if not w.leave(1):failures.append(label+" exit failed");break
			g.fighters[1].position=Vector3(1000,0,0)
		if r.pilot!=0:manned+=dt
		elapsed+=dt;g.clock+=dt;g.round_left=maxf(0,g.round_left-dt);w.tick(dt)
		if tb.cleared!=old_cleared:checkpoint_times.append(elapsed);old_cleared=tb.cleared
		if int(elapsed*60)%600==0:await physics_frame
	var result={"name":label,"seconds":elapsed,"manned_seconds":manned,"checkpoint_seconds":checkpoint_times,"remaining_seconds":g.round_left,"distance_m":r.distance,"speed":r.speed}
	runs.append(result);print("TIMING_RUN ",JSON.stringify(result))
	if expect_finish:
		check(r.distance>=length-.02 and r.speed==0 and tb.cleared==2 and g.round_left>0,label+" reaches 350 m and halts before deadline")
		check(absf(g.round_left-(960.-elapsed))<.02,label+" earns exactly six additional minutes")
	else:check(r.distance<length-.02 and g.round_left<=0 and tb.cleared==0,label+" expires without earning a late extension")
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1"
	g.start_host("TB timing",0,100,60,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():if id<0:g._peer_left(id)
	Fixture.build(g);g.match_mode.titanball.advance_time(60.);w=g.match_mode.fortress.walkers;tb=g.match_mode.titanball
	await physics_frame;await physics_frame
	check(g.time_limit==600 and g.round_left==600,"Host request for 60 minutes is clamped to ten in TB")
	g.time_limit=60;check(g.time_limit==600,"Direct timer override is clamped in TB")
	check(Config.parse("set sv_gametype tb\nset timelimit 60").values.timelimit==10,"Dedicated TB configuration fixes starting minutes")
	check(Config.parse("set sv_gametype dm\nset timelimit 25").values.timelimit==25,"Other mode configuration retains its time limit")
	g.match_mode.kind="dm";g.time_limit=1500;g.match_mode.kind="tb"
	check(g.time_limit==600,"Changing mode into TB enforces ten minutes")
	g.match_mode.kind="dm";check(g.time_limit==1500,"Leaving TB restores the other mode's time setting")
	g.match_mode.kind="tb";g.match_mode.reset();g.match_mode.titanball.advance_time(60.)
	var r: Dictionary=w.robots.test
	check(absf(r.path.get_baked_length()-350)<.01,"Baked winding route is 350 metres")
	r.distance=89.99;tb.observe("test",r)
	check(tb.cleared==0 and g.round_left==600,"Nose and centre crossing do not award before rear clearance")
	r.distance=90;tb.observe("test",r)
	check(tb.cleared==1 and g.round_left==780,"Rear clears first checkpoint: exactly three minutes added")
	tb.observe("test",r);r.distance=0;tb.observe("test",r);r.distance=90;tb.observe("test",r)
	check(tb.cleared==1 and g.round_left==780,"Repeated observation and recrossing cannot farm first extension")
	w.reset();r=w.robots.test;r.distance=90;tb.observe("test",r)
	check(tb.cleared==1 and g.round_left==780,"Replacing or resetting robot does not reset checkpoint awards")
	r.distance=240;tb.observe("other",r)
	check(tb.cleared==1,"A second robot cannot award the active route's checkpoint")
	tb.observe("test",r);tb.observe("test",r)
	check(tb.cleared==2 and g.round_left==960 and g.time_limit==600,"Second rear clearance adds three minutes once, base timer stays fixed")
	g._restart_round();g.match_mode.titanball.advance_time(60.)
	check(tb.cleared==0 and tb.progress==0 and g.round_left==600,"Round restart clears awards and returns to ten minutes")
	r=w.robots.test;r.distance=240;g.round_left=0;tb.observe("test",r)
	check(tb.cleared==0 and g.round_left==0,"Expired round cannot be revived by a checkpoint")
	g.round_left=10;g.intermission=1;tb.observe("test",r)
	check(tb.cleared==0 and g.round_left==10,"Intermission cannot award extensions")
	g.intermission=0;g.round_left=.005;g._server_tick(.01)
	check(g.intermission>0 and tb.cleared==0,"Authoritative timer expiration ends TB before any late extension")
	await simulate("continuous piloting",999,0)
	await simulate("30 seconds on / 30 off",30,30)
	await simulate("15 seconds on / 15 off",15,15)
	await simulate("six minutes idle then continuous",999,0,360)
	await simulate("nine minutes idle then continuous",999,0,540,false)
	check(g._rotate_map("qsrc_dm1") and tb.cleared==0 and tb.progress==0 and g.round_left==600 and g.time_limit==600,"Map rotation resets checkpoint awards and the fixed timer")
	FileAccess.open("res://test-results/ba2/gameplay/timing.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":runs},"  "))
	print("BA2_TIMING_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
