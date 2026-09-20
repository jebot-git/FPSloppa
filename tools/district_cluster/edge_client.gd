extends SceneTree
var edge
var responses: Dictionary={}
var sequence:=0
var settings: Dictionary
func _initialize() -> void:run.call_deferred()
func invoke(body: Dictionary) -> Dictionary:
	sequence+=1;var id:=sequence;edge.request(id,body)
	var deadline:=Time.get_ticks_msec()+6000
	while not responses.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	if not responses.has(id):return {"error":"ENet response timeout"}
	var result: Dictionary=responses[id];responses.erase(id);return result
func run() -> void:
	Engine.max_fps=120
	settings=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	edge=load("res://deathmatch/server/cluster/edge.gd").new();edge.name="ClusterEdge";root.add_child(edge)
	edge.response.connect(func(id,body):responses[id]=body)
	if edge.connect_gateway(settings.address)!=OK:quit(2);return
	var deadline:=Time.get_ticks_msec()+5000
	while edge.multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<deadline:await process_frame
	if edge.multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:push_error("ENet connect timeout");quit(3);return
	var joined:=await invoke({"op":"join","identity":Crypto.new().generate_random_bytes(16).hex_encode(),"resume":Crypto.new().generate_random_bytes(32).hex_encode(),"token":settings.token,"district":settings.district,"name":"ENet cluster probe"})
	if joined.has("error"):push_error(str(joined));quit(3);return
	var auth: Dictionary={"actor":joined.result.identity,"resume":joined.result.resume}
	await create_timer(.7).timeout
	var input:=auth.duplicate();input.merge({"op":"input","generation":joined.result.actor.generation,"command":{"seq":1,"move":[0,0]}})
	var accepted:=await invoke(input)
	var request:=auth.duplicate();request.op="snapshot"
	var snapshot:=await invoke(request)
	if accepted.has("error") or not accepted.result.accepted or snapshot.has("error") or not snapshot.result.actors.has(auth.actor):push_error(str([accepted,snapshot]));quit(3);return
	request.op="leave";var left:=await invoke(request)
	if left.has("error"):push_error(str(left));quit(3);return
	print("CLUSTER_ENET_TEST ",JSON.stringify({"joined":true,"input":true,"snapshot":true,"logout":true}));edge.multiplayer.multiplayer_peer.close();quit()
