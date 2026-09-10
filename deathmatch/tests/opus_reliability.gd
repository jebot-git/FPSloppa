extends SceneTree
const Fixture=preload("res://deathmatch/tests/opus_fixture.gd")
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.active=true;game.voice.test_receive=true
	game.set_physics_process(false)
	for child in game.get_node("Map").get_children():child.set_physics_process(false)
	var advance: Callable=func():game.clock+=root.get_process_delta_time()
	process_frame.connect(advance)
	for id in [2,3]:game.players[id]=game._new_state("Voice fixture",id)
	var enc:=Fixture.encoder();var packets: Array=[]
	for i in 80:packets.append(Fixture.packet(enc,i*960))
	check(packets.all(func(p):return game.voice.valid_packet(p)),"Native Opus 20ms packets pass validation")
	for i in 60:
		# Two concurrent speakers, reorder pairs, lose every seventh frame, replay duplicates.
		var seq: int=i+1 if i%2==0 else i-1
		for id in [2,3]:
			if seq%7!=0:
				game.voice.receive(id,seq,packets[seq]);game.voice.receive(id,seq,packets[seq])
		await create_timer(.02).timeout
	await create_timer(.25).timeout
	check(game.voice.decoded_packets>90,"Both speakers decode through reordering and loss concealment")
	check(game.voice.decoded_peak>.05,"Decoded Opus audio retains audible amplitude")
	check(game.voice.received_packets<120,"Duplicate packets are discarded")
	check(game.voice.streams.values().all(func(s):return not s.speaker.inopusstream),"Missing footer times out and drains the speech tail")
	game.voice.remove_stream(2)
	var before: int=game.voice.decoded_packets
	game.voice.receive(2,1000,packets[0]);await create_timer(.25).timeout
	check(game.voice.decoded_packets==before+1,"One-frame PTT utterance drains instead of remaining buffered")
	await create_timer(2.1).timeout
	check(game.voice.streams.is_empty(),"Idle speakers and native playback resources are released")
	process_frame.disconnect(advance)
	game.active=false;game.queue_free();await process_frame
	print("OPUS_RELIABILITY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
