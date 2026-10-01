extends RefCounted
## Nonblocking bounded TCP frames. HMAC authenticates every frame in both directions.
## No Object decoding, compression bombs, unbounded queues or synchronous socket waits.
const MAX_FRAME:=2097152
const BUDGET:=131072
var peer: StreamPeerTCP
var key: PackedByteArray
var context:=""
var outgoing:=PackedByteArray()
var offset:=0
var incoming:=PackedByteArray()
var tx:=0
var rx:=0
var failed:=false
var sent_bytes:=0
var received_bytes:=0
var crypto:=Crypto.new()
func _init(socket: StreamPeerTCP,secret: PackedByteArray):peer=socket;key=secret
func close():failed=true;peer.disconnect_from_host()
func idle() -> bool:return outgoing.is_empty()
func send(value: Dictionary) -> bool:
	if failed or not idle():return false
	tx+=1
	var data:=var_to_bytes({"seq":tx,"context":context,"body":value})
	var mac:=crypto.hmac_digest(HashingContext.HASH_SHA256,key,data)
	var length:=data.size()+32
	if length>MAX_FRAME:close();return false
	outgoing.resize(4);outgoing.encode_u32(0,length);outgoing.append_array(mac);outgoing.append_array(data);offset=0
	return true
func flush():
	if not outgoing.is_empty():
		var result:=peer.put_partial_data(outgoing.slice(offset,mini(outgoing.size(),offset+BUDGET)))
		if result[0]!=OK:close();return
		offset+=result[1];sent_bytes+=result[1]
		if offset==outgoing.size():outgoing.clear();offset=0
func poll() -> Array:
	var messages: Array=[]
	if failed:return messages
	peer.poll()
	if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:close();return messages
	flush()
	if failed:return messages
	var available:=mini(peer.get_available_bytes(),BUDGET)
	if available>0:
		var result:=peer.get_partial_data(available)
		if result[0]!=OK:close();return messages
		incoming.append_array(result[1]);received_bytes+=result[1].size()
	if incoming.size()>MAX_FRAME+4:close();return messages
	# At most four frames per poll prevents a worker monopolising a server frame.
	for _i in 4:
		if incoming.size()<4:break
		var size:=incoming.decode_u32(0)
		if size<33 or size>MAX_FRAME:close();break
		if incoming.size()<size+4:break
		var signature:=incoming.slice(4,36);var data:=incoming.slice(36,size+4)
		incoming=incoming.slice(size+4)
		if not crypto.constant_time_compare(signature,crypto.hmac_digest(HashingContext.HASH_SHA256,key,data)):close();break
		var value=bytes_to_var(data)
		if not value is Dictionary or value.get("context")!=context or not value.get("seq") is int or value.seq!=rx+1 or not value.get("body") is Dictionary:close();break
		rx=value.seq;messages.append(value.body)
	return messages
