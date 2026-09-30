extends RefCounted
## Independent state records; loss of one datagram never blocks another entity.
const Codec = preload("res://deathmatch/network/snapshot_codec.gd")
const Locomotion=preload("res://deathmatch/network/locomotion_wire.gd")
const BUDGET = 1100 # Leaves room for the Godot RPC and transport envelope.
var native_packer=preload("res://deathmatch/network/codec.gd").native_codec
var native_packing_enabled=not OS.get_cmdline_user_args().has("--gdscript-network-packing")
var sequence := 0
var epoch := -1
var versions: Dictionary = {}
var player_rows: Dictionary = {}
var shot_rows: Dictionary = {}
var state: Array = []
var dirty := false
var cached: Dictionary = {}
var membership: Array = []
var membership_sequence := -1
var stats: Dictionary = {"sent_bytes":0,"sent_packets":0,"large_records":0,"received_packets":0,"stale_records":0,"max_packet":0,"player_update_gaps":0,"player_updates":0}

func reset() -> void:
	epoch = -1; sequence = 0; versions.clear(); player_rows.clear(); shot_rows.clear(); state.clear(); cached.clear(); dirty = false; membership.clear(); membership_sequence = -1

func packets(snapshot: Array) -> Dictionary:
	if epoch!=snapshot[9]:reset();epoch=snapshot[9]
	sequence+=1
	var records:Array=[]
	for index in [1,2,3,4,5,6,8,9,11,12,13]:records.append([0,index,snapshot[index]])
	var mode:Dictionary=snapshot[10]
	for key in mode:
		if key not in ["locomotion","movement_ack","ordnance"]:records.append([1,str(key),mode[key]])
	var ids:Array=[];var shots:Array=[]
	for row in snapshot[0]:
		ids.append(row[0]);records.append([2,row[0],row,Locomotion.encode(mode.get("locomotion",{}).get(row[0],{})),mode.get("movement_ack",{}).get(row[0],-1)])
	for row in snapshot[7]:
		shots.append(row[0]);records.append([3,row[0],row,mode.get("ordnance",{}).get(row[0],{})])
	records.append([4,0,ids,shots,mode.keys()])
	var result:Dictionary={"normal":[],"large":[]};var encoded_records:Array=[]
	var batch:Array=native_packer.encode_records(records) if native_packing_enabled and native_packer and native_packer.has_method("encode_records") else []
	for index in records.size():
		var record:Array=records[index]
		var bytes:PackedByteArray=batch[index] if batch.size()==records.size() else Codec.encode(record)
		if record[0] in [0,1,4] and not (record[0]==0 and record[1] in [2,3,12,13]):
			var key:=str(record[0])+":"+str(record[1])
			if cached.has(key) and cached[key].bytes==bytes and snapshot[12]-cached[key].time<1.:continue
			cached[key]={"bytes":bytes,"time":snapshot[12]}
		encoded_records.append(bytes)
	_pack_records(encoded_records,[snapshot[9],sequence,snapshot[12]],result)
	for bytes in result.normal+result.large:
		stats.sent_bytes+=bytes.size();stats.sent_packets+=1;stats.max_packet=maxi(stats.max_packet,bytes.size())
	return result

func _pack_records(records: Array,header: Array,result: Dictionary) -> void:
	if native_packing_enabled and native_packer and native_packer.has_method("pack_records"):
		var packed:Dictionary=native_packer.pack_records(records,header)
		result.normal.append_array(packed.normal);result.large.append_array(packed.large)
		stats.large_records+=packed.large.size()
		if packed.invalid:push_error("Snapshot record exceeds codec limit")
		return
	_pack_records_reference(records,header,result)

func _pack_records_reference(records: Array,header: Array,result: Dictionary) -> void:
	# Search packet-sized prefixes instead of recompressing after every record.
	# Every emitted candidate is checked: compression need not be monotonic.
	var cursor:=0;var previous_count:=8
	while cursor<records.size():
		var remaining:=records.size()-cursor
		var count:=mini(previous_count,remaining)
		var low:=0;var high:=remaining+1
		var accepted:=PackedByteArray()
		while true:
			var bytes:=Codec.pack([header[0],header[1],header[2],records.slice(cursor,cursor+count)])
			if not bytes.is_empty() and bytes.size()<=BUDGET:
				low=count;accepted=bytes
				if low==remaining:break
				if high==remaining+1:count=mini(remaining,maxi(low+1,low*2));continue
			else:
				high=count
				if count==1:
					# A single oversized record still uses the reliable channel.
					if not bytes.is_empty():result.large.append(bytes);stats.large_records+=1
					else:push_error("Snapshot record exceeds codec limit")
					low=1;break
			if high-low<=1:break
			count=(low+high)/2
		if not accepted.is_empty():result.normal.append(accepted)
		cursor+=low;previous_count=maxi(1,low)

