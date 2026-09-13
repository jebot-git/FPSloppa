extends SceneTree
const Replication = preload("res://deathmatch/network/replication.gd")
const Codec = preload("res://deathmatch/network/codec.gd")
const Demo = preload("res://deathmatch/demos/session.gd")
func summary(values: Array) -> Dictionary:
	values.sort()
	return {"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
func _initialize() -> void:
	var sizes = JSON.parse_string(FileAccess.get_file_as_string("res://test-results/network-study/sizes.json"))
	var results: Dictionary = {}
	for count in [8,16]:
		for vr in [false,true]:
			var label: String = "%d%s"%[count,"vr" if vr else "desktop"]
			var key: String = "synthetic:%s:%s"%[count,"full_body_vr" if vr else "desktop"]
			var bytes := FileAccess.get_file_as_bytes("res://test-results/network-study/"+label+".bin")
			var snapshot: Array = bytes_to_var(bytes.decompress(int(sizes.groups[key].raw.p50),FileAccess.COMPRESSION_FASTLZ))
			var sender := Replication.new(); var totals: Array = []; var times: Array = []; var max_packet := 0; var large := 0
			for sample in 60:
				snapshot[12] = 100.0+sample*.05
				for row in snapshot[0]: row[1] += Vector3(.031,.013,-.021)
				var started := Time.get_ticks_usec(); var packets := sender.packets(snapshot); times.append(Time.get_ticks_usec()-started)
				var total := 0
				for packet in packets.normal+packets.large: total += packet.size(); max_packet = maxi(max_packet,packet.size())
				totals.append(total); large += packets.large.size()
			results[label] = {"total_bytes":summary(totals),"encode_us":summary(times),"max_packet":max_packet,"large_records":large}
	var file := FileAccess.open("res://test-results/remote-all-modes/all-modes.fpsdemo",FileAccess.READ); file.get_buffer(8)
	var frame_index := 0; var sampled := 0; var failures: Array = []; var modes: Dictionary = {}
	while file.get_position()<file.get_length():
		var frame = bytes_to_var(file.get_buffer(file.get_32())); frame_index += 1
		if frame_index%100 != 1: continue
		var state: Array = frame.snapshot.duplicate(true); state.append(frame.time); state.append(0)
		var sender := Replication.new(); var receiver := Replication.new(); var packets := sender.packets(state)
		for packet in packets.normal+packets.large:
			if not receiver.receive(packet,state[9]): failures.append([frame_index,"decode"])
		var result := receiver.flush()
		if result.is_empty(): failures.append([frame_index,"empty"]); continue
		frame.snapshot = result.slice(0,12)
		if not Demo.valid_frame(frame): failures.append([frame_index,"demo"])
		if result[0].size()!=state[0].size() or result[7].size()!=state[7].size(): failures.append([frame_index,"entities"])
		modes[state[10].kind] = true; sampled += 1
	results.recorded = {"sampled":sampled,"modes":modes.keys(),"failures":failures}
	FileAccess.open("res://test-results/network-upgrade/sizes.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("UPGRADE_SIZES ",JSON.stringify(results)); quit(0 if failures.is_empty() else 1)
