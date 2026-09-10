extends SceneTree
const Fixture=preload("res://deathmatch/tests/opus_fixture.gd")
var game
var role:=""
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func wait_for(condition: Callable,seconds: float=10) -> bool:
	var end:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<end:
		if condition.call(): return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	role=args[0]
	game=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	game.voice.test_receive=true
	if role=="server":
		game.dedicated=true
		game.start_host("Voice test",28888,20,10,false)
		check(await wait_for(func(): return game.players.size()==2),"Two voice clients joined")
		check(await wait_for(func(): return game.voice.relayed_packets>=100),"Server relays bounded voice packets")
		await create_timer(1).timeout
	else:
		game.start_join(role,"127.0.0.1",28888)
		check(await wait_for(func(): return game.active and game.players.size()==2),"Client joined same protocol/map")
		check(game.local_state().get("owned",[])==[2],"Pistol-only inventory preserved")
		if role=="sender":
			var enc:=Fixture.encoder()
			for i in range(140):
				game.voice.send_packet(Fixture.packet(enc,i*960))
				await create_timer(.02).timeout
			check(game.voice.received_packets==0,"Sender does not hear network echo")
		else:
			check(await wait_for(func(): return game.voice.decoded_packets>=10),"Cross-process voice received and decoded")
			check(game.voice.decoded_peak>.01,"Opus playback contains audible decoded signal")
			var speaker:=0
			for id in game.players:
				if game.players[id].name=="sender": speaker=id
			game.voice.set_muted(speaker,true)
			var before: int=game.voice.received_packets
			await create_timer(.25).timeout
			check(game.voice.received_packets==before,"Per-player mute blocks playback queue")
			game.voice.set_muted(speaker,false)
			check(await wait_for(func(): return game.voice.received_packets>=before+20),"Unmute resumes voice")
			await create_timer(2).timeout
	print("VOICE_NETWORK_RESULT ",role," ",failures)
	game.disconnect_game()
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
