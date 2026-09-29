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
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Carrier recharge",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Carrier");g.players[-1].team=0
	var ramp=Fixture.box(g,Fixture.ORIGIN+Vector3(0,30,120),Vector3(140,1,50));ramp.rotation.z=deg_to_rad(20)
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	var ai=g.bots;var s: Dictionary=g.players[-1];var actor=g.fighters[-1]
	g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
	actor.position=Fixture.ORIGIN+Vector3(30,30+tan(deg_to_rad(20))*30+1,120);actor.velocity=Vector3.ZERO
	actor.configure_tribes(true);actor.jet_held=false;actor.ski_held=false
	for frame in 60:actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	actor.tribes_state.energy=5;g.match_mode.flags[1].carrier=-1
	var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b
	b.goal=Fixture.ORIGIN+Vector3(-30,30-tan(deg_to_rad(20))*30+.6,120);b.goal_kind="capture";b.goal_key="st:capture"
	b.path=PackedVector3Array([actor.position,b.goal]);b.step=0
	check(ai.tribes.offense.recharge_escape(-1,b),"Low-energy carrier enters recharge escape")
	var start: Vector3=actor.position;var jets:=0;var no_ski:=0
	for frame in 180:
		g.clock+=1.0/60;s.last_input=g.clock;ai.tribes.steer(-1,b);g._configure_tribes(-1,s)
		if s.jet_held:jets+=1
		if actor.is_supported() and not s.ski:no_ski+=1
		actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
	var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
	check(no_ski==0 and speed>13 and start.x-actor.position.x>20,"Empty carrier skis downhill to gain speed and separation")
	check(jets==0 and actor.tribes_state.energy>37,"Gravity escape recharges the real pack without an acceleration burn")
	check(ai.tribes.offense.recharge_escape(-1,b),"Recharge priority persists above entry threshold until useful reserve returns")
	actor.tribes_state.energy=40
	check(not ai.tribes.offense.recharge_escape(-1,b),"Sufficient reserve restores normal travel policy")
	actor.tribes_state.energy=3;ai.tribes.offense.recharge_escape(-1,b);g.match_mode.return_flag(1)
	check(not ai.tribes.offense.recharge_escape(-1,b),"Flag loss clears the carrier-only policy")
	print("ST_CARRIER_RECHARGE ",JSON.stringify({"checks":checks,"failures":failures,"speed_kmh":speed*3.6,"downhill_metres":start.x-actor.position.x,"jet_frames":jets}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
