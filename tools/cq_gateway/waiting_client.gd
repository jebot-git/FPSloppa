extends SceneTree
const Room=preload("res://deathmatch/conquest/waiting_room.gd")
var game
var failures: Array=[]
func _initialize():run.call_deferred()
func until(predicate: Callable,seconds: float=45) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		await create_timer(.05).timeout
	failures.append("Timed out waiting for client state");return false
func run():
	Engine.max_fps=60
	game=load("res://deathmatch/arena.tscn").instantiate();game.set_script(load("res://tools/cq_gateway/driver.gd"));root.add_child(game)
	game.start_join("Waiting room probe","127.0.0.1",game._arg_int(OS.get_cmdline_user_args(),"--test-port",29482))
	if not await until(func():return game.cq_client.waiting()):finish();return
	var id: int=game.multiplayer.get_unique_id();var actor=game.fighters[id]
	if actor.position.distance_to(Room.ORIGIN+Vector3(0,.1,2))>2:failures.append("Waiting client not placed in its private room")
	if not game.players[id].dead or not game.cq_client.frozen:failures.append("Waiting client is battle-active")
	game.target=Room.ORIGIN+Vector3(20,0,2);game.driving=true;game.trigger=true
	await create_timer(2.5).timeout
	if actor.position.x<2 or actor.position.x>5.7:failures.append("Private room movement or enclosing wall collision failed")
	if not game.projectiles.is_empty():failures.append("Waiting client created a combat projectile")
	game.driving=false;game.trigger=false
	if not await until(func():return not game.cq_client.waiting() and not game.cq_client.frozen and game.cq_client.zone==1):finish();return
	if game.players[id].dead or actor.position.y < -100:failures.append("Deployment baseline did not restore live city actor")
	await process_frame
	if is_instance_valid(game.cq_client.waiting_room):failures.append("Private room survived deployment")
	finish()
func finish():
	print("CQ_WAITING_CLIENT ",JSON.stringify({"failures":failures,"handoffs":game.cq_client.handoffs,"zone":game.cq_client.zone}))
	game.disconnect_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
