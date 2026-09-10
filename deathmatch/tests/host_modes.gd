extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	for mode in game.match_mode.NAMES:
		game.start_host("Mode test",0,20,10,true,mode)
		check(game.active and game.match_mode.kind==mode,"In-game host starts "+game.match_mode.NAMES[mode])
		check(game.max_clients==8,"In-game host retains eight-player limit for "+mode)
		game.disconnect_game();await process_frame
	game.queue_free();await process_frame;await process_frame
	print("HOST_MODES_RESULT ",failures);quit(0 if failures.is_empty() else 1)
