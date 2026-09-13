extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.active=true
	var voice=game.voice;voice.test_receive=true
	for id in [1,2,3,4]:game.players[id]=game._new_state("Radio guard",id);game.players[id].team=0
	game.players[3].team=1;game.players[4].spectator=true
	for kind in ["tdm","ctf","koth","ft","tf","as"]:
		game.match_mode.kind=kind
		check(voice.recipients(2,true)==[1],kind+" team voice excludes enemies and spectators")
	game.match_mode.kind="dm";check(voice.recipients(2,true).is_empty(),"Non-team mode rejects team channel instead of broadcasting it")
	game.match_mode.kind="tdm";check(voice.recipients(4,true).is_empty(),"Spectator cannot send on a former team")
	var fixture=preload("res://deathmatch/tests/opus_fixture.gd");var packet: PackedByteArray=fixture.packet(fixture.encoder())
	voice.receive(2,10,packet,true);check(voice.streams[2].team,"Team packet selects radio receive stream")
	voice.receive(2,12,packet,false);var count: int=voice.received_packets
	voice.receive(2,11,packet,true)
	check(voice.received_packets==count and not voice.streams[2].team,"Reordered packet cannot restore old radio channel")
	voice.receive(2,13,packet,true);game.players[2].team=1;voice._process(.02)
	check(not voice.streams.has(2),"Changing teams flushes queued private audio")
	count=voice.received_packets;voice.receive(2,14,packet,true)
	check(voice.received_packets==count,"Receiver rejects team packet after membership changes")
	voice.reset();check(voice.channel_serial.is_empty() and not voice.radio_active,"Reconnect clears radio channel history")
	game.active=false;await create_timer(.15).timeout;game.free();await process_frame;await process_frame
	print("RADIO_GUARDS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
