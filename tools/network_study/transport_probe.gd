extends SceneTree
# Isolate ENet fragmentation from game simulation. Packet bodies come from snapshot_audit.gd.
const LABELS = ["bounded_1100", "8desktop", "8vr", "16vr"]
const SAMPLES = 240
var peer := ENetMultiplayerPeer.new()
var server := false
var connected := false
var elapsed := 0.0
var next_send := 1.0
var sent := 0
var bodies: Array[PackedByteArray] = []
var results: Dictionary = {}
var ending := false

func _initialize() -> void:
	server = OS.get_cmdline_user_args()[0] == "server"
	for label in LABELS:
		var path: String = "8desktop" if label == "bounded_1100" else label
		var body := FileAccess.get_file_as_bytes("res://test-results/network-study/" + path + ".bin")
		assert(not body.is_empty())
		if label == "bounded_1100": body.resize(1084)
		bodies.append(body)
		results[label] = {"bytes": body.size() + 16, "received": 0, "delay_ms": [], "gap_ms": [], "last": 0.0}
	peer.peer_connected.connect(func(_id: int): connected = true)
	var err := peer.create_server(27787, 1, 3) if server else peer.create_client("127.0.0.1", 27788, 3)
	if err != OK:
		push_error("ENet setup failed: " + str(err)); quit(1)

func _process(delta: float) -> bool:
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		if server or packet.size() < 16: continue
		var stage := packet.decode_u32(0)
		if stage == 99:
			for row in results.values():
				row.erase("last")
				row["sent"] = SAMPLES
				for key in ["delay_ms", "gap_ms"]:
					var values: Array = row[key]; values.sort()
					row[key] = {"p95": values[int(values.size() * .95)] if not values.is_empty() else 0, "max": values[-1] if not values.is_empty() else 0}
			print("TRANSPORT_PROBE ", JSON.stringify(results)); peer.close(); quit(); return false
		if stage >= LABELS.size(): continue
		var row: Dictionary = results[LABELS[stage]]
		var now := Time.get_unix_time_from_system()
		row.received += 1; row.delay_ms.append((now - packet.decode_double(8)) * 1000.0)
		if row.last > 0: row.gap_ms.append((now - row.last) * 1000.0)
		row.last = now
	if not connected: return false
	elapsed += delta
	if not server: return false
	if ending:
		if elapsed > next_send + 2.0: peer.close(); quit()
		return false
	if elapsed < next_send: return false
	var packet := PackedByteArray(); packet.resize(16)
	if sent >= SAMPLES * LABELS.size():
		packet.encode_u32(0, 99); peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE; ending = true
	else:
		var stage := sent / SAMPLES
		packet.encode_u32(0, stage); packet.encode_u32(4, sent % SAMPLES)
		packet.encode_double(8, Time.get_unix_time_from_system()); packet.append_array(bodies[stage])
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	peer.transfer_channel = 1; peer.set_target_peer(0); peer.put_packet(packet)
	sent += 1; next_send += .05
	return false
