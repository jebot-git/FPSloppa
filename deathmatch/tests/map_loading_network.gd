extends SceneTree
## Eight ENet clients; the eighth deliberately withholds asset readiness.
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var failures: Array=[]
var role: String
class Probe extends Node:
	var phase:=""
	var armed: Dictionary={}
	var reports: Dictionary={}
	@rpc("authority","call_local","reliable")
	func stage(value: String) -> void:phase=value
	@rpc("any_peer","call_remote","reliable")
	func arm() -> void:
		if multiplayer.is_server():armed[multiplayer.get_remote_sender_id()]=true
	@rpc("any_peer","call_remote","reliable")
	func report(value: String,data: Dictionary) -> void:
		if multiplayer.is_server():reports[value]=data
var probe: Probe
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(predicate: Callable,seconds: float=20) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	probe=Probe.new();probe.name="LoadingProbe";root.add_child(probe)
	Fixture.setup(game)
	if role=="server":await server_run()
	else:await client_run()
	print("MAP_LOADING_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();await create_timer(.1).timeout;game.free();quit(0 if failures.is_empty() else 1)
func server_run() -> void:
	game.dedicated=true;game.selected_map="qsrc_dm1"
	game.lobby.enabled=true;game.lobby.seconds=45
	game.votes.allowed_modes=["dm","ig"];game.mode_maplists={"dm":["qsrc_dm1"],"ig":["qsrc_dm6"]}
	game.map_rotation=["qsrc_dm1"]
	game.start_host("Loading regression",28976,100,30,false)
	check(await wait_for(func():return game.players.size()==8 and probe.armed.size()==8,35),"Eight clients admitted and delayed loader armed")
	if game.players.size()!=8 or probe.armed.size()!=8:return
	var mover: int=game.players.keys().filter(func(id):return game.players[id].name=="fast0")[0]
	var slow: int=game.players.keys().filter(func(id):return game.players[id].name=="slow")[0]
	game._end_round()
	probe.stage.rpc("intermission")
	check(await wait_for(func():return game.lobby.selections.size()==8 and probe.reports.size()==8,6),"All eight clients receive and vote on the intermission grid")
	check(probe.reports.values().all(func(report):return report.get("options",[])==game.lobby.offered),"Every client sees the same randomized combinations")
	var intermission_options: Array=game.lobby.offered.duplicate(true)
	game.lobby.begin()
	check(await wait_for(func():return game.players.size()==7 and game.loading.pending.has(slow)),"Seven enter lobby while eighth withholds readiness")
	if not game.players.has(mover):return
	check(game.lobby.offered==intermission_options and game.lobby.selections.size()==8,"Choices and all votes survive the lobby transition, including delayed peer")
	await movement(mover,"lobby",Vector3(0,.05,4))
	check(not game.map_loading and game.round_left<45,"Lobby countdown runs despite delayed peer")
	probe.stage.rpc("vote")
	check(await wait_for(func():return probe.reports.keys().filter(func(value):return value.begins_with("vote_")).size()==7,5),"Ready clients can vote directly while eighth peer loads")
	# A stalled peer must not hold the lobby at zero or prevent the next offer.
	game.lobby.until=game.clock
	check(await wait_for(func():return game.current_map=="qsrc_dm6" and game.players.size()==7 and game.loading.pending.has(slow)),"Lobby expires and seven players enter voted match")
	if game.current_map!="qsrc_dm6" or not game.players.has(mover):return
	await movement(mover,"match",Fixture.point(0,6))
	check(not game.map_loading and game.round_left<game.time_limit,"New match clock runs despite delayed peer")
	probe.stage.rpc("release")
	check(await wait_for(func():return game.players.size()==8 and not game.pending_names.has(slow)),"Delayed player completes current epoch admission")
	probe.stage.rpc("done")
	await create_timer(.5).timeout
func movement(id: int,label: String,point: Vector3) -> void:
	game.fighters[id].position=point;game.fighters[id].velocity=Vector3.ZERO
	game.players[id].serial+=1
	await create_timer(.3).timeout
	var start: Vector3=game.fighters[id].position
	probe.stage.rpc("move_"+label)
	check(await wait_for(func():return probe.reports.has(label),5),label+" client completes predicted movement")
	check(game.fighters[id].position.distance_to(start)>2,label+" movement reaches authority while eighth peer loads")
	var report: Dictionary=probe.reports.get(label,{})
	print("PREDICTION ",label," ",JSON.stringify(report))
	check(report.get("distance",0)>2 and report.get("resets",999)==0 and report.get("max_error",999)<1.5,label+" prediction has no repeated spawn resets or large corrections")
func key(pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_W;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func client_run() -> void:
	game.start_join(role,"127.0.0.1",28976)
	check(await wait_for(func():return game.active and not game.local_state().is_empty(),35),"Client initially admitted")
	if not game.active:return
	if role=="slow":game.loading.set_process(false)
	probe.arm.rpc_id(1)
	var handled:=""
	var deadline:=Time.get_ticks_msec()+65000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		var stage:=probe.phase
		if stage=="done":break
		if stage==handled:continue
		if stage=="release":game.loading.set_process(true)
		elif stage=="intermission":
			check(await wait_for(func():return game.lobby.view.get("stage","")=="intermission" and not game.lobby.view.get("options",[]).is_empty(),5),"Intermission grid arrives before voting")
			game.lobby.select_option(0)
			probe.report.rpc_id(1,"ballot_"+role,{"options":game.lobby.view.get("options",[])})
		elif stage=="vote" and role.begins_with("fast"):
			# All ready peers select the same complete match option.
			game.lobby.submit("ig","qsrc_dm6")
			probe.report.rpc_id(1,"vote_"+role,{})
		elif stage.begins_with("move_") and role=="fast0":
			var actor=game.fighters[game.multiplayer.get_unique_id()]
			var start:Vector3=actor.position
			actor.prediction.stats={"corrections":0,"resets":0,"max_error":0.0}
			game.menu_open=false;game.local_yaw=0;game.bindings.keys.forward=KEY_W
			key(true);await create_timer(.65).timeout;key(false)
			await create_timer(.25).timeout
			var report:Dictionary=actor.prediction.stats.duplicate();report.distance=actor.position.distance_to(start)
			probe.report.rpc_id(1,stage.trim_prefix("move_"),report)
		handled=stage
	key(false)
	check(probe.phase=="done","Server completes delayed-join transitions")
	check(game.active and game.current_map=="qsrc_dm6","Client finishes in voted map")
