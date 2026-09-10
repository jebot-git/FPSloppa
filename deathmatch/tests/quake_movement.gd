extends SceneTree
const Movement=preload("res://deathmatch/movement/quake.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const DT:=1.0/60
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func ground_speed(wish: Vector2,speed: float) -> Vector2:
	var v:=Vector2.ZERO
	for i in 60:v=Movement.horizontal(v,wish,speed,true,false,DT)
	return v
func run():
	check(is_equal_approx(ground_speed(Vector2.UP,9.4).length(),9.4),"Ground running retains the existing 9.4 m/s balance")
	check(is_equal_approx(ground_speed(Vector2.ONE,9.4).length(),9.4),"Diagonal input does not increase ground speed")
	check(is_equal_approx(ground_speed(Vector2.UP*.25,9.4).length(),2.35),"Partial VR stick input retains analog speed")
	check(is_equal_approx(ground_speed(Vector2.UP,5.2).length(),5.2) and is_equal_approx(ground_speed(Vector2.UP,9.4*.7).length(),9.4*.7),"Walking and TF class speed multipliers remain effective")
	var drift:=Vector2(0,-12)
	for i in 60:drift=Movement.horizontal(drift,Vector2.ZERO,9.4,false,false,DT)
	check(drift==Vector2(0,-12),"Releasing movement in the air preserves horizontal momentum")
	var turned:=Movement.horizontal(drift,Vector2.RIGHT,9.4,false,false,DT)
	check(turned.x>0 and turned.y==-12 and turned.length()>12,"Air strafing adds directional speed without erasing forward momentum")
	check(Movement.horizontal(drift,Vector2.UP,9.4,false,false,DT)==drift,"Air acceleration cannot add speed along an already saturated direction")
	check(Movement.horizontal(drift,Vector2.DOWN,9.4,false,false,DT).y>drift.y,"Opposing air input brakes along its direction")
	check(Movement.horizontal(drift,Vector2.ZERO,9.4,true,true,DT)==drift,"Queued takeoff skips ground friction")
	for i in 60:drift=Movement.horizontal(drift,Vector2.ZERO,9.4,true,false,DT)
	check(drift==Vector2.ZERO,"Ground friction comes to a complete stop")
	var world:=Node3D.new();root.add_child(world)
	Fixture.box(world,Vector3(0,-.5,0),Vector3(100,1,100))
	var actor=preload("res://deathmatch/fighter.gd").new();actor.setup(1,"Movement",Color.WHITE);world.add_child(actor);actor.set_process(false)
	actor.quake_movement=true;actor.position=Vector3(0,.02,0)
	for i in 10:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
	for i in 30:await physics_frame;actor.simulate(Vector2.UP,0,false,DT)
	check(actor.is_on_floor() and absf(actor.velocity.z+9.4)<.01,"CharacterBody3D reaches running speed on real ground")
	await physics_frame;actor.simulate(Vector2.UP,0,false,DT,true)
	check(not actor.is_on_floor() and actor.velocity.y>7,"Jump leaves the floor without being cancelled by snap")
	var takeoff:=Vector2(actor.velocity.x,actor.velocity.z)
	for i in 12:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
	check(Vector2(actor.velocity.x,actor.velocity.z).is_equal_approx(takeoff),"Real airborne collision movement preserves coasting speed")
	for i in 12:await physics_frame;actor.simulate(Vector2.RIGHT,0,false,DT)
	check(actor.velocity.x>3 and Vector2(actor.velocity.x,actor.velocity.z).length()>9.8,"Real jump supports air-strafe speed gain")
	for i in 90:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
	check(actor.is_on_floor() and Vector2(actor.velocity.x,actor.velocity.z).length()<.01,"Landing without jump applies friction and stops")
	var takeoffs:=0
	for i in 180:
		await physics_frame
		var on_ground: bool=actor.is_on_floor()
		actor.simulate(Vector2.ZERO,0,false,DT,true)
		if on_ground and actor.velocity.y>7:takeoffs+=1
	check(takeoffs==1,"Holding jump produces only one takeoff and cannot auto-hop")
	var manual_takeoffs:=0
	for hop in 3:
		for i in 60:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,false)
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,true)
		if actor.velocity.y>7:manual_takeoffs+=1
	check(manual_takeoffs==3,"Releasing and pressing jump again permits each manual bunny hop")
	for i in 100:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,false)
	check(actor.is_on_floor() and actor.velocity.y<=0,"Releasing jump stops automatic hopping at the next landing")
	actor.in_water=true;actor.position.y=4;actor.velocity=Vector3(0,-12,0)
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
	check(actor.velocity.y>=-2,"Water retains bounded sinking speed")
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,true)
	check(actor.velocity.y>=5.4,"Jump input still swims upward")
	var held_swimming:=true
	for i in 15:
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,true)
		held_swimming=held_swimming and actor.velocity.y>=5.4
	check(held_swimming,"Holding jump continuously swims upward without needing another press")
	world.free()
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.active=true;game.players[1]=game._new_state("Timeout",1);game._create_fighter(1)
	game.players[1].jump=true;game.clock+=1;game._server_tick(DT)
	check(not game.players[1].jump,"Expired network input cannot keep a disconnected player bunny hopping")
	game.active=false;game.free()
	print("QUAKE_MOVEMENT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
