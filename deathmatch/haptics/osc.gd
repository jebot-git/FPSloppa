extends RefCounted
## bHaptics VRChatOSC v2 boolean vest parameters, independent of VRChat itself.
## UDP is unacknowledged: an open socket never proves that a suit is connected.
const Preferences=preload("res://deathmatch/haptics/preferences.gd")
const MOTOR_COUNT=40
const ACTIVE_INTERVAL=.05
const IDLE_INTERVAL=.25
var udp: PacketPeerUDP
var expires:=PackedFloat64Array()
var next_send:=0.0
var error:=""
var packets_sent:=0
var cues: Array=[]
func _init() -> void:
	expires.resize(MOTOR_COUNT);expires.fill(0.0)
func is_open() -> bool:return udp!=null
static func address(index: int) -> String:
	return "/avatar/parameters/bOSC/v2/%s/%d/others"%["VestFront" if index<20 else "VestBack",index%20]
static func osc_string(value: String) -> PackedByteArray:
	var data:=value.to_utf8_buffer();data.append(0)
	while data.size()%4!=0:data.append(0)
	return data
static func message(index: int,on: bool) -> PackedByteArray:
	var data:=osc_string(address(index));data.append_array(osc_string(",T" if on else ",F"));return data
static func bundle(states: PackedByteArray,start: int,count: int) -> PackedByteArray:
	var stream:=StreamPeerBuffer.new();stream.big_endian=true
	stream.put_data(osc_string("#bundle"));stream.put_u32(0);stream.put_u32(1) # OSC immediate timetag.
	for index in range(start,mini(start+count,states.size())):
		var data:=message(index,states[index]!=0);stream.put_u32(data.size());stream.put_data(data)
	return stream.data_array
func open(host: String,port: int) -> Error:
	close();error=""
	if not Preferences.valid_endpoint(host,port):error="Enter a receiver IP address and a port from 1 to 65535.";return ERR_INVALID_PARAMETER
	udp=PacketPeerUDP.new()
	var err:=udp.set_dest_address(host,port)
	if err!=OK:
		error="OSC output unavailable: "+error_string(err);udp.close();udp=null;return err
	next_send=0
	return OK
func pulse(indices: Array,duration: float,now: float) -> void:
	if not is_open() or not is_finite(duration) or not is_finite(now) or duration<=0:return
	for index in indices:
		if index is int and index>=0 and index<MOTOR_COUNT:expires[index]=maxf(expires[index],now+minf(duration,.3))
	next_send=minf(next_send,now)
func states_at(now: float) -> PackedByteArray:
	var states:=levels_at(now)
	for index in MOTOR_COUNT:states[index]=1 if states[index]>0 else 0
	return states
func sequence(steps: Array,now: float) -> void:
	if not is_open() or not is_finite(now):return
	for step in steps:
		if cues.size()>=96:break
		var delay: float=clampf(float(step.get("delay",0)),0,1)
		var duration: float=clampf(float(step.get("duration",0)),0,.3)
		if not is_finite(delay) or not is_finite(duration) or duration<=0:continue
		var motors: Array=[]
		for index in step.get("motors",[]):
			if (index is int or index is float) and is_finite(float(index)) and int(index)==index and index>=0 and index<40:motors.append(int(index))
		cues.append({"start":now+delay,"end":now+delay+duration,"level":clampi(int(step.get("level",0)),0,15),"motors":motors})
	next_send=minf(next_send,now)
func has_pending(now: float) -> bool:
	for deadline in expires:
		if deadline>now:return true
	return cues.any(func(cue):return cue.end>now)
func levels_at(now: float) -> PackedByteArray:
	var states:=PackedByteArray();states.resize(MOTOR_COUNT)
	for index in MOTOR_COUNT:states[index]=15 if expires[index]>now else 0
	cues=cues.filter(func(cue):return cue.end>now)
	for cue in cues:
		if now>=cue.start:
			for index in cue.motors:states[index]=maxi(states[index],cue.level)
	return states
func tick(now: float) -> void:
	if not is_open() or now<next_send:return
	var states:=levels_at(now)
	next_send=now+(ACTIVE_INTERVAL if states.count(0)<40 or not cues.is_empty() else IDLE_INTERVAL)
	_send_levels(states)
func _send_levels(levels: PackedByteArray) -> void:_send(levels)
func _send(states: PackedByteArray) -> void:
	if not udp:return
	# Four small bundles stay below normal network MTUs, even with IPv6.
	for start in range(0,MOTOR_COUNT,10):
		var err:=udp.put_packet(bundle(states,start,10))
		if err!=OK:error="OSC send failed: "+error_string(err)
		else:packets_sent+=1
func stop() -> void:
	expires.fill(0.0);cues.clear();next_send=0
	if is_open():
		var states:=PackedByteArray();states.resize(MOTOR_COUNT)
		# Repeat releases; regular idle snapshots also recover lost UDP packets.
		for repeat in 3:_send(states)
func close() -> void:
	stop()
	if udp:udp.close();udp=null
