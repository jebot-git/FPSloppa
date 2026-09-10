extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args();var count:=int(args[0]) if not args.is_empty() else 16
	var duration:=720;var duration_arg:=args.find("--ticks")
	if duration_arg>=0:duration=maxi(121,int(args[duration_arg+1]))
	g=load("res://deathmatch/arena.tscn").instantiate();
	if args.has("--profile"):
		# The original script constructs this Node before _ready takes ownership.
		g.match_mode.fortress.free()
		g.set_script(preload("res://deathmatch/tests/profiled_arena.gd"))
	root.add_child(g);Fixture.setup(g)
	g.start_host("CPU audit",0,100,60,true)
	if g.bots:g.bots.free();g.bots=null
	g.set_physics_process(false);g.set_process(false)
	for id in g.players.keys():g.fighters[id].free()
	g.players.clear();g.fighters.clear()
	for id in range(1,count+1):
		g._add_player(id,"Load actor");g.players[id].hp=1000000;g.players[id].owned=[2,6,7];g.players[id].weapon=7;g.players[id].ammo=[200,50,50,30000];g.players[id].invulnerable=0
		var a:float=TAU*(id-1)/count;g.fighters[id].position=Fixture.point(cos(a)*7,sin(a)*7);g.players[id].yaw=-a-PI/2
	var times: Array=[];var snapshots: Array=[];var maximum_projectiles:=0
	for tick in duration:
		await physics_frame
		g.clock+=1.0/60
		for id in g.players:
			g.players[id].last_input=g.clock;g.players[id].fire=true;g.players[id].hp=1000000;g.players[id].dead=false
		var before:=Time.get_ticks_usec();g._server_tick(1.0/60);g._record_history()
		if tick>=120:times.append((Time.get_ticks_usec()-before)/1000.0)
		maximum_projectiles=maxi(maximum_projectiles,g.projectiles.size())
		if tick%3==0:
			before=Time.get_ticks_usec();g._send_snapshot()
			if tick>=120:snapshots.append((Time.get_ticks_usec()-before)/1000.0)
		if args.has("--memory") and tick%300==0:
			print("SERVER_MEMORY_SAMPLE ",JSON.stringify({"tick":tick,"projectiles":g.projectiles.size(),"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	times.sort();snapshots.sort()
	print("SERVER_LOAD_RESULT ",JSON.stringify({"players":count,"version":ProjectSettings.get_setting("application/config/version"),"ticks":times.size(),"tick_p50_ms":times[times.size()/2],"tick_p95_ms":times[int(times.size()*.95)],"tick_max_ms":times.back(),"snapshot_p95_ms":snapshots[int(snapshots.size()*.95)],"max_projectiles":maximum_projectiles,"history_entries":g.history.size()}))
	if args.has("--profile"):
		print("SERVER_PROFILE_RESULT ",JSON.stringify({"projectiles_ms_per_tick":g.audit_projectile_us/1000.0/g.audit_ticks,"history_ms_per_tick":g.audit_history_us/1000.0/g.audit_ticks,"collect_ms_per_tick":g.audit_collect_us/1000.0/g.audit_ticks,"melee_ms_per_tick":g.audit_melee_us/1000.0/g.audit_ticks}))
	g.disconnect_game();g.free();await process_frame
	if args.has("--memory"):
		for frame in 60:await process_frame
		print("SERVER_MEMORY_FINAL ",JSON.stringify({"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit()
