extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Arena=preload("res://test-results/remaining-native/arena.gd")
const Fighter=preload("res://test-results/remaining-native/fighter.gd")
const Bots=preload("res://test-results/remaining-native/bots.gd")
const Navigation=preload("res://test-results/remaining-native/bot_ai_navigation.gd")
var game
func _initialize() -> void:run.call_deferred()
func stats(rows: Array) -> Dictionary:
	rows.sort();return {"mean_ms":rows.reduce(func(a,b):return a+b,0.)/rows.size(),"median_ms":rows[rows.size()/2],"p95_ms":rows[ceili(rows.size()*.95)-1],"max_ms":rows.back()}
func clear_scopes() -> void:
	for script in [Arena,Fighter,Bots,Navigation]:script.remaining_audit.clear()
func scopes() -> Dictionary:
	return {"arena":Arena.remaining_audit.duplicate(true),"fighter":Fighter.remaining_audit.duplicate(true),"bots":Bots.remaining_audit.duplicate(true),"navigation":Navigation.remaining_audit.duplicate(true)}
func run() -> void:
	seed(20260929)
	game=load("res://deathmatch/arena.tscn").instantiate()
	game.match_mode.fortress.free();game.set_script(Arena)
	if OS.get_cmdline_user_args().has("--reference"):
		game.match_mode.fortress.free();game.set_script(preload("res://deathmatch/arena.gd"))
	root.add_child(game);game.selected_map="qsrc_dm1"
	game.start_host("Remaining native study",0,100000,60,true,"dm","doom")
	if not game.active:push_error("FAIL host start");quit(1);return
	game.set_physics_process(false);game.set_process(false);game.dedicated=true
	game.players[1].spectator=true;game._spawn(1)
	game.max_clients=32;game.bot_population.count_target=16
	for id in range(-4,-17,-1):game._add_player(id,"Study bot "+str(-id))
	var deadline:=Time.get_ticks_msec()+30000
	while not game.bots.ready_to_walk or not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("FAIL navigation timeout");quit(1);return
		await physics_frame
	for i in 120:game.bots.navigation.update_jump_links();await physics_frame
	seed(20260929)
	var timings: Array=[]
	for tick in 720:
		await physics_frame
		if tick==120:clear_scopes()
		game.clock+=1./60
		var start:=Time.get_ticks_usec();game._server_tick(1./60);game._record_history()
		if tick>=120:timings.append((Time.get_ticks_usec()-start)/1000.)
	var report:={"map":game.current_map,"bots":game.players.size()-1,"ticks":600,"tick":stats(timings),"scopes_us_and_calls":scopes(),"pickups":game.pickups.size()}
	# Separate controlled firing workload: 16 live targets in an open test area.
	Fixture.setup(game)
	game.history.clear()
	for id in game.players:
		if id==1:continue
		game.players[id].dead=false;game.players[id].spectator=false
		var a:float=TAU*(-id-1)/16.
		game.fighters[id].position=Fixture.point(cos(a)*7,sin(a)*7)
	for tick in 20:
		game.clock+=1./60
		for id in game.players:
			if id<0:game.fighters[id].position.x+=.01
		game._record_history()
	await physics_frame
	var trace_reports: Array=[]
	for variant in ["native_current","gd_current","gd_rewind_100ms"]:
		var samples: Array=[];clear_scopes()
		var hits:=0
		for batch in 70:
			var start:=Time.get_ticks_usec()
			for shot in 8:
				var from:Vector3=game.fighters[-1].position+Vector3.UP
				var to:Vector3=game.fighters[-(2+(shot+batch)%15)].position+Vector3.UP
				var result:Dictionary=game._trace(from,to,-1) if variant=="native_current" else game._trace_reference(from,to,-1,.1 if variant=="gd_rewind_100ms" else 0.)
				if result.id!=0:hits+=1
			if batch>=10:samples.append((Time.get_ticks_usec()-start)/1000.)
			elif batch==9:clear_scopes()
		trace_reports.append({"path":variant,"eight_rays":stats(samples),"target_hits_including_warmup":hits,"scopes_us_and_calls":scopes()})
	print("REMAINING_RESULT ",JSON.stringify({"engine":Engine.get_version_info().string,"bot_match":report,"hitscan":trace_reports,"scope":"16 active bots and spectator, qsrc_dm1 DM/Doom, 120 warmup + 600 measured ticks after navigation setup. Server tick includes native projectiles, movement, AI, pickups and history; excludes snapshot packing/transport and the engine physics step. Nested timer scopes include instrument overhead; call totals in microseconds. Controlled hitscan fixture uses eight rays per batch with 16 current or historical targets; no damage/ammo."}))
	game.disconnect_game();game.free();await process_frame;quit()
