extends SceneTree
## Deliberately sustained, synthetic ST projectile workload; not a match replay.
const Study=preload("res://tools/native_study/study_scopes.gd")
var game
func _initialize():run.call_deferred()
func stats(rows:Array) -> Dictionary:
	rows.sort();return {"mean_ms":rows.reduce(func(a,b):return a+b,0.)/rows.size(),"p95_ms":rows[ceili(rows.size()*.95)-1],"p99_ms":rows[ceili(rows.size()*.99)-1],"max_ms":rows.back()}
func run() -> void:
	seed(9400)
	game=load("res://test-results/native-current-study/code/deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.dedicated=true;game.bind_address="127.0.0.1";game.max_clients=32;game.bot_population.count_target=16
	game.match_mode.configure({"sv_gametype":"st","capturelimit":100});game.selected_map="ctf_stonehenge";game.lobby.enabled=false
	game.start_host("ST projectile study",0,100,60,false)
	if not game.active:push_error("FAIL host start");quit(1);return
	game.set_process(false);game.set_physics_process(false);game.voice_enabled=false;game.intermission=0
	for frame in 3:await physics_frame
	var index:=0
	for id in game.players:
		game.match_mode.tribes.apply_equipment(id,"heavy",[1,2,3],"energy")
		var s:Dictionary=game.players[id];s.dead=false;s.spectator=false;s.cooldown=0;s.weapon=[1,2,3][index%3];s.yaw=0;s.pitch=0;s.invulnerable=0
		# Parallel lanes clear of the map. Fire at real weapon cadence; replenish
		# ammo/energy explicitly so inventory and bot decisions cannot starve it.
		game.fighters[id].position=Vector3(1000+index*8,100,1000);game.fighters[id].velocity=Vector3.ZERO
		index+=1
	var times:Array=[];var live:Array=[];var shots:=0;var peak:=0
	for tick in 300+600:
		await physics_frame
		if tick==300:Study.reset()
		game.clock+=1./60
		for id in game.players:
			var s:Dictionary=game.players[id];s.cooldown=maxf(0,s.cooldown-1./60);s.tribes_ammo[s.weapon]=100;game.fighters[id].tribes_state.energy=60
			game.match_mode.tribes.combat.spins[id]=1.
			if game.match_mode.tribes.combat.fire(id):shots+=1
		var started:=Time.get_ticks_usec();game._update_projectiles(1./60,{})
		if tick>=300:times.append((Time.get_ticks_usec()-started)/1000.);live.append(game.projectiles.size())
		peak=maxi(peak,game.projectiles.size())
	if shots<100 or peak<30:push_error("FAIL insufficient projectile workload");quit(1);return
	var state:Array=[]
	for id in game.projectiles:
		var p:Dictionary=game.projectiles[id];state.append([id,p.weapon,p.position,p.velocity,p.life])
	print("CURRENT_STUDY_RESULT ",JSON.stringify({"kind":"st_sustained_projectiles","native":game.native_projectiles!=null,"shooters":game.players.size(),"warmup":300,"ticks":600,"shots":shots,"peak_projectiles":peak,"mean_projectiles":live.reduce(func(a,b):return a+b,0.)/live.size(),"update":stats(times),"state_hash":hash(state),"scopes_us_calls_max_self":Study.rows.duplicate(true)}))
	game.disconnect_game();game.free();await process_frame;quit()
