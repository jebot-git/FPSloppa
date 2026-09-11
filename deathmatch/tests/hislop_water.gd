extends SceneTree
var game
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func q(x: float,y: float,z: float) -> Vector3:return Vector3(-y,z,-x)/32.0+Vector3.UP*.05
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.selected_map="as_hislop";game.start_host("Sludge escape",0,100,60,true,"as")
	game.bots.free();game.bots=null
	for id in game.players:game.players[id].spectator=true
	var s: Dictionary=game.players[1];s.spectator=false;s.dead=false
	var actor=game.fighters[1];var runtime=game.get_node("Map/MapRuntime");runtime.set_physics_process(false)
	await physics_frame;await physics_frame
	for hz in [60,72,90,120]:
		Engine.physics_ticks_per_second=hz
		actor.position=q(0,96,96);actor.velocity=Vector3.ZERO;actor.reset_view();actor.jump_held=false
		var peak:=0.0;var boosts:=0;var previous_boost:=0.0;var escaped:=false
		for frame in hz*4:
			await physics_frame
			game.clock+=1.0/hz;runtime.hurt_until[1]=game.clock+100
			runtime._physics_process(1.0/hz)
			actor.simulate(Vector2(-1,0),0,true,1.0/hz,true)
			peak=maxf(peak,actor.position.y)
			if actor.water_boost>previous_boost:boosts+=1
			previous_boost=actor.water_boost
			if actor.position.x< -5.0:escaped=true;break
		print("SLUDGE_ESCAPE hz=",hz," position=",actor.position," peak=",peak," boosts=",boosts)
		check(escaped and boosts==1,"Held swim-up exits actual HiSlop sludge rim with one boost at %d Hz"%hz)
	print("HISLOP_WATER_RESULT ",JSON.stringify(failures));game.free();quit(0 if failures.is_empty() else 1)
