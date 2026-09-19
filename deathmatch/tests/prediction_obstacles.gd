extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	Fixture.box(world,Vector3(0,-.5,0),Vector3(30,1,30))
	Fixture.box(world,Vector3(1,2,0),Vector3(1,4,20))
	var actor:=Fighter.new();actor.setup(1,"Wall prediction",Color.WHITE);world.add_child(actor)
	actor.set_process(false)
	for quake in [false,true]:
		actor.quake_movement=quake;actor.position=Vector3(-2,.01,0);actor.velocity=Vector3.ZERO;actor.reset_view()
		for tick in 60:
			await physics_frame;actor.simulate(Vector2.RIGHT,0,false,1.0/60)
		var stopped: Vector3=actor.position
		actor.prediction.remember(1,stopped,Vector3(9,0,0))
		actor.prediction.reconcile(actor,1,stopped,Vector3.ZERO,-1,true)
		check(absf(actor.velocity.x)<.01,"Wall-stop acknowledgement does not kick player backwards (quake=%s)"%quake)
		actor.velocity=Vector3.ZERO
		var worst_motion:=0.0;var penetration:=0.0
		for tick in 60:
			await physics_frame
			actor.simulate(Vector2.RIGHT,0,false,1.0/60)
			if tick%3==0:
				# A delayed sample was behind the authority; the current capsule
				# has already reached the obstacle in the meantime.
				actor.prediction.remember(tick+2,stopped-Vector3.RIGHT*.6,Vector3.ZERO)
				actor.prediction.reconcile(actor,tick+2,stopped,Vector3.ZERO,-1,true)
			penetration=maxf(penetration,actor.position.x-stopped.x)
			actor._process(1.0/60)
			worst_motion=maxf(worst_motion,absf((actor.position+actor.prediction_view_offset).x-stopped.x))
		print("OBSTACLE_METRICS ",JSON.stringify({"quake":quake,"stopped_x":stopped.x,"max_correction":penetration,"max_view_motion":worst_motion}))
		check(stopped.x+penetration<=.201,"Reconciliation cannot push capsule through obstacle (quake=%s)"%quake)
		check(worst_motion<.005,"Holding against wall keeps view steady under delayed corrections (quake=%s)"%quake)
		# A correction along the wall must still converge to authority.
		actor.prediction.clear();actor.prediction.remember(100,actor.position,Vector3.ZERO)
		var before: Vector3=actor.position
		var view_before:=actor.render_position()
		actor.prediction.reconcile(actor,100,before+Vector3(0,0,.6),Vector3.ZERO,-1,true)
		check(actor.position.z>before.z+.1,"Tangential correction remains available (quake=%s)"%quake)
		check(actor.render_position().distance_to(view_before)<.0001,"Correction preserves interpolated camera position (quake=%s)"%quake)
		actor.velocity=Vector3.ZERO
		for tick in 20:await physics_frame;actor.simulate(Vector2.LEFT,0,false,1.0/60)
		check(actor.position.x<stopped.x-.5,"Player can immediately move away from obstacle (quake=%s)"%quake)
	# Two wall normals must not turn a delayed stop into a diagonal recoil.
	Fixture.box(world,Vector3(0,2,-2),Vector3(20,4,1))
	actor.position=Vector3(-2,.01,0);actor.velocity=Vector3.ZERO;actor.reset_view()
	for tick in 60:await physics_frame;actor.simulate(Vector2(1,-1),0,false,1.0/60)
	var corner:=actor.position
	actor.prediction.remember(1,corner,Vector3(9,0,-9))
	actor.prediction.reconcile(actor,1,corner,Vector3.ZERO,-1,true)
	check(Vector2(actor.velocity.x,actor.velocity.z).length()<.01,"Corner stop cannot produce diagonal recoil")
	# A player who has just reversed input must keep that newer movement.
	actor.velocity=Vector3(-4,0,4)
	actor.prediction.remember(2,corner,Vector3(9,0,-9))
	actor.prediction.reconcile(actor,2,corner,Vector3.ZERO,-1,true)
	check(actor.velocity.is_equal_approx(Vector3(-4,0,4)),"Delayed contact preserves newer movement away from corner")
	actor.prediction.remember(3,corner,Vector3.ZERO)
	actor.prediction.reconcile(actor,3,corner,Vector3(-3,4,3),-1,true)
	check(actor.velocity.is_equal_approx(Vector3(-7,4,7)),"Real authority blast away from obstacle is retained")
	Fixture.box(world,Vector3(-5,2.5,4),Vector3(4,.4,4))
	actor.position=Vector3(-5,.01,4);actor.velocity=Vector3.ZERO;actor.reset_view();actor.jump_held=false
	for tick in 5:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	var ceiling:=false
	for tick in 30:
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60,tick==0)
		if actor.is_on_ceiling():ceiling=true;break
	check(ceiling,"Jump fixture reaches low ceiling")
	var before_velocity:=actor.velocity
	actor.prediction.remember(1,actor.position,Vector3.UP*6)
	actor.prediction.reconcile(actor,1,actor.position,Vector3.ZERO)
	check(actor.velocity.is_equal_approx(before_velocity),"Ceiling-stop acknowledgement cannot kick camera downwards")
	world.free();print("PREDICTION_OBSTACLES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
