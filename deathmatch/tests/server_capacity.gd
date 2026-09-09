extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args()
	var role:=args[0]
	var count:=int(args[1])
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	if role=="host":
		game.max_clients=16 # A normal host must not retain a larger configured cap.
		game.bind_address="127.0.0.1";game.start_host("Playing host",28892,100,60,false)
		if not game.active or game.max_clients!=8:quit(1);return
		print("CAPACITY_HOST_READY")
	else:
		game.start_join(role,"127.0.0.1",28892)
	var deadline:=Time.get_ticks_msec()+90000
	var joined:=false
	var full_roster:=false
	var rejected:=role=="extra"
	while Time.get_ticks_msec()<deadline:
		if game.active and not joined:
			joined=true;print("CAPACITY_JOINED ",role)
		if rejected:
			if joined:quit(1);return
			if game.last_event.contains("server full") or game.last_event.contains("Connection failed") or game.last_event.contains("Connection timed out"):
				print("CAPACITY_REJECTED");quit(0);return
		elif game.players.size()==count and game.avatars.choices.size()==count and not full_roster:
			full_roster=true;print("CAPACITY_FULL_ROSTER ",count)
		if FileAccess.file_exists("res://test-results/capacity-stop"):
			game.disconnect_game();quit(0 if joined and full_roster else 1);return
		await create_timer(.05).timeout
	# A transport can reject a full server without delivering a game RPC.
	if rejected and not joined:print("CAPACITY_REJECTED timeout");quit(0)
	else:quit(1)
