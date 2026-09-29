extends SceneTree
const Fixture=preload("res://deathmatch/tests/native_network_packing.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
func full_pose(t: float) -> Dictionary:
	var pose:=Poses.neutral()
	pose.head.origin.x=sin(t)*.025
	pose.body={"hips":Transform3D(Basis(Vector3.UP,sin(t)*.08),Vector3(0,.92,0)),"chest":Transform3D(Basis(Vector3.RIGHT,sin(t)*.06),Vector3(0,1.2,0)),"left_curls":PackedFloat32Array([.3,.4,.6,.7,.8]),"right_curls":PackedFloat32Array([.4,.5,.7,.8,.9])}
	for side in ["left","right"]:
		var sign_side:=-1.0 if side=="left" else 1.0
		pose.body[side+"_foot"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.13,.08,0))
		pose.body[side+"_knee"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.16,.5,-.2))
		pose.body[side+"_elbow"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.5,.95,.02))
		pose.body[side+"_hand"]=pose[side]
	pose.face={"look":Vector2(sin(t)*.1,cos(t)*.08),"blink":Vector2.ONE*.2,"gaze":true,"lids":true,"expression":PackedFloat32Array([.4,0,0,0,0])}
	return pose
func stats(rows: Array) -> Dictionary:
	rows.sort();return {"mean_ms":rows.reduce(func(a,b):return a+b,0.)/rows.size(),"median_ms":rows[rows.size()/2],"p95_ms":rows[ceili(rows.size()*.95)-1]}
func bench(operation: Callable) -> Dictionary:
	for i in 100:operation.call()
	var samples: Array=[]
	for block in 40:
		var start:=Time.get_ticks_usec()
		for i in 100:operation.call()
		samples.append((Time.get_ticks_usec()-start)/100000.)
	return stats(samples)
func _initialize() -> void:
	var reports: Array=[]
	var fixture:=Fixture.new()
	for scenario in [[8,0,false],[16,32,true],[16,523,false]]:
		var sender:=Replication.new();var receiver:=Replication.new()
		var send_times: Array=[];var receive_times: Array=[];var flush_times: Array=[]
		var bytes:=0;var packets:=0
		for tick in 140:
			var state: Array=fixture.snapshot(scenario[0],scenario[1],false,tick)
			if scenario[2]:
				for row in state[0]:row[18]=full_pose(tick*.05+row[0])
			var start:=Time.get_ticks_usec();var batch:=sender.packets(state);var sent:=Time.get_ticks_usec()-start
			start=Time.get_ticks_usec()
			for packet in batch.normal+batch.large:
				if not receiver.receive(packet,1):push_error("FAIL receive");quit(1);return
			var received:=Time.get_ticks_usec()-start
			start=Time.get_ticks_usec();var restored:=receiver.flush();var flushed:=Time.get_ticks_usec()-start
			if restored[0].size()!=scenario[0] or restored[7].size()!=scenario[1]:push_error("FAIL row counts");quit(1);return
			if tick>=20:
				send_times.append(sent/1000.);receive_times.append(received/1000.);flush_times.append(flushed/1000.)
				for packet in batch.normal+batch.large:bytes+=packet.size();packets+=1
		reports.append({"players":scenario[0],"shots":scenario[1],"full_vr":scenario[2],"encode":stats(send_times),"receive":stats(receive_times),"flush":stats(flush_times),"bytes_per_snapshot":bytes/120.,"packets_per_snapshot":packets/120.})
	var pose:=full_pose(.7)
	if Poses.validate(pose).is_empty():push_error("FAIL invalid full pose");quit(1);return
	var raw:=Codec.encode(pose);var packed:=Codec.pack(pose)
	var codec:={"scope":"Full body/face pose only, excludes command envelope; 40 batches of 100 calls after 100 warmup calls. One scenario at a time.","raw_bytes":raw.size(),"packed_bytes":packed.size(),"encode":bench(func():return Codec.encode(pose)),"decode":bench(func():return Codec.decode(raw)),"pack":bench(func():return Codec.pack(pose)),"unpack":bench(func():return Codec.unpack(packed)),"validate":bench(func():return Poses.validate(pose)),"compress":bench(func():return raw.compress(FileAccess.COMPRESSION_FASTLZ)),"decompress":bench(func():return packed.slice(5).decompress(raw.size(),FileAccess.COMPRESSION_FASTLZ))}
	print("REMAINING_RESULT ",JSON.stringify({"engine":Engine.get_version_info().string,"snapshots":reports,"pose_codec":codec,"scope":"Current production paths; 20 warmup + 120 changing snapshots each; includes compression, record caches and full receiver flush. No ENet transport, loss, scene application or rendering."}))
	fixture.free();quit()
