extends SceneTree
## Reproduce the actual thin-bridge snag found during the teamplay soak.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	seed(7129)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="tf_ironspan";game.start_host("Underpass test",0,100,60,true,"tf","quake")
	game.set_physics_process(false);game.set_process(false)
	for id in game.players:
		game.players[id].spectator=id!=-1;game.players[id].team=0
	game.players[-1].tf_next="engineer";game._spawn(-1)
	var deadline:=Time.get_ticks_msec()+20000
	while not game.bots.ready_to_walk or not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("Underpass navigation timed out");quit(1);return
		await physics_frame
	var actor=game.fighters[-1]
	var start:=Vector3(-2.124006,-1.405652,-7.575234)
	actor.position=start;actor.velocity=Vector3.ZERO;game.bots.brains[-1]=game.bots.new_brain(-1)
	var crawled:=false;var escaped:=false
	for frame in 1200:
		await physics_frame;game._physics_process(1.0/60)
		crawled=crawled or game.players[-1].prone
		if actor.position.distance_to(start)>8 and actor.position.y>-.1:escaped=true;break
	print("PASS " if crawled and escaped else "FAIL ","Engineer crawls out of Ironspan bridge snag and returns to dry ground using normal physics")
	game.disconnect_game();game.queue_free();await process_frame;await process_frame
	quit(0 if crawled and escaped else 1)
