extends "res://deathmatch/tests/weapon_variants.gd"
var measurements: Dictionary={}
func arm(seconds: float) -> void:
	g.players[1].fire=true
	for i in ceili(seconds*60):
		g.clock+=1.0/60;g.players[1].last_input=g.clock
		g.variant_combat.tick_input(1,1.0/60)
func ready_actor() -> void:
	reset("ut99",0)
	g.players[1].hp=100;g.players[1].shots=0;g.players[1].jump=false
	g.fighters[-1].position=Fixture.point(8,8)
	var actor=g.fighters[1]
	actor.blast_velocity=Vector2.ZERO;actor.jump_held=false;actor.jump_queued=false
	actor.in_water=false;actor.floor_grace=0
	g.players[1].pitch=-PI/2
	for i in 3:
		await physics_frame
		actor.simulate(Vector2.ZERO,0,false,1.0/Engine.physics_ticks_per_second,false)
func apex() -> float:
	var actor=g.fighters[1]
	var height: float=actor.position.y-Fixture.ORIGIN.y
	for i in Engine.physics_ticks_per_second*3:
		await physics_frame
		actor.simulate(Vector2.ZERO,0,false,1.0/Engine.physics_ticks_per_second,false)
		height=maxf(height,actor.position.y-Fixture.ORIGIN.y)
		if actor.velocity.y<=0:break
	return height
func release(jump: bool) -> void:
	g.players[1].fire=false;g.players[1].jump=jump;g.players[1].last_input=g.clock
	g._server_tick(1.0/Engine.physics_ticks_per_second)
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	await physics_frame
	g.start_host("Impact jump",0,100,60,true);g.bots.free();g.bots=null
	g.set_physics_process(false);g.set_process(false)
	await ready_actor()
	g.players[1].jump=true;g._server_tick(1.0/Engine.physics_ticks_per_second)
	measurements.normal_apex=await apex()
	await ready_actor();arm(3.5)
	check(g.variant_combat.charging.has(1) and g.players[1].shots==0 and g.players[1].hp==100,"Full charge stays held against floor beyond charge limit")
	check(is_equal_approx(g.variant_combat.charging[1].time,1.5),"Held charge remains capped")
	release(true)
	check(g.players[1].shots==1 and g.variant_combat.charging.is_empty(),"Jump and release fire exactly once")
	check(g.players[1].hp==64 and g.players[1].ammo==[200,100,100,300],"Primary surface strike costs 36 health and no ammo")
	check(g.fighters[1].velocity.y>18,"Hammer impulse stacks with same-frame jump")
	measurements.charged_apex=await apex()
	check(measurements.charged_apex>measurements.normal_apex*4,"Charged impact jump reaches substantially higher than normal jump")
	await ready_actor();arm(.2);release(true)
	measurements.partial_apex=await apex()
	check(measurements.partial_apex>measurements.normal_apex and measurements.partial_apex<measurements.charged_apex,"Partial charge provides a smaller usable jump")
	await ready_actor();arm(2);release(false)
	measurements.no_jump_apex=await apex()
	check(measurements.no_jump_apex<measurements.charged_apex and measurements.no_jump_apex>measurements.normal_apex,"Jump timing adds height over ground discharge alone")
	await ready_actor();g.players[1].pitch=PI/2;arm(2);release(false)
	check(g.players[1].hp==100 and g.fighters[1].velocity.y<=0,"Air miss gives no self damage or free impulse")
	await ready_actor();g.players[1].armor=100;arm(2);release(true)
	check(g.players[1].armor<100 and g.players[1].hp>64 and g.fighters[1].velocity.y>18,"Armor absorbs normal self damage without weakening launch")
	await ready_actor();g.players[1].hp=20;arm(2);release(true)
	check(g.players[1].dead,"Insufficient health makes impact jump lethal")
	await ready_actor();arm(2);g.players[1].input_blocked=true;release(true)
	check(g.players[1].hp==100 and g.players[1].shots==0,"Blocked input cancels charge without discharge")
	await ready_actor();arm(2);g.clock+=1;g.players[1].fire=false;g.variant_combat.tick_input(1,.1)
	check(g.players[1].hp==100 and g.players[1].shots==0 and g.variant_combat.charging.is_empty(),"Stale connection cancels the held hammer")
	await ready_actor();arm(2);g.players[1].weapon=2;g.variant_combat.tick_input(1,.1)
	check(g.players[1].hp==100 and g.variant_combat.charging.is_empty(),"Switching weapon cancels the held hammer")
	await ready_actor();g.fighters[1].position=Fixture.point(9,0);g.players[1].yaw=-PI/2;g.players[1].pitch=0
	arm(2);release(false)
	check(g.players[1].hp==64 and g.fighters[1].velocity.x < -10 and g.fighters[1].velocity.y>4,"Wall strike pushes away and lifts grounded player")
	await ready_actor();g.players[1].pitch=0;g.fighters[-1].position=Fixture.point(0,-1)
	g.variant_combat.fire(1,false,1.5)
	check(g.players[-1].hp<2000 and g.players[1].hp==100 and g.fighters[1].velocity.length()<1,"Enemy hit damages target without surface-jump recoil")
	await ready_actor();g.players[1].pitch=0;g.fighters[-1].position=Fixture.point(0,-2.2)
	g.variant_combat.fire(1,false,1.5)
	check(g.players[-1].hp==2000 and g.players[1].hp==100,"Extended surface reach does not extend melee damage or jump off distant players")
	await ready_actor();g.players[1].pitch=0;g.fighters[-1].position=Fixture.point(0,-.65);arm(1.2)
	check(g.players[-1].hp<2000 and g.players[1].shots==1,"Charged piston discharges on close enemy contact")
	await ready_actor();g.variant_combat.fire(1,true)
	check(g.players[1].hp<100 and g.players[1].hp>64 and g.fighters[1].velocity.y>0 and g.fighters[1].velocity.y<8,"Alternate floor strike has a smaller distance-scaled jump and cost")
	await ready_actor()
	var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
	pose.right.origin=Vector3(.25,.6,-.3);pose.weapon=Transform3D(Basis(Vector3.RIGHT,-PI/2),pose.right.origin)
	g.players[1].vr_device=true;g.players[1].xr=pose;arm(2);release(true)
	check(g.players[1].hp==64 and g.fighters[1].velocity.y>18,"Tracked-hand downward aim retains impact jump")
	print("IMPACT_JUMP_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements}))
	g.disconnect_game();g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
