extends SceneTree
const Runtime=preload("res://deathmatch/native/runtime.gd")
const Hits=preload("res://deathmatch/hit_detection.gd")
const Lag=preload("res://deathmatch/lag_compensation.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func same(a:float,b:float) -> bool:return (not is_finite(a) and not is_finite(b)) or absf(a-b)<.000002
func _initialize():run.call_deferred()
func flattened(packets:Dictionary) -> Array:
	var rows:Array=[]
	for packet in packets.normal+packets.large:
		var decoded=preload("res://deathmatch/network/snapshot_codec.gd").unpack(packet)
		check(decoded is Array,"Encoded snapshot decodes")
		for row in decoded[3]:rows.append(row.hex_encode())
	rows.sort();return rows
func run():
	var backend=Runtime.backend()
	check(backend!=null,"FPSBackend loaded")
	if not backend:quit(1);return
	var rng:=RandomNumberGenerator.new();rng.seed=93713
	var native_us:=0;var reference_us:=0
	for trial in 3000:
		var height:float=[.65,.79,.80,1.05,1.65][trial%5];var yaw:=rng.randf_range(-PI,PI);var radius:float=[0.,.05,.4][trial%3]
		var start:=Vector3(rng.randf_range(-3,3),rng.randf_range(-.5,2),rng.randf_range(-3,3));var end:=Vector3(rng.randf_range(-3,3),rng.randf_range(-.5,2),rng.randf_range(-3,3))
		var time:=Time.get_ticks_usec();var actual:float=backend.player_fraction(start,end,height,yaw,radius);native_us+=Time.get_ticks_usec()-time
		time=Time.get_ticks_usec();var expected:=Hits.player_fraction_reference(start,end,height,yaw,radius);reference_us+=Time.get_ticks_usec()-time
		check(same(actual,expected),"Swept geometry differential "+str(trial))
		check(backend.player_axis(end,height,yaw).distance_to(Hits.player_axis_reference(end,height,yaw))<.000002,"Cover axis differential "+str(trial))
		check(backend.player_head(end,height,yaw,radius)==Hits.player_head_reference(end,height,yaw,radius),"Head differential "+str(trial))
	for trial in 1000:
		var pose:Dictionary=preload("res://deathmatch/vr/poses.gd").neutral();pose.left_handed=trial%2==0
		pose.head.origin=Vector3(rng.randf_range(-.9,.9),rng.randf_range(0,3.3),rng.randf_range(-.2,.2))
		if trial%3==0:pose.right.basis=Basis(Vector3.UP,rng.randf_range(-PI,PI))
		if trial%7==0:pose.left.basis.x*=1.03
		if trial%11==0:pose["unsupported"]=1
		if trial%13==0:pose.height=NAN
		if trial%17==0:pose.offhand_weapon=Transform3D.IDENTITY
		check(backend.validate_pose(pose)==preload("res://deathmatch/vr/poses.gd").validate_reference(pose),"Tracked pose validation differential "+str(trial))
		var head:=Vector3(rng.randf_range(-1,1),1.65,rng.randf_range(-1,1))
		check(backend.room_request(head).distance_to(preload("res://deathmatch/vr/room_scale.gd").request_reference(head))<.000002,"Room-scale request differential "+str(trial))
	for malformed in [null,[],1,{1:1},{"height":"invalid"}]:check(backend.validate_pose(malformed).is_empty(),"Malformed pose is rejected")
	var before:Dictionary={};var after:Dictionary={};var current:Dictionary={}
	for id in 64:
		before[id]={"serial":id,"position":Vector3(id,0,0),"height":.65,"yaw":3.12}
		after[id]={"serial":id,"position":Vector3(id+1,0,0),"height":1.65,"yaw":-3.12};current[id]=after[id].duplicate()
	after[2].serial+=1;current[2]=after[2].duplicate();after[3].position.x+=10;current[3]=after[3].duplicate()
	var history:Array=[{"time":0.,"positions":before},{"time":1.,"positions":after}]
	backend.record_history(0.,before);backend.record_history(1.,after)
	var ring_result:Dictionary=backend.history_state(1.,.2,current)
	var combined:=Lag.combined(history,1.,.2,current)
	for pair in [["positions",false,false],["heights",true,false],["yaws",false,true]]:
		var expected:=Lag.positions(history,1.,.2,current,pair[1],pair[2]);check(ring_result[pair[0]]==expected,"Typed history ring "+pair[0]);check(combined[pair[0]]==expected,"Combined rewind "+pair[0]+" with serial, teleport and angle guards")
	var positions:=PackedVector3Array();var teams:=PackedInt32Array();var observers:=PackedInt32Array();var targets:=PackedInt32Array();var radii:=PackedFloat64Array()
	for id in 64:
		positions.append(Vector3(id*4,0,0));teams.append(id%2);observers.append(0 if id%7==0 else 1);targets.append(0 if id%9==0 else 1);radii.append(75. if id%3 else 150.)
	var filtering:Array=[]
	backend.set_parallel_threshold(128)
	for workers in [1,2,4]:
		backend.set_workers(workers);var time:=Time.get_ticks_usec();var result:Array
		for iteration in 128:result=backend.range_candidates(positions,teams,observers,targets,radii)
		filtering.append({"workers":workers,"mean_us":(Time.get_ticks_usec()-time)/128.})
		for i in 64:
			var expected:=PackedInt32Array()
			for j in 64:
				if i!=j and observers[i] and targets[j] and teams[i]!=teams[j] and positions[i].distance_squared_to(positions[j])<=radii[i]*radii[i]:expected.append(j)
			check(result[i]==expected,"Ordered candidate batch workers="+str(workers)+" observer="+str(i))
	var sync:=Replication.new();var async_rep:=Replication.new();var source=preload("res://deathmatch/tests/native_network_packing.gd").new()
	for tick in 20:
		var snapshot:Array=source.snapshot(64,24,true,tick);var expected:=sync.packets(snapshot)
		check(async_rep.queue_packets(snapshot),"Bounded snapshot submission")
		# The producer may mutate live game state immediately after submission.
		snapshot[0][0][1]=Vector3(999,999,999);snapshot[10].scores[0]=999
		var packets:Array=[];var deadline:=Time.get_ticks_msec()+5000
		while packets.is_empty() and Time.get_ticks_msec()<deadline:
			await process_frame;packets=async_rep.poll_packets()
		check(packets.size()==1,"Asynchronous completion")
		if not packets.is_empty():check(flattened(packets[0])==flattened(expected),"Async cache/bytes match synchronous immutable state tick="+str(tick))
	var queue=ClassDB.instantiate("FPSBackend");var record:Array=[[0,1,"bounded"]]
	check(not queue.submit_snapshot([1],[1,1,0.],1) and not queue.submit_snapshot([[]],[1,1,0.],1) and not queue.submit_snapshot(record,[1,1,"invalid"],1),"Malformed snapshot jobs never enter worker queue")
	check(queue.submit_snapshot(record,[1,1,0.],1) and queue.submit_snapshot(record,[1,2,.05],1) and not queue.submit_snapshot(record,[1,3,.1],1),"At most two outstanding snapshot jobs, including completions")
	queue.shutdown();queue=null
	check(async_rep.queue_packets(source.snapshot(64,0,false,21)),"Reset test submits pending job");async_rep.reset();check(async_rep.poll_packets().is_empty(),"Reset joins encoder and discards prior epoch/life work")
	async_rep.reset();source.free();backend.shutdown();Runtime.backend_instance=null
	print("NATIVE_BACKEND_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"hit_native_ms":native_us/1000.,"hit_reference_ms":reference_us/1000.,"filtering":filtering}))
	quit(0 if failures.is_empty() else 1)
