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
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST obstacle control",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Runner");g.players[-1].team=0
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(250,1,250))
	while not g.bots.navigation.ready():await physics_frame
	for height in [1.2,12.0]:
		var wall=Fixture.box(g,Fixture.ORIGIN+Vector3(0,height*.5,-20),Vector3(12,height,1))
		var actor=g.fighters[-1];var s: Dictionary=g.players[-1];var ai=g.bots
		g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
		actor.position=Fixture.ORIGIN+Vector3.UP*.01;actor.velocity=Vector3.ZERO;actor.jump_held=false
		s.yaw=0;s.jump=false;s.ski=false;s.jet_held=false
		await physics_frame;await physics_frame
		for frame in 5:g._configure_tribes(-1,s);actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
		actor.velocity=Vector3.FORWARD*22
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b
		b.goal=Fixture.ORIGIN+Vector3.FORWARD*90;b.goal_key="obstacle-route";b.goal_kind="objective"
		b.path=PackedVector3Array([actor.position,b.goal]);b.step=0
		var crossed:=false;var stalled:=0.0;var worst_stall:=0.0;var first_correction:=-1.0;var minimum:=22.0
		for frame in 600:
			g.clock+=1.0/60;s.last_input=g.clock;ai.tribes.steer(-1,b);g._configure_tribes(-1,s)
			if first_correction<0 and b.get("travel_phase","").begins_with("obstacle_"):first_correction=actor.position.z-(Fixture.ORIGIN.z-19.5)
			actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			if "detail" in OS.get_cmdline_user_args() and frame%6==0:print("OBSTACLE_DETAIL ",height," ",frame," ",actor.position," ",actor.velocity," ",b.get("travel_phase","")," jet ",s.jet_held," jump ",s.jump)
			var speed:=Vector2(actor.velocity.x,actor.velocity.z).length();minimum=minf(minimum,speed)
			stalled=stalled+1.0/60 if speed<1 else 0.0;worst_stall=maxf(worst_stall,stalled)
			if actor.position.z<Fixture.ORIGIN.z-24:crossed=true;break
		print("OBSTACLE_REPLAY ",JSON.stringify({"height":height,"crossed":crossed,"first_correction_m":first_correction,"worst_stall":worst_stall,"minimum_speed":minimum,"position":actor.position}))
		check(first_correction>4,"%.1f m wall is anticipated before the old two-metre probe"%height)
		check(crossed and worst_stall<.5,"Runner passes %.1f m wall without a collision standstill"%height)
		wall.free();await physics_frame
	print("ST_OBSTACLE_CONTROL ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
