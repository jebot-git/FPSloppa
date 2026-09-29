extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	seed(9304);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST carrier priorities",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for id in range(-1,-7,-1):g._add_player(id,"Focus %d"%id);g.players[id].team=0 if id==-1 else 1
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(300,1,300))
	Fixture.box(g,Fixture.ORIGIN+Vector3(3,2,-3),Vector3(.5,4,18))
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame;await physics_frame
	var ai=g.bots;var st=ai.tribes;var s: Dictionary=g.players[-1];var actor=g.fighters[-1]
	g.clock=101;g.match_mode.bases[0]=Fixture.ORIGIN+Vector3.FORWARD*100
	g.match_mode.return_flag(0);g.match_mode.flags[1].carrier=-1
	g.match_mode.tribes.apply_equipment(-1,"light",[0,2,3],"energy");s.hp=20;s.tribes_kit=false
	actor.position=Fixture.ORIGIN+Vector3.UP*.01;actor.velocity=Vector3.FORWARD*18
	var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.role="capper"
	b.goal=g.match_mode.bases[0];b.goal_key="st:capture";b.goal_kind="capture";b.hold=true
	b.path=PackedVector3Array([actor.position,b.goal]);b.step=0;b.route_at=g.clock+20
	b.enemy=-2;b.visible=[-2,-3,-4,-5,-6];b.last_seen_at=g.clock
	for id in b.visible:g.fighters[id].position=Fixture.ORIGIN+Vector3(0,0,-20+id)
	b.seen_position=g.fighters[-2].position
	var covers: Array=[];ai.cover_goals(-1,b,covers)
	check(not covers.is_empty(),"Pressure fixture provides nearby generic combat-cover candidates")
	ai.plan(-1,b)
	check(b.goal_key=="st:capture","Injured surrounded carrier keeps delivery over combat cover or ally support")
	if "plan-only" in OS.get_cmdline_user_args():finish();return
	b.enemy=-2;b.visible=[-2];b.last_seen_at=g.clock;b.seen_at=g.clock-1;b.reaction=0;b.observed_velocity=Vector3.ZERO
	b.seen_position=actor.position+Vector3.BACK*70;g.fighters[-2].position=b.seen_position
	check(not st.offense.travel_defence(-1,b),"Distant pursuer does not start a carrier duel")
	s.yaw=PI;s.pitch=0;b.equipment_target=0;b.equipment_aim_until=g.clock+1
	ai.combat(-1,b,1.0/60);st.steer(-1,b)
	check(not s.fire and b.equipment_target==-1 and b.equipment_aim_until==0,"Carrier clears optional equipment targeting and declines distant fire")
	check(st.route_look(-1,b),"Carrier navigation regains its view between defensive shots")
	var world: Vector3=Basis(Vector3.UP,s.yaw)*Vector3(s.move.x,0,s.move.y)
	check(world.z<0,"Looking away from a distant enemy preserves homeward movement")
	b.seen_position=actor.position+Vector3.FORWARD*25
	check(st.offense.travel_defence(-1,b),"Enemy directly in the escape lane allows defensive fire")
	b.seen_position=actor.position+Vector3.RIGHT*8
	check(st.offense.travel_defence(-1,b),"Immediate side threat still allows self-defence")
	b.seen_position=actor.position+Vector3.BACK*25
	var firing:=0
	for frame in 210:
		g.clock=105+frame/60.0;b.last_seen_at=g.clock
		if st.offense.travel_defence(-1,b):firing+=1
	check(firing>=30 and firing<45,"Pursuer permits a bounded defensive burst during a 3.5-second escape")
	b.last_seen_at=g.clock-1
	check(not st.offense.travel_defence(-1,b),"Stale observations do not sustain carrier return fire")
	actor.tribes_state.energy=25
	check(not st.offense.carrier_weapon(-1,0) and st.offense.carrier_weapon(-1,2),"Carrier preserves jet reserve and can still use ammunition weapons")
	actor.tribes_state.energy=60
	check(st.offense.carrier_weapon(-1,0) and not st.offense.carrier_weapon(-1,5),"Surplus permits a blaster shot but not an energy-emptying laser shot")
	# Hold a visible side enemy while steering and firing on a real floor.
	# Neither the combat yaw nor movement conversion may reverse the escape.
	actor.position=Fixture.ORIGIN+Vector3.UP*.01;actor.velocity=Vector3.FORWARD*18;s.yaw=0;s.pitch=0
	var start: Vector3=actor.position;var minimum:=18.0
	for frame in 120:
		g.clock+=1.0/60;s.last_input=g.clock;b.last_seen_at=g.clock
		b.seen_position=actor.position+Vector3(8,0,-4);g.fighters[-2].position=b.seen_position
		ai.combat(-1,b,1.0/60);st.steer(-1,b);g._configure_tribes(-1,s)
		actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
		minimum=minf(minimum,Vector2(actor.velocity.x,actor.velocity.z).length())
	check(start.z-actor.position.z>34 and minimum>17,"Two seconds of defensive combat retains ski speed and homeward displacement")
	g.match_mode.return_flag(1);actor.velocity=Vector3.FORWARD*20;b.role="capper";b.goal_kind="objective";b.goal_key="st:flag"
	b.seen_position=actor.position+Vector3.BACK*70;b.last_seen_at=g.clock
	b.equipment_target=0;b.equipment_aim_until=g.clock+1
	ai.combat(-1,b,1.0/60)
	check(b.travel_focus and not s.fire and b.equipment_target==-1,"Fast non-carrier also preserves travel over distant combat and optional equipment")
	g.match_mode.flags[1].carrier=-1;actor.velocity=Vector3.ZERO;b.goal_key="st:capture";b.goal_kind="capture";b.goal=actor.position+Vector3.FORWARD*100
	b.path=PackedVector3Array([actor.position,b.goal]);b.step=1;b.erase("tower");b.erase("st_recovery")
	var memory: Dictionary=st.tactics.record(-1);memory.watches.clear();var recoveries: int=memory.recoveries
	for frame in 20:g.clock+=.5;st.tactics.watch(-1,b,memory)
	check(memory.recoveries>recoveries,"Stationary carrier requests recovery within ten seconds")
	b.erase("st_recovery");b.goal_key="st:hold";b.goal_kind="st_hold";b.goal=actor.position;memory.watches.clear();recoveries=memory.recoveries
	for frame in 40:g.clock+=.5;st.tactics.watch(-1,b,memory)
	check(memory.recoveries==recoveries,"Intentional home-flag hold stays exempt from stopped-carrier recovery")
	finish()
func finish():
	print("ST_CARRIER_FOCUS ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
