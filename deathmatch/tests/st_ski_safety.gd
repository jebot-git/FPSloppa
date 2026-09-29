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
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Ski safety",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Runner");g.players[-1].team=0
	var ramp=Fixture.box(g,Fixture.ORIGIN+Vector3(0,30,120),Vector3(140,1,60));ramp.rotation.z=deg_to_rad(20)
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	var ai=g.bots;var s: Dictionary=g.players[-1];var actor=g.fighters[-1]
	g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
	actor.position=Fixture.ORIGIN+Vector3(20,30+tan(deg_to_rad(20))*20+1,120);actor.velocity=Vector3.ZERO
	actor.configure_tribes(true);actor.jet_held=false;actor.ski_held=false
	for frame in 60:actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b
	b.goal=Fixture.ORIGIN+Vector3(-35,30-tan(deg_to_rad(20))*35+.6,120);b.goal_kind="objective";b.goal_key="ski-safety";b.travel_phase="ski"
	b.path=PackedVector3Array([actor.position,b.goal]);b.step=1
	s.yaw=0;s.move=Vector2.LEFT;s.ski=false
	ai.tribes.slope_inputs(-1,b)
	check(s.ski,"Clear downhill route permits acceleration from rest")
	var path: PackedVector3Array=b.path;b.path=PackedVector3Array();s.ski=true
	ai.tribes.slope_inputs(-1,b)
	check(not s.ski,"No route cannot enable blind downhill skiing")
	b.path=path
	for phase in ["obstacle_flank","precision","base_approach","arrive","flag_catch","route_recovery"]:
		b.travel_phase=phase;s.ski=false;ai.tribes.slope_inputs(-1,b)
		check(not s.ski,"Downhill preference preserves "+phase+" traction/braking")
	b.travel_phase="ski";actor.velocity=Vector3.LEFT.slide(actor.tribes_state.normal)*24
	var barrier=Fixture.box(g,actor.position+Vector3(-12,5,0),Vector3(1,22,35))
	await physics_frame;await physics_frame;g.clock+=.2;b.erase("ski_probe");s.ski=true
	ai.tribes.slope_inputs(-1,b)
	check(not s.ski,"Wall within braking horizon disables downhill ski before contact")
	barrier.free();await physics_frame;g.clock+=.2;b.erase("ski_probe")
	actor.velocity=Vector3.BACK*22
	barrier=Fixture.box(g,actor.position+Vector3(0,5,10),Vector3(35,22,1))
	await physics_frame;await physics_frame;s.ski=true
	ai.tribes.slope_inputs(-1,b)
	check(not s.ski,"Clear intended direction cannot hide sideways momentum into a wall")
	barrier.free();await physics_frame;g.clock+=.2;b.erase("ski_probe")
	actor.velocity=Vector3.RIGHT*12;s.ski=true;ai.tribes.slope_inputs(-1,b)
	check(not s.ski,"Reversing toward a downhill route first uses steering traction")
	actor.velocity=Vector3.LEFT.slide(actor.tribes_state.normal)*16;g.clock+=.2;b.erase("ski_probe");s.ski=false
	ai.tribes.slope_inputs(-1,b)
	check(s.ski,"Skiing resumes once the route and momentum corridor are clear")
	# Exercise the actual ordering: obstacle avoidance chooses a ground flank,
	# then the final slope pass must not turn skiing back on underneath it.
	barrier=Fixture.box(g,actor.position+Vector3(-18,5,0),Vector3(1,22,12))
	await physics_frame;await physics_frame;g.clock+=.2;b.erase("ski_probe")
	actor.velocity=Vector3.LEFT.slide(actor.tribes_state.normal)*24
	var flanks:=0;var unsafe_ski:=0
	for frame in 240:
		g.clock+=1.0/60;s.last_input=g.clock;ai.tribes.steer(-1,b)
		if actor.is_supported() and b.get("travel_phase","")=="obstacle_flank":
			flanks+=1
			if s.ski:unsafe_ski+=1
		g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
	check(flanks>0 and unsafe_ski==0,"Full downhill controller keeps walking traction throughout its obstacle flank")
	barrier.free()
	for armour in ["light","medium","heavy"]:
		g.match_mode.tribes.apply_equipment(-1,armour,[3,2,0],"energy")
		actor.position=Fixture.ORIGIN+Vector3(-20,30-tan(deg_to_rad(20))*20+1,120);actor.velocity=Vector3.ZERO;actor.jump_held=false
		s.yaw=0;actor.jet_held=false;actor.ski_held=false
		for frame in 60:actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
		var profile: Dictionary=g.match_mode.tribes.definition(-1)
		actor.velocity=Vector3.RIGHT.slide(actor.tribes_state.normal)*profile.walk*1.25
		b.goal=actor.position+Vector3(50,20,0);b.path=PackedVector3Array([actor.position,b.goal]);b.step=1;b.travel_phase="run_up"
		s.move=Vector2.RIGHT;s.jet_held=false;s.jump=false;actor.tribes_state.energy=profile.energy
		ai.tribes.slope_inputs(-1,b)
		var wish:=Basis(Vector3.UP,s.yaw)*Vector3(s.move.x,0,s.move.y)
		var acceleration=preload("res://deathmatch/movement/tribes.gd").jet_acceleration(actor.velocity,wish,.256,armour)
		check(s.jet_held and s.jump and acceleration.y>20,"Slope-triggered "+armour+" launch reserves enough real jet thrust to oppose gravity")
		actor.tribes_state.energy=profile.energy*.1;s.move=Vector2.RIGHT;s.jet_held=false;s.jump=false
		ai.tribes.slope_inputs(-1,b)
		check(not s.jet_held and not s.jump and not s.ski,"Nearly empty "+armour+" pack walks/recharges instead of starting a futile hop")
	print("ST_SKI_SAFETY ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
