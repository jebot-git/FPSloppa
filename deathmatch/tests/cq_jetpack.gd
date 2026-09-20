extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Jet=preload("res://deathmatch/conquest/jetpack.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Delivery=preload("res://deathmatch/network/input_delivery.gd")
const State=preload("res://deathmatch/server/districts/state.gd")
var failures: Array=[]
var measurements: Array=[]
var checks:=0
var actor
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func reset(at: Vector3=Vector3(0,.02,0)) -> void:
	actor.position=at;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.jump_held=false;actor.jump_queued=false;actor.stepped_last_frame=false;actor.reset_view();actor.reset_jetpack();actor.configure_jetpack(true);actor.update_height(1.65,true)
	for i in 4:actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
func press(wish: Vector2,dt: float) -> void:
	actor.simulate(wish,0,false,dt,true)
	for i in maxi(1,roundi(.12/dt)):actor.simulate(wish,0,false,dt,false)
	actor.simulate(wish,0,false,dt,true)
func _initialize():run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,-.5,0),Vector3(600,1,600))
	actor=Fighter.new();actor.setup(1,"Jetpack",Color.WHITE);actor.quake_movement=true;world.add_child(actor)
	await physics_frame;await physics_frame
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz
		await physics_frame;await physics_frame
		var dt: float=1.0/hz;reset();press(Vector2.RIGHT,dt)
		check(actor.jetpack_state.mode==1,"Double press starts moving flight at %d Hz"%hz)
		var start: Vector3=actor.position;var top: float=actor.position.y;var last: Vector3=actor.position;var travel:=0.0;var duration:=0.0
		while actor.jetpack_state.mode!=0 and duration<8:
			actor.simulate(Vector2.RIGHT,0,false,dt,false);duration+=dt;top=maxf(top,actor.position.y);travel+=Vector2(actor.position.x-last.x,actor.position.z-last.z).length();last=actor.position
		check(actor.jetpack_state.mode==0 and actor.is_supported(),"Flight lands normally at %d Hz"%hz)
		check(top>5.8 and top<8.0 and travel>20 and travel<=50,"Curved boost rises and travels under 50 m at %d Hz"%hz)
		measurements.append({"hz":hz,"apex_metres":top,"horizontal_metres":travel,"air_seconds":duration})
		var activation: int=actor.jetpack_state.activation;press(Vector2.RIGHT,dt)
		check(actor.jetpack_state.activation==activation,"Cooldown denies another boost at %d Hz"%hz)
		while actor.jetpack_state.cooldown>0:actor.simulate(Vector2.ZERO,0,false,dt,false)
		for i in hz:actor.simulate(Vector2.ZERO,0,false,dt,false)
		press(Vector2.RIGHT,dt);check(actor.jetpack_state.activation==activation+1,"Fresh double press works after 8 second cooldown at %d Hz"%hz)
	Engine.physics_ticks_per_second=60
	await physics_frame;await physics_frame
	reset();actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	for i in 90:actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(actor.jetpack_state.activation==0,"Holding jump remains an ordinary jump")
	reset();actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	for i in 30:actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	actor.simulate(Vector2.ZERO,0,false,1.0/60,true);check(actor.jetpack_state.activation==0,"Separate jumps beyond 300 ms do not activate")
	reset();press(Vector2.ZERO,1.0/60);var start: Vector3=actor.position
	var heights: Array=[]
	for i in 100:
		actor.simulate(Vector2.RIGHT,0,false,1.0/60,false)
		if actor.jetpack_state.age>.8 and actor.jetpack_state.age<1.4:heights.append(actor.position.y)
	check(heights.size()>20 and heights.max()-heights.min()<.01 and heights[0]>2,"Stationary boost lifts and briefly hovers")
	check(Vector2(actor.position.x-start.x,actor.position.z-start.z).length()<.01,"Hover remains in place even with later movement input")
	reset();press(Vector2.RIGHT,1.0/60)
	for i in 30:actor.simulate(Vector2.LEFT,0,false,1.0/60,false)
	check(absf(Vector2.RIGHT.angle_to(actor.jetpack_state.heading))<=deg_to_rad(9.1),"Air control cannot instantly reverse the launch direction")
	reset(Vector3(0,100,0));press(Vector2.RIGHT,1.0/60);start=actor.position
	for i in 600:
		if actor.jetpack_state.mode==0:break
		actor.simulate(Vector2.RIGHT,0,false,1.0/60,false)
	check(actor.jetpack_state.distance<=Jet.RANGE+.01 and actor.position.x-start.x<=50,"High ledge does not turn boost into unlimited horizontal flight")
	reset(Vector3(0,100,0));press(Vector2.RIGHT,1.0/60);actor.jetpack_state.distance=47.95;start=actor.position
	for i in 90:actor.simulate(Vector2.RIGHT,0,false,1.0/60,false)
	check(actor.position.x-start.x<.06 and actor.jetpack_state.distance<=48.001,"Actual path budget stops thrust at the range cap")
	# Loss of both press packets: repeat the double-tap action through the existing
	# life-scoped delivery channel. The server still decides cooldown/mode legality.
	reset();var delivery:=Delivery.new();delivery.sample({"jump":true},3,0);delivery.sample({"jump":false},3,.05);delivery.sample({"jump":true},3,.12)
	var packet:={"jump":false};delivery.annotate(packet,.16)
	var state:={"serial":3,"dead":false,"spectator":false,"jump":false};Delivery.accept(state,packet)
	actor.simulate(Vector2.RIGHT,0,false,1.0/60,Delivery.consume(state,actor))
	check(actor.jetpack_state.activation==1 and state.jetpack_ack==1,"Lost press/release packets still deliver exactly one boost")
	Delivery.accept(state,packet);Delivery.consume(state,actor);check(not actor.jetpack_requested,"Retransmission cannot queue a second boost")
	state.serial=4;Delivery.accept(state,packet);Delivery.consume(state,actor);check(not actor.jetpack_requested,"Old-life boost cannot replay after respawn")
	for disabled in ["mode","blocked","water","prone","spectator","frozen"]:
		reset();actor.configure_jetpack(disabled!="mode",disabled=="blocked");actor.in_water=disabled=="water";actor.spectator=disabled=="spectator";actor.frozen=disabled=="frozen"
		if disabled=="prone":actor.update_height(.65,true)
		press(Vector2.RIGHT,1.0/60);check(actor.jetpack_state.activation==0,"Boost rejected while "+disabled)
		actor.in_water=false;actor.spectator=false;actor.frozen=false
	# Late authority cannot erase a newer predicted boost.
	reset();var authority: Dictionary=actor.jetpack_state.duplicate(true);actor.prediction.remember(1,actor.position,actor.velocity,1.65,authority)
	press(Vector2.RIGHT,1.0/60);var local: Dictionary=actor.jetpack_state.duplicate(true)
	Jet.reconcile(actor,authority,authority);check(actor.jetpack_state==local,"Delayed pre-launch snapshot preserves newer predicted boost")
	Jet.reconcile(actor,authority,local);check(actor.jetpack_state.mode==0,"Authority can deny an acknowledged predicted boost")
	reset();press(Vector2.RIGHT,1.0/60)
	# Transfer schema serializes the complete relative-time flight state.
	var copy:=Fighter.new();copy.setup(2,"Copy",Color.WHITE);copy.quake_movement=true;world.add_child(copy)
	check(State.BODY.has("jetpack_state") and State.BODY.has("jetpack_enabled"),"Worker transfer schema includes boost and cooldown")
	copy.jetpack_state=actor.jetpack_state.duplicate(true);copy.jetpack_enabled=true;copy.position=actor.position+Vector3(0,0,20);copy.velocity=actor.velocity
	for i in 20:actor.simulate(Vector2.RIGHT,0,false,1.0/60,false);copy.simulate(Vector2.RIGHT,0,false,1.0/60,false)
	check(copy.position.distance_to(actor.position+Vector3(0,0,20))<.001 and absf(copy.jetpack_state.cooldown-actor.jetpack_state.cooldown)<.001,"Transferred flight continues with the same trajectory and cooldown")
	copy.free()
	var wall:=Fixture.box(world,Vector3(8,8,0),Vector3(.3,16,30));var ceiling:=Fixture.box(world,Vector3(-30,3,0),Vector3(15,.3,15))
	await physics_frame;await physics_frame
	reset();press(Vector2.RIGHT,1.0/60)
	for i in 150:actor.simulate(Vector2.RIGHT,0,false,1.0/60,false)
	check(actor.position.x<7.56,"Boost collides with walls instead of tunnelling")
	reset(Vector3(-30,.02,0));press(Vector2.ZERO,1.0/60);var max_height:=0.0
	for i in 150:actor.simulate(Vector2.ZERO,0,false,1.0/60,false);max_height=maxf(max_height,actor.position.y)
	check(max_height<1.3 and actor.is_supported(),"Low ceiling stops lift safely and hover still ends")
	actor.configure_jetpack(false);check(actor.jetpack_state.mode==0 and actor.jetpack_state.cooldown==0,"Leaving CQ clears flight state")
	world.free();await process_frame
	DirAccess.make_dir_recursive_absolute("res://test-results/cq-jetpack")
	var report:={"checks":checks,"failures":failures,"flights":measurements};FileAccess.open("res://test-results/cq-jetpack/physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CQ_JETPACK_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
