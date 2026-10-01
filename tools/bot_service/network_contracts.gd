extends SceneTree
const Channel=preload("res://deathmatch/bot_service/channel.gd")
var listener:=TCPServer.new()
var checks:=0
func _initialize():run.call_deferred()
func check(value: bool,label: String):
	checks+=1
	if not value:push_error(label);quit(1)
func pair() -> Array:
	var sender:=StreamPeerTCP.new();sender.connect_to_host("127.0.0.1",29886)
	while not listener.is_connection_available():sender.poll();await process_frame
	var receiver:=listener.take_connection()
	while sender.get_status()!=StreamPeerTCP.STATUS_CONNECTED:sender.poll();await process_frame
	return [Channel.new(sender,"01234567890123456789012345678901".to_utf8_buffer()),Channel.new(receiver,"01234567890123456789012345678901".to_utf8_buffer())]
func transfer(a,b) -> Array:
	for i in 30:
		a.poll();var messages: Array=b.poll()
		if not messages.is_empty() or b.failed:return messages
		await process_frame
	return []
func run():
	check(listener.listen(29886,"127.0.0.1")==OK,"listen")
	var peers: Array=await pair();var a=peers[0];var b=peers[1]
	a.context="session";b.context="session";a.send({"type":"test","move":Vector2(0,-1)})
	var wire: PackedByteArray=a.outgoing.duplicate()
	var received: Array=await transfer(a,b)
	check(received.size()==1 and received[0].move==Vector2(0,-1),"authenticated vector payload")
	b.incoming=wire;b.poll();check(b.failed,"replayed sequence");a.close()
	peers=await pair();a=peers[0];b=peers[1]
	a.context="old session";b.context="new session";a.send({"type":"test"});await transfer(a,b);check(b.failed,"session replay");a.close()
	peers=await pair();a=peers[0];b=peers[1]
	a.key="incorrect worker key with 32 bytes".to_utf8_buffer();a.send({"type":"hello"});await transfer(a,b);check(b.failed,"wrong authentication key");a.close()
	peers=await pair();a=peers[0];b=peers[1]
	var oversized:=PackedByteArray();oversized.resize(4);oversized.encode_u32(0,Channel.MAX_FRAME+1);b.incoming=oversized;b.poll();check(b.failed,"oversized frame before allocation");a.close()
	peers=await pair();a=peers[0];b=peers[1]
	a.send({"type":"test"});wire=a.outgoing.duplicate();wire[-1]=wire[-1]^1;b.incoming=wire;b.poll();check(b.failed,"tampered payload");a.close()
	listener.stop();print("BOT_NETWORK_CONTRACTS_PASS checks=",checks);quit()
