extends SceneTree
const Opus=preload("res://deathmatch/tests/opus_fixture.gd")
var game
var public_packets:=0
var team_packets:=0
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args();var tag:=args[args.find("--probe")+1]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.voice.test_receive=true
	game.voice.packet_received.connect(func(_id,serial,_data):
		if serial<=100:public_packets+=1
		else:team_packets+=1)
	game.start_join("VoiceProbe "+tag,args[args.find("--host")+1],int(args[args.find("--port")+1]))
	var deadline:=Time.get_ticks_msec()+45000
	while not game.active or game.players.size()!=3:
		if Time.get_ticks_msec()>deadline:quit(1);return
		await create_timer(.05).timeout
	await create_timer(float(args[args.find("--settle")+1])).timeout
	var sender: int=game.players.keys().filter(func(id):return game.players[id].name=="VoiceProbe 01")[0]
	var teammate: bool=game.match_mode.same_team(sender,game.multiplayer.get_unique_id())
	if tag=="01":
		var encoder=Opus.encoder()
		for serial in range(1,201):
			game.voice.submit.rpc_id(1,serial,Opus.packet(encoder,serial*960),serial>100)
			await create_timer(.02).timeout
		encoder=null
		await create_timer(2).timeout
	else:await create_timer(8).timeout
	var passed: bool=game.match_mode.kind=="tdm"
	if tag=="01":passed=passed and game.voice.received_packets==0
	else:passed=passed and public_packets>=80 and (team_packets>=80 if teammate else team_packets==0) and game.voice.decoded_packets>50 and game.voice.decoded_peak>.01
	print("REMOTE_VOICE_RESULT ",JSON.stringify({"tag":tag,"teammate":teammate,"public_packets":public_packets,"team_packets":team_packets,"decoded":game.voice.decoded_packets,"peak":game.voice.decoded_peak,"passed":passed}))
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(0 if passed else 1)
