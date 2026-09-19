extends SceneTree
var game
class MeasuredBots extends "res://deathmatch/bots.gd":
	var bot_ms:=0.0
	var plan_ms:=0.0
	var tick_count:=0
	var plan_count:=0
	func tick(delta: float) -> void:
		var began:=Time.get_ticks_usec();super.tick(delta);bot_ms+=(Time.get_ticks_usec()-began)/1000.0;tick_count+=1
	func plan(id: int,brain: Dictionary) -> void:
		var began:=Time.get_ticks_usec();super.plan(id,brain);plan_ms+=(Time.get_ticks_usec()-began)/1000.0;plan_count+=1
func _initialize():run.call_deferred()
func run() -> void:
	Engine.max_fps=60
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.dedicated=true;game.max_clients=64;game.bot_population.target=64
	game.selected_map=game.match_mode.conquest.MAP_ID;game.start_host("CQ soak",0,100,30,true)
	if not game.active or game.players.size()!=64:push_error("CQ soak startup failed");quit(1);return
	game.bots.free();game.bots=MeasuredBots.new();game.add_child(game.bots);game.bots.setup(game)
	var deadline:=Time.get_ticks_msec()+60000
	while not game.bots.navigation.ready() and Time.get_ticks_msec()<deadline:await process_frame
	if not game.bots.navigation.ready():push_error("CQ navigation not ready");quit(1);return
	var initial: Dictionary={}
	for id in game.fighters:initial[id]=game.fighters[id].position
	game.bots.bot_ms=0;game.bots.plan_ms=0;game.bots.tick_count=0;game.bots.plan_count=0
	var start:=Time.get_ticks_msec();var clock: float=game.clock;var frames: Array=[]
	while Time.get_ticks_msec()-start<20000:
		await process_frame
		frames.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	var moved:=0;var shots:=0;var kills:=0
	for id in game.players:
		if game.fighters[id].position.distance_to(initial.get(id,game.fighters[id].position))>2:moved+=1
		shots+=game.players[id].shots;kills+=game.players[id].kills
	frames.sort()
	var result: Dictionary={"population":game.players.size(),"moved":moved,"shots":shots,"kills":kills,"sim_seconds":game.clock-clock,"wall_seconds":(Time.get_ticks_msec()-start)/1000.0,"physics_p95_ms":frames[int(frames.size()*.95)],"owners":game.match_mode.conquest.rules.owners,"bot_tick_mean_ms":game.bots.bot_ms/maxi(1,game.bots.tick_count),"bot_plan_total_ms":game.bots.plan_ms,"bot_plan_count":game.bots.plan_count,"backend":"single_authority","failures":[]}
	if result.population!=64 or moved<48:result.failures.append("population or movement check failed")
	DirAccess.make_dir_recursive_absolute("res://test-results/conquest")
	FileAccess.open("res://test-results/conquest/soak.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CQ_SOAK_RESULT ",JSON.stringify(result))
	game.disconnect_game();game.queue_free();await process_frame;quit(0 if result.failures.is_empty() else 1)
