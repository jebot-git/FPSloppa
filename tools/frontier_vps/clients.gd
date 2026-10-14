extends Node
## Synthetic cached-asset ENet clients: real admission, input and snapshot decoding, no world rendering.
var clients:Array=[]
var sequence:=0
var started:=0
var connected_at:=0
var count:=32
var seconds:=120
var address:="87.106.27.237"
var port:=7777
var accumulator:=0.0
var no_fire:=false
var fire_delay:=0.0
var next_transport:=0
var last_transport:Array=[]
func value(flag:String,fallback:String) -> String:
	var args:=OS.get_cmdline_user_args();var i:=args.find(flag)
	return args[i+1] if i>=0 and i+1<args.size() else fallback
func _ready() -> void:run.call_deferred()
func run() -> void:
	Engine.max_fps=60
	no_fire=OS.get_cmdline_user_args().has("--no-fire");fire_delay=float(value("--fire-delay","0"))
	count=int(value("--players","32"));seconds=int(value("--seconds","120"));address=value("--address",address);port=int(value("--port","7777"));started=Time.get_ticks_msec()
	for i in count:
		var branch:=Node.new();branch.name="LoadClient%d"%i;get_tree().root.add_child(branch)
		var api:=SceneMultiplayer.new();get_tree().set_multiplayer(api,branch.get_path())
		var arena=load("res://tools/frontier_vps/clients/arena.gd").new();arena.name="VoxelBattle";branch.add_child(arena)
		for child_name in ["MapNetwork","Loading","AvatarNetwork","VoiceChat","Announcer","PlayerVotes"]:
			var child=load("res://tools/frontier_vps/clients/"+child_name+".gd").new();child.name=child_name;arena.add_child(child)
		api.server_disconnected.connect(func():print("LOAD_CLIENT_TRANSPORT_LOST ",JSON.stringify({"uptime_ms":Time.get_ticks_msec()-started,"last":last_transport})))
		api.connection_failed.connect(func():print("LOAD_CLIENT_TRANSPORT_FAILED uptime_ms=",Time.get_ticks_msec()-started))
		api.connected_to_server.connect(func():arena._hello.rpc_id(1,"Load "+value("--client-label",str(i)),preload("res://tools/voxel_battle/class_arena.gd").CLASS_PROTOCOL,false))
		var peer:=ENetMultiplayerPeer.new();var err:=peer.create_client(address,port);api.multiplayer_peer=peer
		if err!=OK:push_error("ENet client creation failed");get_tree().quit(1);return
		clients.append(arena)
func _process(delta:float) -> void:
	var admitted:=0;var received:=0;var packets:=0;var errors:=0
	for c in clients:
		if c.ready_player and c.multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:admitted+=1
		if not c.rejected.is_empty():errors+=1
		received+=c.bytes_received;packets+=c.packets
	var now:=Time.get_ticks_msec()
	if now>=next_transport:
		last_transport=[]
		for c in clients:
			var peer=c.multiplayer.multiplayer_peer
			if peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
				var packet=peer.get_peer(1)
				last_transport.append({"peer":c.multiplayer.get_unique_id(),"state":packet.get_state(),"rtt_ms":packet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"loss":packet.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS),"throttle":packet.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)})
		next_transport=now+1000
	if connected_at==0 and admitted==count:
		connected_at=now;print("LOAD_CLIENTS_READY players=",count," join_seconds=",(now-started)/1000.0)
	if connected_at==0 and now-started>90000:
		print("LOAD_CLIENTS_TIMEOUT ",admitted,"/",count," rejected=",errors);get_tree().quit(1);return
	accumulator+=delta
	if accumulator>=1.0/30:
		accumulator=fmod(accumulator,1.0/30);sequence+=1
		for i in clients.size():
			var c=clients[i]
			if not c.ready_player or c.multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:continue
			var pose:Dictionary=preload("res://deathmatch/vr/poses.gd").neutral();pose.head.origin.y+=sin(sequence*.01+i)*.03
			var cmd:Dictionary={"seq":sequence,"map_epoch":c.epoch,"input_life":c.life,"move":Vector2(sin(sequence*.01+i)*.4,cos(sequence*.008+i)*.4),"yaw":i*.8+sin(sequence*.005)*.3,"pitch":.05,"fire":not no_fire and connected_at>0 and now-connected_at>=fire_delay*1000,"weapon":0,"slow":false,"respawn":true,"reload":sequence%90==0,"xr":pose,"room":Vector3.ZERO}
			c._input_packet.rpc_id(1,preload("res://deathmatch/network/codec.gd").pack(cmd))
	if connected_at>0 and now-connected_at>=seconds*1000:
		print("LOAD_CLIENTS_RESULT ",JSON.stringify({"players":count,"admitted":admitted,"seconds":(now-connected_at)/1000.0,"input_batches":sequence,"snapshot_bytes_received":received,"snapshot_packets_received":packets,"rejected":errors,"XR":"synthetic tracked head/hands","rendering":false,"assets":"cached-asset barrier acknowledged; no downloads"}))
		for c in clients:c.multiplayer.multiplayer_peer.close()
		get_tree().quit(0 if admitted==count and errors==0 and (packets>count*10 or OS.get_cmdline_user_args().has("--connection-only")) else 1)