func receive(bytes: PackedByteArray, expected_epoch: int) -> bool:
	var message = Codec.unpack(bytes)
	if not message is Array or message.size() != 4: return false
	if not message[0] is int or message[0] != expected_epoch or not message[1] is int or not message[2] is float or not message[3] is Array: return false
	if epoch != expected_epoch:
		reset(); epoch = expected_epoch
		state = [[],PackedByteArray(),0.0,0.0,"",30,10,[],[],epoch,{"locomotion":{},"movement_ack":{},"ordnance":{},"sample_time":{}},{},0.0,0]
	stats.received_packets += 1
	for encoded_record in message[3]:
		if not encoded_record is PackedByteArray: return false
		var record = Codec.decode(encoded_record)
		if not record is Array or record.size() < 3 or not record[0] is int: return false
		var key := str(record[0])+":"+str(record[1])
		if record[0] in [2,3] and message[1] <= membership_sequence and not record[1] in membership[record[0]-2]: continue
		if record[0] == 1 and message[1] <= membership_sequence and not record[1] in membership[2]: continue
		if message[1] <= versions.get(key,-1): stats.stale_records += 1; continue
		if record[0]==2:
			stats.player_updates+=1
			if versions.has(key):stats.player_update_gaps+=maxi(0,message[1]-int(versions[key])-1)
		versions[key] = message[1]
		match record[0]:
			0:
				if not record[1] in [1,2,3,4,5,6,8,9,11,12,13]: return false
				state[record[1]] = record[2]
			1:
				if not record[1] is String: return false
				state[10][record[1]] = record[2]
			2:
				if record.size() != 5 or not record[2] is Array or record[2].size() != 22 or not record[3] is Dictionary: return false
				player_rows[record[1]] = record[2]
				state[10].locomotion[record[1]] = Locomotion.decode(record[3]); state[10].movement_ack[record[1]] = record[4]; state[10].sample_time[record[1]] = message[2]
			3:
				if record.size() != 4 or not record[2] is Array or record[2].size() != 7 or not record[3] is Dictionary: return false
				shot_rows[record[1]] = record[2]
				if record[3].is_empty(): state[10].ordnance.erase(record[1])
				else: state[10].ordnance[record[1]] = record[3]
			4:
				if record.size() != 5 or not record[2] is Array or not record[3] is Array or not record[4] is Array: return false
				membership = [record[2],record[3],record[4]]; membership_sequence = message[1]
				for id in player_rows.keys():
					if not id in record[2] and versions.get("2:"+str(id),0) <= message[1]:
						player_rows.erase(id)
						for field in ["locomotion","movement_ack","sample_time"]: state[10][field].erase(id)
				for id in shot_rows.keys():
					if not id in record[3] and versions.get("3:"+str(id),0) <= message[1]: shot_rows.erase(id); state[10].ordnance.erase(id)
				for field in state[10].keys():
					if field not in record[4] and field not in ["locomotion","movement_ack","ordnance","sample_time"]: state[10].erase(field)
				for version in versions.keys():
					if version.begins_with("3:") and not int(version.substr(2)) in shot_rows: versions.erase(version)
					elif version.begins_with("2:") and not int(version.substr(2)) in player_rows: versions.erase(version)
			_: return false
	dirty = true
	return true

func flush() -> Array:
	if not dirty or not versions.has("0:9") or not versions.has("0:12") or not state[10].has("kind"): return []
	for field in ["scores","bases","flags","hill","owner","friendly_fire","limit"]:
		if not state[10].has(field): return []
	dirty = false; state[0] = player_rows.values(); state[7] = shot_rows.values()
	# Gameplay receivers rebase relative timers and may mutate their dictionaries.
	# Keep the wire cache immutable between independently arriving records.
	return state.duplicate(true)
