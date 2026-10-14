extends SceneTree
## Exercise real socket selection, kernel limits and graceful absence.
func _initialize():
	if not preload("res://deathmatch/native/runtime.gd").available("FPSBackend"):
		push_error("FPSBackend unavailable");quit(1);return
	var backend=ClassDB.instantiate("FPSBackend")
	var a:=ENetMultiplayerPeer.new();var b:=ENetMultiplayerPeer.new()
	var failures:Array=[]
	if a.create_server(0)!=OK or b.create_server(0)!=OK:
		push_error("Cannot create test UDP sockets");quit(1);return
	var first:Dictionary=backend.tune_udp_buffer(a.host.get_local_port(),262144)
	var second:Dictionary=backend.tune_udp_buffer(b.host.get_local_port(),65536)
	var unchanged:Dictionary=backend.tune_udp_buffer(a.host.get_local_port(),262144)
	if OS.get_name()=="Linux":
		if not first.get("available",false) or first.get("error",-1)!=0:failures.append("Own ENet socket is tunable")
		if second.get("port")!=b.host.get_local_port() or second.get("after",0)<=0:failures.append("Second socket is selected by port")
		if unchanged.get("before")!=first.get("after"):failures.append("Other socket tuning must not alter first socket")
	if backend.tune_udp_buffer(-1,262144).get("available",true):failures.append("Absent socket is harmless")
	a.close();b.close();backend.shutdown()
	print("NETWORK_RECEIVE_BUFFER_RESULT ",JSON.stringify({"failures":failures,"first":first,"second":second}))
	quit(0 if failures.is_empty() else 1)
