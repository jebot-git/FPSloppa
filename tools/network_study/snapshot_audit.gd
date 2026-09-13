extends SceneTree
const Demo=preload("res://deathmatch/demos/session.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var groups: Dictionary={}
func stats(values: Array) -> Dictionary:
	values.sort();var sum:=0.0
	for v in values:sum+=v
	return {"count":values.size(),"mean":sum/maxi(1,values.size()),"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
func measure(key: String,state: Array) -> PackedByteArray:
	var start:=Time.get_ticks_usec();var raw:=var_to_bytes(state);var wire:=raw.compress(FileAccess.COMPRESSION_FASTLZ);var micros:=Time.get_ticks_usec()-start
	if not groups.has(key):groups[key]={"raw":[],"compressed":[],"encode_us":[]}
	groups[key].raw.append(raw.size());groups[key].compressed.append(wire.size());groups[key].encode_us.append(micros)
	return wire
func pose(t: float,index: int) -> Dictionary:
	var p:=Poses.neutral();p.body={}
	var j:=0
	for key in ["head","left","right","weapon"]:
		p[key].basis=Basis.from_euler(Vector3(.2*sin(t+j),.5*sin(t*.8+index),.1*cos(t+j)))
		p[key].origin+=Vector3(sin(t+j)*.02,cos(t*.7+j)*.02,cos(t+j)*.02);j+=1
	for key in ["hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"]:
		p.body[key]=Transform3D(Basis.from_euler(Vector3(.3*sin(t+j),.6*sin(t*.8+index+j),.2*cos(t+j))),Vector3(.3*sin(j),.8+.7*cos(j),.2*sin(t+j)));j+=1
	p.body.left_curls=PackedFloat32Array([.1,.2,.3,.4,.5]);p.body.right_curls=PackedFloat32Array([.6,.7,.8,.9,1])
	p.face={"look":Vector2(.1*sin(t),.1*cos(t)),"blink":Vector2(.2,.1),"gaze":true,"lids":true,"expression":PackedFloat32Array([.1,.2,.1,.2,.1])}
	assert(not Poses.validate(p).is_empty())
	return p
func _initialize() -> void:
	var file:=FileAccess.open("res://test-results/remote-all-modes/all-modes.fpsdemo",FileAccess.READ)
	assert(file.get_buffer(8).get_string_from_ascii()==Demo.MAGIC)
	var example: Array=[];var count:=0
	while file.get_position()<file.get_length():
		var size:=file.get_32();var frame=bytes_to_var(file.get_buffer(size));assert(Demo.valid_frame(frame));count+=1
		var state: Array=frame.snapshot.duplicate(true)
		# Demo capture contains twelve state arguments. Add the live timestamp/watermark.
		if state.size()==12:state.append(frame.time);state.append(0)
		measure("recorded:"+state[10].kind,state)
		if state[10].kind=="dm" and state[0].size()==9 and frame.time>10 and example.is_empty():example=state
	file.close();assert(not example.is_empty())
	for players in [8,16]:
		for vr in [false,true]:
			var label: String="synthetic:%s:%s"%[players,"full_body_vr" if vr else "desktop"]
			for sample in 60:
				var state: Array=example.duplicate(true);var template: Array=state[0][0].duplicate(true);state[0]=[];state[10].locomotion={};state[10].movement_ack={}
				for i in players:
					var row: Array=template.duplicate(true);row[0]=10001+i;row[1]=Vector3(i*2.03+sin(sample*.13+i),1+cos(i),i*1.83);row[2]=Vector3(sin(i+sample)*6,cos(i),cos(i+sample)*6);row[3]=sin(sample*.2+i)*PI;row[18]=pose(sample*.1,i) if vr else {};row[20]=false
					state[0].append(row);state[10].movement_ack[row[0]]=sample
					state[10].locomotion[row[0]]={"height":1.65,"grounded":true,"assist":false}
				state[7]=[];state[10].ordnance={}
				for i in 32:state[7].append([i,Vector3(i*.3,sin(i+sample),i*.7),10001+i%players,6,Vector3(1,0,0),0.0,0.0])
				var wire:=measure(label,state)
				if sample==30:FileAccess.open("res://test-results/network-study/"+str(players)+( "vr" if vr else "desktop")+".bin",FileAccess.WRITE).store_buffer(wire)
				if vr:
					var command: Dictionary={"map_epoch":1,"seq":sample,"move":Vector2(.4,.8),"yaw":.4,"pitch":-.2,"fire":true,"weapon":6,"slow":false,"respawn":false,"jump":false,"xr":state[0][0][18],"room":Vector3.ZERO,"swim":Vector3.ZERO,"view_time":sample*.05}
					if not groups.has("input:full_body_vr"):groups["input:full_body_vr"]={"raw":[],"compressed":[],"encode_us":[]}
					var raw:=var_to_bytes(command);groups["input:full_body_vr"].raw.append(raw.size());groups["input:full_body_vr"].compressed.append(raw.compress(FileAccess.COMPRESSION_FASTLZ).size());groups["input:full_body_vr"].encode_us.append(0)
	for key in groups:
		for field in groups[key]:groups[key][field]=stats(groups[key][field])
	FileAccess.open("res://test-results/network-study/sizes.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":count,"groups":groups},"  "))
	print("SNAPSHOT_AUDIT ",count," frames ",groups.size()," scenarios");quit()
