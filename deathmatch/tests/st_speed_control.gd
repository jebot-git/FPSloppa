extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	seed(9302);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST speed control",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Runner")
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(500,1,500))
	while not g.bots.navigation.ready():await physics_frame
	for initial_speed in [11.0,28.0]:
		var ai=g.bots;var s: Dictionary=g.players[-1];var actor=g.fighters[-1]
		s.team=0;s.dead=false;s.yaw=0;s.pitch=0;s.jump=false;s.jet_held=false;s.ski=false
		g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
		actor.position=Fixture.ORIGIN+Vector3.UP*12;actor.velocity=Vector3.FORWARD*initial_speed;actor.jump_held=false
		var brain: Dictionary=ai.new_brain(-1);ai.brains[-1]=brain
		brain.goal=Fixture.ORIGIN+Vector3.FORWARD*180;brain.goal_key="speed-route";brain.goal_kind="objective"
		brain.path=PackedVector3Array([actor.position,Fixture.ORIGIN+Vector3.FORWARD*32,Fixture.ORIGIN+Vector3.FORWARD*64,Fixture.ORIGIN+Vector3.FORWARD*96,brain.goal]);brain.step=0
		var landed:=false;var landing_speed:=0.0;var lowest_energy:=60.0
		for frame in 240:
			g.clock+=1.0/60;s.last_input=g.clock;ai.tribes.steer(-1,brain);g._configure_tribes(-1,s)
			actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			lowest_energy=minf(lowest_energy,actor.tribes_state.energy)
			if not landed and actor.is_supported():landed=true;landing_speed=Vector2(actor.velocity.x,actor.velocity.z).length()
		var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
		print("SPEED_REPLAY ",JSON.stringify({"initial":initial_speed,"final":speed,"landing":landing_speed,"progress":Fixture.ORIGIN.z-actor.position.z,"lowest_energy":lowest_energy}))
		check(landed,"Open flight reaches a real supported landing at initial speed %.0f"%initial_speed)
		if initial_speed<15:
			check(speed>14 and Fixture.ORIGIN.z-actor.position.z>55,"Ordinary directional jets accelerate the walking-speed approach")
			check(lowest_energy<55 and lowest_energy>0,"Forward acceleration consumes real jet energy")
		else:check(speed>26 and landing_speed>26,"Ski input preserves an existing fast landing without a walking clamp")
	# Real slope with the full controller: downhill travel must not hit the
	# walking cap, and a low-energy climb must still use walking traction.
	var ramp=Fixture.box(g,Fixture.ORIGIN+Vector3(0,30,120),Vector3(140,1,50));ramp.rotation.z=deg_to_rad(20)
	await physics_frame;await physics_frame
	for descending in [true,false]:
		var ai=g.bots;var s: Dictionary=g.players[-1];var actor=g.fighters[-1]
		g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"none")
		var x: float=30 if descending else -30
		actor.position=Fixture.ORIGIN+Vector3(x,30+tan(deg_to_rad(20))*x+1,120);actor.velocity=Vector3.ZERO
		actor.configure_tribes(true);actor.jet_held=false;actor.ski_held=false
		for frame in 60:actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
		actor.tribes_state.energy=0 if not descending else 60
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b
		b.goal=Fixture.ORIGIN+Vector3(-x,30-tan(deg_to_rad(20))*x+.6,120);b.goal_kind="objective";b.goal_key="slope-route"
		b.path=PackedVector3Array([actor.position,b.goal]);b.step=0
		var start: Vector3=actor.position;var no_ski:=0;var seconds: float=3 if descending else 1
		for frame in int(seconds*60):
			g.clock+=1.0/60;s.last_input=g.clock;ai.tribes.steer(-1,b);g._configure_tribes(-1,s)
			if descending and actor.is_supported() and not s.ski:no_ski+=1
			actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
		if descending:check(no_ski==0 and start.x-actor.position.x>20 and Vector2(actor.velocity.x,actor.velocity.z).length()>13,"Downhill controller keeps skiing and accelerates beyond walking speed")
		else:check(actor.position.x-start.x>5 and actor.position.y>start.y+1.5,"Empty pack climbs a clear slope with walking traction while recharging")
	print("ST_SPEED_CONTROL ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
