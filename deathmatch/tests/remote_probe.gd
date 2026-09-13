extends SceneTree
var game
var positions: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var tag:=args[args.find("--probe")+1]
	var host:=args[args.find("--host")+1]
	var port:=int(args[args.find("--port")+1])
	var stop_path:=args[args.find("--stop-file")+1]
	game=load(args[args.find("--probe-scene")+1]).instantiate()
	game.probe_number=int(tag);game.probe_moving=not "--spectator" in args
	root.add_child(game)
	game.menu_open=false
	game.start_join("RemoteTest "+tag,host,port,"--spectator" in args)
	var deadline:=Time.get_ticks_msec()+900000
	var next:=0;var first:=0;var last_map:=""
	var admitted:=false
	while Time.get_ticks_msec()<deadline:
		if game.active:
			admitted=true
			if first==0:first=Time.get_ticks_msec()
			if game.current_map!=last_map:positions.clear();last_map=game.current_map
		if Time.get_ticks_msec()>=next:
			var mine: Dictionary=game.local_state()
			var fighter=game.fighters.get(game.multiplayer.get_unique_id())
			var pos: Vector3=fighter.position if fighter else Vector3.ZERO
			positions.append(pos)
			var distance:=0.0
			for i in range(1,positions.size()):distance+=positions[i].distance_to(positions[i-1])
			print("REMOTE_PROBE ",JSON.stringify({"tag":tag,"active":game.active,"count":game.players.size(),"spectator":mine.get("spectator",false),"map":game.current_map,"mode":game.match_mode.kind,"epoch":game.map_epoch,"hp":mine.get("hp",0),"deaths":mine.get("deaths",0),"ping":mine.get("ping",0),"position":str(pos),"travel":distance,"loading":game.loading.snapshot(),"event":game.last_event,"models":game.avatars.library.entries.size(),"join_ms":first,"clock":game.clock}))
			next=Time.get_ticks_msec()+2000
		if FileAccess.file_exists(stop_path):break
		if "--reject" in args and not game.active and (game.last_event.to_lower().contains("server full") or game.last_event.contains("Connection failed")):
			print("REMOTE_REJECTED ",game.last_event);game.disconnect_game();game.queue_free();await process_frame;quit(0);return
		await create_timer(.05).timeout
	game.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("REMOTE_EXIT admitted=",admitted)
	quit(0 if admitted and not "--reject" in args else 1)
