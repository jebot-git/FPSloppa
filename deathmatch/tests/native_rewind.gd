extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Lag=preload("res://deathmatch/lag_compensation.gd")
var checks:=0
var failures: Array=[]
var rng:=RandomNumberGenerator.new()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<20:failures.append(label);push_error(label)
func vector(scale: float=1.) -> Vector3:return Vector3(rng.randf_range(-scale,scale),rng.randf_range(-scale,scale),rng.randf_range(-scale,scale))
func same(a: Dictionary,b: Dictionary,label: String) -> void:
	check(a.keys()==b.keys(),label+" fields")
	check(a.id==b.id and a.hit==b.hit and a.headshot==b.headshot and a.position.distance_to(b.position)<.0001,label+" result")
	for key in ["surface_normal","impact_normal"]:
		if a.has(key):check(a[key].distance_to(b.get(key,Vector3.INF))<.0001,label+" normal")
func summary(rows: Array) -> Dictionary:
	rows.sort();return {"mean_ms":rows.reduce(func(a,b):return a+b,0.)/rows.size(),"median_ms":rows[rows.size()/2],"p95_ms":rows[ceili(rows.size()*.95)-1]}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	rng.seed=20260929
	for trial in 1000:
		var current: Dictionary={};var history: Array=[]
		for id in 16:current[id]={"serial":3,"position":vector(5),"height":rng.randf_range(.65,1.65),"yaw":rng.randf_range(-PI,PI)}
		for tick in 20:
			var rows: Dictionary={}
			for id in current:
				if id==trial%16 and tick%3==0:continue
				rows[id]={"serial":2 if (id+tick)%7==0 else 3,"position":current[id].position+vector(.5 if id%4 else 5)}
				if id%3:rows[id].height=rng.randf_range(.65,1.65);rows[id].yaw=rng.randf_range(-PI,PI)
			history.append({"time":10.-(20-tick)/60.,"positions":rows})
		var rewind:=rng.randf_range(-.01,.5)
		var batch:=Lag.sample(history,10.,rewind,current)
		var positions:=Lag.positions(history,10.,rewind,current)
		var heights:=Lag.positions(history,10.,rewind,current,true)
		var yaws:=Lag.positions(history,10.,rewind,current,false,true)
		check(batch.keys()==positions.keys(),"Sample membership "+str(trial))
		for id in batch:check(batch[id].serial==current[id].serial and batch[id].position.is_equal_approx(positions[id]) and is_equal_approx(batch[id].height,heights[id]) and is_equal_approx(batch[id].yaw,yaws[id]),"Sample components "+str(trial))
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.start_host("Native rewind parity",0,100,60,true);game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
	check(game.native_projectiles!=null,"Native tracing available")
	for id in range(-4,-16,-1):game._add_player(id,"Rewind target")
	for id in game.players:
		game.players[id].invulnerable=0;game.players[id].hp=10000
		var angle: float=TAU*abs(id)/16.
		game.fighters[id].position=Fixture.point(cos(angle)*7,sin(angle)*7)
	game.history.clear();game.clock=10.
	for tick in 20:
		game.clock+=1./60
		for id in game.players:game.fighters[id].position.x+=.01
		game._record_history()
	await physics_frame
	for trial in 1500:
		var start:=Fixture.point()+vector(9)+Vector3.UP;var end:=Fixture.point()+vector(9)+Vector3.UP
		var rewind:=rng.randf_range(.001,.4);var radius: float=[0.,.14,.3][trial%3]
		var context: Dictionary=game._rewind_context(rewind)
		var a: Dictionary=game._trace_reference(start,end,1,rewind,radius)
		same(a,game._trace(start,end,1,rewind,radius,{},null,context),"Native historical "+str(trial))
		same(a,game._trace_reference(start,end,1,rewind,radius,{},null,context),"Fallback historical "+str(trial))
	var context: Dictionary=game._rewind_context(.1)
	var start: Vector3=Fixture.point()+Vector3.UP
	for mutation in ["dead","spectator","new_life","new_player"]:
		if mutation=="dead":game.players[-1].dead=true
		elif mutation=="spectator":game.players[-2].spectator=true
		elif mutation=="new_life":game.players[-3].serial+=1;game.fighters[-3].position=Fixture.point(0,-3)
		else:game._add_player(-16,"New life");game.fighters[-16].position=Fixture.point(0,-2)
		for id in game.players:
			var end: Vector3=game.fighters[id].position+Vector3.UP
			same(game._trace_reference(start,end,1,.1),game._trace(start,end,1,.1,0.,{},null,context),"Live eligibility "+mutation)
	# Measurements include creation of one context per eight-ray burst.
	var reports: Array=[]
	for mode in ["reference","batched_gd","native","native","batched_gd","reference"]:
		var times: Array=[]
		for batch in 140:
			var before:=Time.get_ticks_usec()
			var history_context: Dictionary={} if mode=="reference" else game._rewind_context(.1)
			for pellet in 8:
				var end: Vector3=game.fighters[-(4+(batch+pellet)%10)].position+Vector3.UP
				if mode=="reference":game._trace_reference(start,end,1,.1)
				elif mode=="batched_gd":game._trace_reference(start,end,1,.1,0.,{},null,history_context)
				else:game._trace(start,end,1,.1,0.,{},null,history_context)
			if batch>=20:times.append((Time.get_ticks_usec()-before)/1000.)
		reports.append({"path":mode,"eight_rays":summary(times)})
	game.disconnect_game();game.free();await process_frame
	print("NATIVE_REWIND_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"benchmarks":reports}));quit(0 if failures.is_empty() else 1)
