extends Node
## ENet facade for the opt-in regional backend. This has its own protocol and
## does not pretend to be the shipping arena RPC tree. All authority stays server-side.
signal response(request_id: int,body: Dictionary)
var backend: Array=[]
var routes: Dictionary={}
var inflight: Dictionary={}
var server:=false
func host(settings: Dictionary) -> Error:
	backend=settings.backend;routes=settings.routes
	# Clients talk only to their gateway; peer relay and roster broadcasts are unused.
	multiplayer.server_relay=false
	var peer:=ENetMultiplayerPeer.new();peer.set_bind_ip(settings.listen[0])
	var error:=peer.create_server(int(settings.listen[1]),192,3)
	if error!=OK:return error
	multiplayer.multiplayer_peer=peer;server=true;return OK
func connect_gateway(address: Array) -> Error:
	if multiplayer.multiplayer_peer:multiplayer.multiplayer_peer.close()
	var peer:=ENetMultiplayerPeer.new()
	var error:=peer.create_client(address[0],int(address[1]),3)
	if error==OK:multiplayer.multiplayer_peer=peer
	return error
func request(request_id: int,body: Dictionary) -> void:
	_request.rpc_id(1,request_id,JSON.stringify(body).to_utf8_buffer())
@rpc("any_peer","call_remote","reliable",0)
func _request(request_id: int,bytes: PackedByteArray) -> void:
	if not server:return
	var sender:=multiplayer.get_remote_sender_id()
	if request_id<0 or bytes.size()>8192 or int(inflight.get(sender,0))>=4:return
	var body=JSON.parse_string(bytes.get_string_from_utf8())
	if not body is Dictionary or body.get("op") not in ["join","resume","status","input","snapshot","transfer","deploy","respawn","leave"]:return
	inflight[sender]=int(inflight.get(sender,0))+1
	var result:=await forward(bytes)
	inflight[sender]=int(inflight.get(sender,1))-1
	if inflight[sender]==0:inflight.erase(sender)
	if sender not in multiplayer.get_peers():return
	# ENet can retire the transport before SceneMultiplayer drops its peer ID.
	var transport: ENetPacketPeer=multiplayer.multiplayer_peer.get_peer(sender)
	if not transport or transport.get_state()!=ENetPacketPeer.STATE_CONNECTED or transport.get_channels()==0:return
	if body.op=="snapshot":_snapshot.rpc_id(sender,request_id,result)
	else:
		# Public reconnection addresses must identify the destination ENet facade.
		var value=JSON.parse_string(result.get_string_from_utf8())
		if value is Dictionary and value.get("result") is Dictionary:
			for field in ["gateway","redirect"]:
				var address=value.result.get(field)
				if address is Array and address.size()==2:
					var key:="%s:%d"%[address[0],int(address[1])]
					if routes.has(key):value.result[field]=routes[key]
			result=JSON.stringify(value).to_utf8_buffer()
		_reply.rpc_id(sender,request_id,result)
func forward(bytes: PackedByteArray) -> PackedByteArray:
	var socket:=StreamPeerTCP.new();socket.connect_to_host(backend[0],int(backend[1]));socket.set_no_delay(true)
	var limit:=Time.get_ticks_msec()+4000
	var output:=bytes.duplicate();output.append(10)
	var input:=PackedByteArray()
	while Time.get_ticks_msec()<limit:
		socket.poll()
		if socket.get_status()==StreamPeerTCP.STATUS_ERROR:break
		if socket.get_status()==StreamPeerTCP.STATUS_CONNECTED:
			if not output.is_empty():
				var result:=socket.put_partial_data(output)
				if result[0]!=OK:break
				output=output.slice(result[1])
			if socket.get_available_bytes()>0:
				var result:=socket.get_partial_data(mini(socket.get_available_bytes(),1048576-input.size()))
				if result[0]!=OK:break
				input.append_array(result[1])
				var end:=input.find(10)
				if end>=0:socket.disconnect_from_host();return input.slice(0,end)
				if input.size()>=1048576:break
		await get_tree().process_frame
	socket.disconnect_from_host()
	return '{"error":"Regional backend unavailable; reconnect or retry the pending operation"}'.to_utf8_buffer()
@rpc("authority","call_remote","reliable",0)
func _reply(request_id: int,bytes: PackedByteArray) -> void:receive(request_id,bytes)
@rpc("authority","call_remote","reliable",1)
func _snapshot(request_id: int,bytes: PackedByteArray) -> void:receive(request_id,bytes)
func receive(request_id: int,bytes: PackedByteArray) -> void:
	if server or bytes.size()>1048576:return
	var body=JSON.parse_string(bytes.get_string_from_utf8())
	if body is Dictionary:response.emit(request_id,body)
