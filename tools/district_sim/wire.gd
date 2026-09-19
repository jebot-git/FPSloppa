extends RefCounted
## Local-only, bounded framed Variant messages. Object decoding stays disabled.
const LIMIT:=1048576
var peer: StreamPeerTCP
var input:=PackedByteArray()
var output:=PackedByteArray()
var sent:=0
var received:=0
var failed:=false
func _init(socket: StreamPeerTCP):peer=socket;peer.set_no_delay(true)
func send(value: Dictionary) -> void:
	var data:=var_to_bytes(value)
	if data.size()>LIMIT or output.size()+data.size()>LIMIT*2:failed=true;return
	var header:=PackedByteArray();header.resize(4);header.encode_u32(0,data.size());output.append_array(header);output.append_array(data)
func poll() -> Array:
	peer.poll();var messages: Array=[]
	if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:return messages
	if not output.is_empty():
		var result:=peer.put_partial_data(output)
		if result[0]!=OK:failed=true;return messages
		sent+=result[1];output=output.slice(result[1])
	var count:=peer.get_available_bytes()
	if count>0:
		var result:=peer.get_partial_data(mini(count,LIMIT))
		if result[0]!=OK:failed=true;return messages
		received+=result[1].size();input.append_array(result[1])
	while input.size()>=4:
		var size:=input.decode_u32(0)
		if size<1 or size>LIMIT:failed=true;break
		if input.size()<size+4:break
		var value=bytes_to_var(input.slice(4,size+4));input=input.slice(size+4)
		if not value is Dictionary:failed=true;break
		messages.append(value)
	return messages
