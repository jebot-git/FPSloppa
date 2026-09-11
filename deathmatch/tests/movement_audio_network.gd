extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class Capture extends Node:
	var heard: Array=[]
	func clear():pass
	func play(kind: String,where: Vector3,_volume: float=-8):
		if kind in ["jump","land"]:heard.append([kind,where])
var game
class Barrier extends Node:
	var ready_peers: Dictionary={}
	var completed_peers: Dictionary={}
	var scenario_done:=false
	@rpc("any_peer","call_remote","reliable",3)
	func audio_ready() -> void:
		ready_peers[multiplayer.get_remote_sender_id()]=true
	@rpc("authority","call_remote","reliable",3)
	func audio_done() -> void:
		scenario_done=true
	@rpc("any_peer","call_remote","reliable",3)
	func audio_completed() -> void:
		completed_peers[multiplayer.get_remote_sender_id()]=true
var barrier: Barrier
var failures: Array=[]
func _initialize():call_deferred("run")
func until(condition: Callable,seconds: float=12) -> bool:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await create_timer(.02).timeout
	return false
func check(ok: bool,label: String):
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	var role: String=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	barrier=Barrier.new();barrier.name="AudioBarrier";root.add_child(barrier)
	var capture:=Capture.new();game.add_child(capture);var original=game.effects;game.effects=capture
	if role=="server":
		game.dedicated=true;game.start_host("Jump audio",28916,100,60,false)
		check(await until(func():return game.players.size()==2),"Two clients connected")
		game.set_physics_process(false);game.set_process(false)
		check(await until(func():return barrier.ready_peers.size()==2),"Both audio receivers ready")
		if game.players.size()==2:
			var id: int=game.players.keys()[0];var actor=game.fighters[id]
			actor.position=Fixture.point()+Vector3.UP*.03;actor.velocity=Vector3.ZERO
			for i in 15:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
			await create_timer(.5).timeout
			# Server-confirmed movement emits one reliable cue despite held/air input.
			for i in 100:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
			await create_timer(.5).timeout
			barrier.audio_done.rpc()
			check(await until(func():return barrier.completed_peers.size()==2),"Both receivers checked events")
			await create_timer(1).timeout
	else:
		game.start_join(role,"127.0.0.1",28916)
		check(await until(func():return game.active),"Connected")
		game.set_physics_process(false);game.set_process(false);game.headless=false
		barrier.audio_ready.rpc_id(1)
		check(await until(func():return barrier.scenario_done),"Scenario completed")
		check(capture.heard.filter(func(e):return e[0]=="jump").size()==1,"Exactly one remote jump cue")
		check(capture.heard.filter(func(e):return e[0]=="land").size()==1,"Exactly one remote landing cue")
		check(capture.heard.all(func(e):return e[1].distance_to(Fixture.point())<1),"Events retain authoritative source position")
		barrier.audio_completed.rpc_id(1)
		await create_timer(.5).timeout
	barrier.free()
	game.headless=true;game.effects=original;game.disconnect_game("Test done");game.free();await process_frame
	print("MOVEMENT_AUDIO_NETWORK ",role," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
