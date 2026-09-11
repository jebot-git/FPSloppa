extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world);Fixture.box(world,Fixture.ORIGIN-Vector3.UP*.5,Vector3(40,1,40))
	var actor:=Fighter.new();actor.setup(1,"Prediction",Color.WHITE);world.add_child(actor)
	actor.position=Fixture.point();actor.quake_movement=true
	await physics_frame;await physics_frame
	for latency_ticks in [2,6,12,24]:
		actor.reset_view();actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.jump_held=false
		for i in 5:actor.simulate(Vector2.ZERO,0,false,1.0/60)
		actor.prediction.remember(10,actor.position,actor.velocity)
		var old_position:=actor.position;var old_velocity:=actor.velocity
		actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
		for i in latency_ticks:
			actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
			actor.prediction.remember(11+i,actor.position,actor.velocity)
		var predicted:=actor.velocity;var predicted_position:=actor.position
		actor.prediction.reconcile(actor,10,old_position,old_velocity)
		check(actor.velocity.is_equal_approx(predicted) and actor.position.is_equal_approx(predicted_position),"Delayed grounded snapshot preserves newer jump at %d ms"%roundi(latency_ticks*1000.0/60))
	actor.reset_view();actor.position=Vector3(5,2,0);actor.velocity=Vector3(9,6,0)
	actor.prediction.remember(1,Vector3.ZERO,Vector3(9,0,0))
	actor.prediction.reconcile(actor,1,Vector3.ZERO,Vector3(9,4,0))
	check(actor.velocity==Vector3(9,10,0),"Unpredicted server impulse is added without removing pending jump")
	actor.prediction.reconcile(actor,1,Vector3.ZERO,Vector3(9,4,0))
	check(actor.velocity.y==10,"Repeated acknowledgement cannot apply impulse twice")
	actor.prediction.remember(2,Vector3.ZERO,Vector3.ZERO)
	var before:=actor.position
	actor.prediction.reconcile(actor,2,Vector3(.6,0,0),Vector3.ZERO)
	check(actor.position.x>before.x and (actor.position+actor.prediction_view_offset).is_equal_approx(before),"Server collision correction preserves visual origin for smooth convergence")
	actor.prediction.remember(3,Vector3.ZERO,Vector3.ZERO)
	actor.prediction.reconcile(actor,3,Vector3(20,0,0),Vector3.ZERO)
	check(actor.position==Vector3(20,0,0) and actor.prediction.samples.is_empty() and actor.prediction_view_offset==Vector3.ZERO,"Large divergence resets authority, visual offset and history")
	for i in 1000:actor.prediction.remember(i,Vector3.ZERO,Vector3.ZERO)
	check(actor.prediction.samples.size()==180,"Prediction history remains bounded under missing snapshots")
	actor.reset_view();check(actor.prediction.samples.is_empty(),"Respawn/teleport clears old-life prediction")
	var secondary:=VRMSecondary.new()
	secondary.set_local_body(true);secondary.do_process(1.0)
	check(secondary.local_body_disabled,"Local spring simulation exits before touching uninitialized skeleton")
	secondary.set_local_body(false);check(not secondary.local_body_disabled,"Remote spring simulation can be restored")
	secondary.free();world.free();await process_frame
	print("LOCAL_PREDICTION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
