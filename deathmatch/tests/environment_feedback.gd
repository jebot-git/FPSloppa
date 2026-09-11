extends SceneTree
var failures: Array=[]
class Sounds extends Node3D:
	var calls: Array=[]
	func play(kind: String,where: Vector3,_volume: float=-8) -> void:calls.append({"kind":kind,"where":where})
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.effects.free();var capture:=Sounds.new();game.add_child(capture);game.effects=capture
	var door:=StaticBody3D.new();game.add_child(door);door.position=Vector3(100,100,100)
	game.gates=[{"node":door,"base_position":door.position,"center":door.position,"travel":Vector3(3,0,0),"open":false,"until":0}]
	game._gate_state(0,true)
	var first: Tween=game.gates[0].motion_tween
	game._gate_state(0,true)
	check(capture.calls.size()==1 and capture.calls[0].kind=="door_open" and game.gates[0].motion_tween==first,"Opening door emits one motor cue and duplicate state does not restart motion")
	await create_timer(.12).timeout
	game._gate_state(0,false)
	check(capture.calls.size()==2 and capture.calls[1].kind=="door_close" and not first.is_valid(),"Reversing door plays closing cue and cancels the opening tween")
	await create_timer(.7).timeout
	check(door.position.is_equal_approx(game.gates[0].base_position),"Reversed door settles exactly at its closed position")
	game._gate_state(0,false);game._gate_state(-1,true);game._gate_state(99,true)
	check(capture.calls.size()==2,"Duplicate closed state and invalid gate indices create no sound")
	game._gate_state(0,true);var pending: Tween=game.gates[0].motion_tween;door.free();await process_frame;await process_frame
	check(not pending.is_valid(),"Removing a door also cancels its animation")
	game.gates.clear();capture.calls.clear()
	# Exercise a real trigger overlap, using the production teleport path.
	var runtime=preload("res://deathmatch/maps/runtime.gd").new();game.add_child(runtime);runtime.game=game;runtime.set_physics_process(false)
	game.players[1]=game._new_state("Traveler",1);game._create_fighter(1);game.players[1].dead=false;game.players[1].spectator=false
	var actor=game.fighters[1];actor.position=Vector3(200,100,200)
	var area:=Area3D.new();game.add_child(area);area.position=actor.position+Vector3.UP*.8;area.collision_layer=0;area.collision_mask=2
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,3,2);shape.shape=box;area.add_child(shape)
	runtime.regions=[{"kind":"trigger_teleport","area":area,"data":{"target":"exit"}}]
	var destination: Vector3=actor.position+Vector3(8,0,0);runtime.destinations={"exit":{"position":destination,"yaw":0.0}}
	game.active=true
	# Newly added physics objects need a broadphase update before overlap queries.
	for tick in 8:
		await physics_frame
		if area.overlaps_body(actor):break
	check(area.overlaps_body(actor),"Real teleport trigger detects the player capsule")
	game.demos.recording=true;game.demos.events.clear()
	runtime._physics_process(.016);runtime._physics_process(.016)
	check(actor.position==destination and capture.calls.size()==2 and capture.calls.all(func(c):return c.kind=="teleport"),"Activation sounds at departure and arrival once despite repeated overlap polling")
	check(game.demos.events.size()==2 and game.demos.events.all(func(e):return e[0]=="_teleport_fx"),"Both teleport cues enter the existing demo event stream")
	game.demos.recording=false
	for kind in ["door_open","door_close","teleport"]:
		var cue=game.spatial.choose(kind)
		check(cue is AudioStream and cue.get_length()>.3 and cue.get_length()<1,"Imported spatial cue is available: "+kind)
	game.active=false;game.free();await process_frame
	print("ENVIRONMENT_FEEDBACK_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
