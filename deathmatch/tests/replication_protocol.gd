extends SceneTree
const Codec = preload("res://deathmatch/network/codec.gd")
const Replication = preload("res://deathmatch/network/replication.gd")
const Poses = preload("res://deathmatch/vr/poses.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var pose := Poses.neutral(); pose.body = {}
	for key in ["hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"]:
		pose.body[key] = Transform3D(Basis.from_euler(Vector3(.31,.72,-.44)),Vector3(.15,1.0,.23))
	pose.body.left_curls = PackedFloat32Array([.1,.2,.3,.4,.5]); pose.body.right_curls = pose.body.left_curls
	pose.face = {"look":Vector2(.1,.1),"blink":Vector2(.2,.1),"gaze":true,"lids":true,"expression":PackedFloat32Array([.1,.2,.1,.2,.1])}
	var decoded = Codec.unpack(Codec.pack(pose))
	check(decoded is Dictionary and not Poses.validate(decoded).is_empty(),"Compact full-body pose passes gameplay validation")
	check(decoded.body.hips.origin.distance_to(pose.body.hips.origin)<.0001 and decoded.body.hips.basis.get_rotation_quaternion().angle_to(pose.body.hips.basis.get_rotation_quaternion())<.001,"Pose position/rotation error remains below tolerance")
	for value in [0,1,-1,2147483647,-2147483648,9999999999,"名前 🦊",PackedByteArray(),PackedFloat32Array(),true,false]:
		check(Codec.unpack(Codec.pack(value)) == value,"Codec round trip: "+str(value))
	check(Codec.unpack(PackedByteArray([1,255,255,255,255,1])) == null,"Oversized decode rejected")
	check(Codec.unpack(PackedByteArray([0,1,2])) == null,"Unknown/truncated header rejected")
	var input := {"seq":123,"map_epoch":1,"move":Vector2(.4,.8),"yaw":.5,"pitch":.2,"fire":true,"slow":false,"weapon":6,"respawn":false,"xr":pose}
	var input_bytes := Codec.pack(input).size()
	check(input_bytes <= 1100,"Full-body command fits datagram budget")
	input["input_life"]=1;input["jump_event"]=1;input["fire_event"]=[1,6,1]
	input["pilot_controls"]=[[true,Vector2(.6,-.8),true],[true,Vector2(-.4,.5),false]]
	var pilot_packet:=Codec.pack(input)
	check(pilot_packet.size()<=1100 and Codec.unpack(pilot_packet).pilot_controls==input.pilot_controls,"Manual cockpit controls round trip within full-body input budget")
	var mode: Dictionary={"kind":"dm","scores":[0,0],"bases":[],"flags":[],"hill":Vector3.ZERO,"owner":-1,"friendly_fire":false,"limit":20,"locomotion":{},"movement_ack":{}}
	var snapshot: Array=[[],PackedByteArray(),600.0,0.0,"",20,600.0,[],[],1,mode,{},1.0,0]
	var template: Array=[1,Vector3.ZERO,Vector3.ZERO,0.0,0.0,100,0,false,2,{"bullets":50},[0,2],0,0,30,1,0.0,false,0.0,{},0.0,false,Vector3.ZERO]
	for i in 16:
		var row := template.duplicate(true); row[0] = 10000+i; row[18] = pose.duplicate(true); row[1] = Vector3(i*.732,1.0,i*.31)
		row[18].head.origin.x = sin(i)*.1; snapshot[0].append(row)
		for joint in row[18].body:
			if row[18].body[joint] is Transform3D:
				row[18].body[joint].basis = Basis.from_euler(Vector3(sin(i*.7),cos(i*.8),sin(i*.2)))
		snapshot[10].locomotion[row[0]] = {"height":1.65,"grounded":true}; snapshot[10].movement_ack[row[0]] = i
	var sender := Replication.new(); var receiver := Replication.new()
	var start := Time.get_ticks_usec(); var packets := sender.packets(snapshot); var elapsed := Time.get_ticks_usec()-start
	var total := 0; var maximum := 0
	for bytes in packets.normal:
		total += bytes.size(); maximum = maxi(maximum,bytes.size()); check(bytes.size() <= 1100,"Bounded routine datagram")
	check(packets.large.is_empty(),"Sixteen full-body actors need no oversized reliable record")
	packets.normal.reverse()
	for bytes in packets.normal: check(receiver.receive(bytes,1),"Reordered independent datagram accepted")
	var result := receiver.flush()
	check(not result.is_empty() and result[0].size() == 16,"Independent datagrams reconstruct all players")
	check(result[10].movement_ack.size() == 16,"Input acknowledgements remain associated with players")
	for bytes in packets.normal: receiver.receive(bytes,1)
	check(not receiver.receive(packets.normal[0],2),"Previous-map packet rejected")
	# Dropping one packet must still update actors carried by the other packets.
	snapshot[12] += .05
	for row in snapshot[0]: row[1].x += 1.0
	var next := sender.packets(snapshot); var dropped = next.normal.pop_back()
	for bytes in next.normal: receiver.receive(bytes,1)
	var partial := receiver.flush(); var moved := 0
	for row in partial[0]:
		if row[1].distance_to(snapshot[0][row[0]-10000][1]) < .0001: moved += 1
	check(moved > 0 and moved < 16,"One missing datagram preserves independent actor progress")
	check(receiver.receive(dropped,1),"Late independent packet accepted")
	var final := receiver.flush(); check(final[0].size() == 16,"Late recovery preserves roster")
	var removed: int=snapshot[0].pop_back()[0];snapshot[12]+=.05
	var departure:=sender.packets(snapshot)
	for bytes in departure.normal+departure.large:receiver.receive(bytes,1)
	for bytes in next.normal+[dropped]:receiver.receive(bytes,1)
	var after_departure:=receiver.flush()
	check(after_departure[0].size()==15 and not receiver.player_rows.has(removed) and not receiver.versions.has("2:"+str(removed)),"Membership tombstones prevent stale resurrection and prune departed player history")
	print("REPLICATION_PROTOCOL_RESULT ",JSON.stringify({"failures":failures,"input_bytes":input_bytes,"snapshot_bytes":total,"max_packet":maximum,"packets":packets.normal.size(),"encode_us":elapsed,"players_updated_with_one_packet_missing":moved}))
	quit(0 if failures.is_empty() else 1)
