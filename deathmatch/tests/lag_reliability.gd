extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Lag=preload("res://deathmatch/lag_compensation.gd")
var failures: Array=[]
var game
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.start_host("Lag",0,100,60,true);game.bots.free();game.bots=null;game.set_physics_process(false)
	for id in game.players:
		game.players[id].invulnerable=0;game.players[id].hp=10000;game.players[id].armor=0
		game.fighters[id].position=Fixture.point(15,15)
	var baseline_misses:=0
	for ping in [20,40,60,80,100]:
		var hits:=0;var max_error:=0.0
		for trial in 40:
			game.history.clear();game.clock=10.0+float(trial)/300.0
			var age:=float(ping)/1000.0+.065+float(trial%5)*.003
			var viewed: float=game.clock-age
			for i in 25:
				var at: float=game.clock-.4+float(i)/60.0
				game.history.append({"time":at,"positions":{-1:{"position":Fixture.point((at-viewed)*9.4,-8),"serial":game.players[-1].serial}}})
			game.fighters[-1].position=Fixture.point(age*9.4,-8)
			var delay:=Lag.delay(game.clock,ping,viewed,game.clock)
			var start:=Fixture.point()+Vector3.UP
			if game._trace(start,start+Vector3.FORWARD*20,1,delay).id==-1:hits+=1
			var rewound: Dictionary=game._rewound_positions(delay)
			max_error=maxf(max_error,absf(rewound[-1].x-Fixture.ORIGIN.x))
			# Old code used the last 50 ms sample preceding half-RTT.
			var old_time:=floorf((game.clock-ping/2000.0)*20)/20
			if absf((old_time-viewed)*9.4)>.4:baseline_misses+=1
		check(hits==40 and max_error<.005,"%d ms RTT: 40/40 moving hits, interpolation error %.4f m"%[ping,max_error])
	check(baseline_misses>0,"Regression reproduces old half-RTT/snapshot quantization misses (%d/200)"%baseline_misses)
	game.players[-1].serial+=1
	check(not game._rewound_positions(.15).has(-1),"Historical shot cannot hit a previous spawn")
	check(Lag.delay(10,100,0,10)<=.22 and Lag.delay(10,100,NAN,10)<=.22 and Lag.delay(10,100,11,10)<=.22,"Old, future and nonfinite client times remain bounded")
	game.players[-1].spectator=true;game.fighters[-1].position=Fixture.point(0,-3)
	check(game._trace(Fixture.point()+Vector3.UP,Fixture.point(0,-6)+Vector3.UP,1).id==0,"Spectator capsules do not absorb hits")
	game.players[-1].spectator=false
	game.fighters[-1].position=Fixture.point(0,-3)
	var wall=Fixture.box(game,Fixture.point(0,-2)+Vector3.UP,Vector3(4,2,.05))
	await physics_frame;await physics_frame
	check(game._trace(Fixture.point()+Vector3.UP,Fixture.point(0,-6)+Vector3.UP,1,.1).id==0,"Lag compensation respects current wall cover")
	wall.free()
	game.free();await process_frame
	print("LAG_RELIABILITY_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
