extends RefCounted
## SlimeVR VRChat OSC output; bounded OSC 1.0 messages and nested bundles.
const ROLES={"1":"hips","2":"left_foot","3":"right_foot","4":"left_knee","5":"right_knee","6":"chest","7":"left_elbow","8":"right_elbow","head":"head"}
var samples: Dictionary={}
func parse(data: PackedByteArray,now: float,depth: int=0) -> void:
	if depth>4 or data.size()>16384 or data.size()<8: return
	if data.slice(0,7).get_string_from_ascii()=="#bundle" and data[7]==0:
		if data.size()<16: return
		var stream:=StreamPeerBuffer.new(); stream.big_endian=true; stream.data_array=data; stream.seek(16)
		var count:=0
		while stream.get_available_bytes()>=4 and count<64:
			count+=1
			var size:=stream.get_u32()
			if size<8 or size>stream.get_available_bytes(): return
			parse(stream.get_data(size)[1],now,depth+1)
		return
	var cursor:=0
	var strings: Array=[]
	for i in range(2):
		var end:=data.find(0,cursor)
		if end<0 or end-cursor>128: return
		strings.append(data.slice(cursor,end).get_string_from_ascii())
		cursor=(end+4)&~3
	if strings[1]!=",fff" or cursor+12!=data.size(): return
	var parts: PackedStringArray=strings[0].split("/")
	if parts.size()!=5 or parts[1]!="tracking" or parts[2]!="trackers" or not ROLES.has(parts[3]) or not parts[4] in ["position","rotation"]: return
	var stream:=StreamPeerBuffer.new(); stream.big_endian=true; stream.data_array=data; stream.seek(cursor)
	var value:=Vector3(stream.get_float(),stream.get_float(),stream.get_float())
	if not value.is_finite() or value.length()>1000: return
	var key: String=ROLES[parts[3]]
	var state: Dictionary=samples.get(key,{})
	if parts[4]=="position":
		state.position=Vector3(value.x,value.y,-value.z); state.time=now
	else:
		# Unity left-handed YXZ Euler -> Godot right-handed.
		state.basis=Basis.from_euler(Vector3(-value.x,-value.y,value.z)*PI/180,EULER_ORDER_YXZ)
		state.rotation_time=now
	samples[key]=state
func current(now: float) -> Dictionary:
	var result: Dictionary={}
	for key in samples:
		var state: Dictionary=samples[key]
		if state.has("position") and now-float(state.time)<.25:
			result[key]=Transform3D(state.basis if state.has("basis") and now-float(state.rotation_time)<.25 else Basis.IDENTITY,state.position)
	return result
