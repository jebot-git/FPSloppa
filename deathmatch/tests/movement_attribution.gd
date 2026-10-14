extends SceneTree
const Attribution=preload("res://deathmatch/server/attribution.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var world:=Node3D.new();root.add_child(world)
	var floor:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,1,40);collider.shape=box;floor.position.y=-.5;floor.add_child(collider);world.add_child(floor)
	var left:=Fighter.new();var right:=Fighter.new()
	for actor in [left,right]:
		world.add_child(actor);actor.setup(11,"profile",Color.WHITE);actor.configure_cs16(true)
	left.position=Vector3(-5,.01,0);right.position=Vector3(5,.01,0)
	await physics_frame
	Attribution.reset()
	for step in 60:
		var command:=Vector2(.1,-.4);var delta:=1./30
		Attribution.enabled=false;left.simulate(command,0,false,delta,step==12)
		Attribution.enabled=true;var token:=Attribution.begin("test.root")
		right.simulate(command,0,false,delta,step==12)
		preload("res://deathmatch/vr/room_scale.gd").move_capsule(right,Vector3.ZERO,0,delta)
		Attribution.end(token);Attribution.tick(0,2)
		check((left.position+Vector3(10,0,0)).distance_to(right.position)<.0001 and left.velocity.distance_to(right.velocity)<.0001,"Attribution preserves controller trajectory "+str(step))
	var report:=Attribution.summary();check(report.scope_errors==0,"Scopes stay balanced across early-return movement")
	var categories:Dictionary=report.categories
	check(categories["movement.simulate"].calls==60,"Movement calls counted")
	check(categories["query.movement.room_scale_zero"].calls==60,"Zero-request collision calls counted")
	check(categories["query.movement.slide"].calls>0,"Slide calls counted")
	var own:=0.;var root_total:float=categories["test.root"].inclusive_total_ms
	for row in categories.values():own+=row.self_total_ms
	check(absf(root_total-own)<.0001,"Exclusive scopes sum to root without double counting")
	Attribution.enabled=false;var old_size:=Attribution.ticks.size();left.simulate(Vector2.ZERO,0,false,1./30)
	check(Attribution.ticks.size()==old_size and Attribution.stack.is_empty(),"Disabled recorder produces no samples")
	print("MOVEMENT_ATTRIBUTION_RESULT ",JSON.stringify({"failures":failures,"scope_count":categories.size()}))
	Attribution.reset();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
