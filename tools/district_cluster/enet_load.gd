extends SceneTree
## External protocol clients. Never creates server-side bots or AI.
const Edge=preload("res://deathmatch/server/cluster/edge.gd")
var settings: Dictionary
var completed:=0
var failures: Array=[]
var cycles:=0
var bytes:=0
var latencies: Array=[]
class Probe extends Node:
	var edge
	var replies: Dictionary={}
	var serial:=0
	func call_server(body: Dictionary) -> Dictionary:
		serial+=1;var request:=serial;edge.request(request,body)
		var until:=Time.get_ticks_msec()+8000
		while not replies.has(request) and Time.get_ticks_msec()<until:await get_tree().process_frame
		if not replies.has(request):return {"error":"Request timeout"}
		var result: Dictionary=replies[request];replies.erase(request);return result
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.max_fps=240
	settings=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	for index in int(settings.get("clients",16)):drive(index)
	while completed<int(settings.get("clients",16)):await process_frame
	latencies.sort()
	var result:={"clients":completed,"cycles":cycles,"bytes":bytes,"p95_cycle_ms":latencies[int(latencies.size()*.95)] if not latencies.is_empty() else 0,"errors":failures}
	print("CQ_ENET_LOAD ",JSON.stringify(result));quit(0 if failures.is_empty() else 3)
func drive(index: int) -> void:
	var parent:=Probe.new();parent.name="Probe%d"%index;root.add_child(parent)
	set_multiplayer(SceneMultiplayer.new(),parent.get_path())
	parent.edge=Edge.new();parent.edge.name="ClusterEdge";parent.add_child(parent.edge)
	parent.edge.response.connect(func(id,body):parent.replies[id]=body)
	if parent.edge.connect_gateway(settings.address)!=OK:failures.append("Connect failed");completed+=1;return
	var until:=Time.get_ticks_msec()+5000
	while parent.edge.multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<until:await process_frame
	var secret:=Crypto.new().generate_random_bytes(32).hex_encode();var key:=Crypto.new().generate_random_bytes(16).hex_encode()
	var joined: Dictionary=await parent.call_server({"op":"join","identity":key,"resume":secret,"token":settings.token,"district":"d40","team":0,"name":"ENet probe"})
	if joined.has("error"):failures.append(joined.error);completed+=1;return
	var auth:={"actor":key,"resume":secret}
	await create_timer(.8).timeout
	var deadline:=Time.get_ticks_msec()+int(settings.get("seconds",15))*1000
	var seq:=0
	while Time.get_ticks_msec()<deadline:
		var began:=Time.get_ticks_msec();seq+=1
		var input:=auth.duplicate();input.merge({"op":"input","generation":joined.result.actor.generation,"command":{"seq":seq,"move":[0,0],"fire":false}})
		var applied: Dictionary=await parent.call_server(input)
		var command:=auth.duplicate();command.op="snapshot"
		var reply: Dictionary=await parent.call_server(command)
		if reply.has("error") or applied.has("error"):failures.append(str([applied.get("error",""),reply.get("error","")]))
		else:cycles+=1;bytes+=JSON.stringify(reply.result).length();latencies.append(Time.get_ticks_msec()-began)
		await create_timer(maxf(.001,.05-(Time.get_ticks_msec()-began)/1000.0)).timeout
	var leave:=auth.duplicate();leave.op="leave";await parent.call_server(leave)
	parent.edge.multiplayer.multiplayer_peer.close();completed+=1
