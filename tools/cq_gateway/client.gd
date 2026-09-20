extends SceneTree
var game
var failures: Array=[]
var distances: Array=[]
var pauses: Array=[]
func _initialize():run.call_deferred()
func run() -> void:
	Engine.max_fps=60
	game=load("res://deathmatch/arena.tscn").instantiate();game.set_script(load("res://tools/cq_gateway/driver.gd"));root.add_child(game)
	var args:=OS.get_cmdline_user_args()
	game.start_join("CQ gateway probe",game._arg_value(args,"--host","127.0.0.1"),game._arg_int(args,"--test-port",28987))
	var deadline:=Time.get_ticks_msec()+90000
	while game.cq_client.handoffs<1 and Time.get_ticks_msec()<deadline:await create_timer(.05).timeout
	if game.cq_client.handoffs<1:failures.append("No initial district baseline");finish();return
	var id: int=game.multiplayer.get_unique_id()
	var zone: int=game.cq_client.zone
	var center:=preload("res://deathmatch/conquest/rules.gd").center(zone)
	var path: Array=[center,center+Vector3(131,0,0),center+Vector3(113,0,0)]
	if game.cq_maps.enabled:
		# Follow the authored eastbound street; the old straight line can now
		# pass through buildings. Movement and collision remain fully live.
		var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/CQDistricts/district_%02d/layout.json"%zone))
		path=[center];var eastbound:=false
		for point in layout.streets[0]:
			if int(point[0])==0 and int(point[1])==0:eastbound=true;continue
			if eastbound and point[0]<125:path.append(center+Vector3(point[0],0,point[1]))
		path.append(center+Vector3(131,0,0));path.append(center+Vector3(113,0,0))
	if args.has("--pool-route"):path=[center,center+Vector3(131,0,0),center+Vector3(381,0,0),center+Vector3(369,0,0),center+Vector3(119,0,0)]
	var legs: Array=[]
	for point in path:
		game.target=point;game.driving=true
		var limit:=Time.get_ticks_msec()+40000
		var frozen_at:=0
		while Time.get_ticks_msec()<limit and game.active:
			await create_timer(.05).timeout
			if game.cq_client.frozen and frozen_at==0:frozen_at=Time.get_ticks_msec()
			if not game.cq_client.frozen and frozen_at>0:pauses.append(Time.get_ticks_msec()-frozen_at);frozen_at=0
			var delta: Vector3=game.fighters[id].position-point;delta.y=0
			if delta.length()<1 and not game.cq_client.frozen:break
		game.driving=false
		if not game.active:failures.append("Disconnected during route");break
		var delta: Vector3=game.fighters[id].position-point;delta.y=0;legs.append(delta.length())
		if delta.length()>=1:failures.append("Route leg timed out")
	if not game.active:finish();return
	# Exercise server-authoritative shot/event path after the two handoffs.
	game.trigger=true;await create_timer(1).timeout;game.trigger=false
	await create_timer(.5).timeout
	if game.cq_client.events_received<1:failures.append("No worker audiovisual event received")
	if game.cq_client.handoffs<3:failures.append("Expected initial baseline and two gate handoffs")
	if game.cq_client.zone!=zone:failures.append("Did not return to original district")
	# Inject delayed old-generation payloads at the client receiver; they cannot alter state.
	var before: Vector3=game.fighters[id].position
	var stale: int=game.cq_client.rejected
	game.cq_client.packet(game.map_epoch,game.cq_client.generation-1,PackedByteArray([0]))
	game.cq_client.event(game.map_epoch,game.cq_client.generation-1,"_teleport_fx",[Vector3.ZERO])
	if game.cq_client.rejected!=stale+2 or game.fighters[id].position!=before:failures.append("Stale generation was not rejected")
	var stale_input: Dictionary=game._local_command();stale_input.seq=game.sequence+10000;stale_input.map_epoch=game.map_epoch;stale_input.cq_generation=game.cq_client.generation-1
	game._input_packet.rpc_id(1,game.NetCodec.pack(stale_input))
	if args.has("--respawn"):
		var life: int=game.players[id].serial
		game.request_suicide()
		var expires:=Time.get_ticks_msec()+12000
		while Time.get_ticks_msec()<expires and game.active:
			await create_timer(.05).timeout
			if game.players[id].serial>life and not game.players[id].dead and not game.cq_client.frozen:break
		if game.players[id].serial<=life or game.players[id].dead:failures.append("Master-authorized respawn did not complete")
		if game.cq_client.occupancy.size()!=16 or game.cq_client.occupancy.any(func(n):return n>16):failures.append("Missing or overfilled district capacity")
	print("CQ_ROUTE ",JSON.stringify({"legs":legs,"position":str(game.fighters[id].position),"prediction":game.fighters[id].prediction.stats,"ack":game.fighters[id].prediction.acknowledged,"pauses_ms":pauses,"ammo":game.players[id].ammo,"events":game.cq_client.events_received,"visible":game.cq_client.visible,"roster":game.players.size()}))
	var hold: float=float(game._arg_value(args,"--hold-seconds","0"))
	if hold>0:await create_timer(hold).timeout
	finish()
func finish() -> void:
	var result:={"handoffs":game.cq_client.handoffs,"zone":game.cq_client.zone,"failures":failures,"stale_rejected":game.cq_client.rejected}
	if game.cq_maps.enabled:
		result.map_transitions=game.cq_maps.transitions;result.map_zone=game.cq_maps.zone;result.map_instances=game.get_node("Map").get_children().filter(func(n):return n.name.begins_with("District_")).size()
	print("CQ_GATEWAY_CLIENT ",JSON.stringify(result))
	game.disconnect_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
