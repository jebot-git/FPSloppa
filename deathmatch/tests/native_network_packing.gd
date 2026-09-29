extends SceneTree
const Replication=preload("res://deathmatch/network/replication.gd")
const Codec=preload("res://deathmatch/network/snapshot_codec.gd")
class Legacy extends Replication:
	func _pack_records(records: Array,header: Array,result: Dictionary) -> void:
		var batch: Array=[]
		for record in records:
			var trial:=batch.duplicate();trial.append(record)
			var encoded:=Codec.pack([header[0],header[1],header[2],trial])
			if encoded.size()>BUDGET and not batch.is_empty():
				result.normal.append(Codec.pack([header[0],header[1],header[2],batch]));batch=[record]
				encoded=Codec.pack([header[0],header[1],header[2],batch])
			else:batch=trial
			if encoded.size()>BUDGET:result.large.append(encoded);stats.large_records+=1;batch=[]
		if not batch.is_empty():result.normal.append(Codec.pack([header[0],header[1],header[2],batch]))
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func snapshot(count: int,shots: int,vr: bool,tick: int) -> Array:
	var state: Array=[[],PackedByteArray(),600.0,0.0,"",20,600.0,[],[],1,{"kind":"dm","scores":[0,0],"bases":[],"flags":[],"hill":Vector3.ZERO,"owner":-1,"friendly_fire":false,"limit":20,"locomotion":{},"movement_ack":{},"ordnance":{}},{},tick*.05,shots]
	for i in count:
		var pose:=preload("res://deathmatch/vr/poses.gd").neutral() if vr else {}
		if vr:
			pose.body={"hips":Transform3D(Basis(Vector3.UP,sin(i+tick)),Vector3(0,.92,0)),"left_curls":PackedFloat32Array([.1,.2,.3,.4,.5])}
			pose.head.origin.x=sin(i+tick)*.1
		state[0].append([i+1,Vector3(i*1.7,sin(i+tick),i*.23),Vector3(1,0,0),.0,.0,100,0,false,7,[20,20,20,20],[0,2,7],0,0,30,1,.0,false,.0,pose,.0,false,Vector3.ZERO])
		state[10].locomotion[i+1]={"height":1.65,"grounded":true};state[10].movement_ack[i+1]=tick
	for i in shots:state[7].append([i+1,Vector3(i*.3,sin(i+tick),i*.7),1+i%count,7,Vector3(1,0,0),.0,.0])
	return state
func flatten(packets: Dictionary) -> Array:
	var records: Array=[]
	for packet in packets.normal+packets.large:
		check(not packet.is_empty(),"No empty encoded packet")
		var value=Codec.unpack(packet)
		check(value is Array and value.size()==4,"Every emitted packet decodes")
		records.append_array(value[3])
	# Reliable records can be interleaved differently; compare encoded record multiset.
	var result: Array=[]
	for row in records:result.append(row.hex_encode())
	result.sort();return result
func stats(rows: Array) -> Dictionary:
	rows.sort();return {"median":rows[rows.size()/2],"p95":rows[int(rows.size()*.95)]}
func _initialize() -> void:
	var reports: Array=[]
	for scenario in [[8,0,false],[16,32,true],[16,523,false]]:
		var legacy:=Legacy.new();var current:=Replication.new();var old_times: Array=[];var times: Array=[];var old_bytes:=0;var total_bytes:=0;var old_packets:=0;var total_packets:=0
		for tick in 64:
			var state:=snapshot(scenario[0],scenario[1],scenario[2],tick)
			var start:=Time.get_ticks_usec();var before:=legacy.packets(state);var elapsed_old:=Time.get_ticks_usec()-start
			start=Time.get_ticks_usec();var after:=current.packets(state);var elapsed:=Time.get_ticks_usec()-start
			if tick>=4:old_times.append(elapsed_old/1000.);times.append(elapsed/1000.)
			check(flatten(before)==flatten(after),"Independent records preserved "+str(scenario)+" tick "+str(tick))
			for packet in after.normal:check(packet.size()<=1100,"Unreliable packet stays within budget")
			for packet in before.normal+before.large:old_bytes+=packet.size();old_packets+=1
			for packet in after.normal+after.large:total_bytes+=packet.size();total_packets+=1
		reports.append({"players":scenario[0],"shots":scenario[1],"vr":scenario[2],"before_ms":stats(old_times),"after_ms":stats(times),"before_bytes":old_bytes,"after_bytes":total_bytes,"before_packets":old_packets,"after_packets":total_packets})
	var rng:=RandomNumberGenerator.new();rng.seed=7331
	var huge:=PackedByteArray();huge.resize(8192)
	for i in huge.size():huge[i]=rng.randi()%256
	var state:=snapshot(16,32,true,1);state[10]["large_test"]=huge
	var a:=Legacy.new().packets(state);var b:=Replication.new().packets(state)
	check(b.large.size()==1 and flatten(a)==flatten(b),"Oversized single record retains reliable delivery")
	var receiving:=Replication.new();b.normal.reverse()
	for packet in b.large+b.normal:check(receiving.receive(packet,1),"Mixed channel reordered packets accepted")
	check(receiving.flush()[10].large_test==huge,"Oversized payload reconstructed exactly")
	print("NATIVE_NETWORK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"reports":reports}));quit(0 if failures.is_empty() else 1)
