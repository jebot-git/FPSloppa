extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="qsrc_dm3";game.start_host("Probe",0,100,30,true,"dm","quake");game.set_process(false)
	while not game.bots.navigation.ready():await physics_frame
	var nav=game.bots.navigation;var point:=Vector3(-24,6,-16)
	for r in [2,4,6,8]:
		for i in 8:
			var target: Vector3=point+Vector3(cos(i*TAU/8),0,sin(i*TAU/8))*r
			var hit: Dictionary=nav.ray(target+Vector3.UP,target-Vector3.UP*20)
			if not hit.is_empty():print("LEDGE ",r," ",i," floor=",hit.position," clear=",nav.ray(point+Vector3.UP,hit.position+Vector3.UP).is_empty()," path=",nav.path(point,hit.position).size())
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
