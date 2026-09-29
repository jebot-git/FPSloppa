extends SceneTree
const Capture=preload("res://deathmatch/bot_ai/tribes_capture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	check(Capture.ready(18,30,60,.8),"Fast charged homeward approach is ready")
	check(not Capture.ready(9,60,60,1),"Charge alone cannot replace entry speed")
	check(not Capture.ready(25,8,60,1),"Speed alone cannot replace escape fuel")
	check(not Capture.ready(20,40,60,-.8),"Fast approach requiring a reversal is not ready")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_stonehenge"
	g.start_host("Capture readiness",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for id in [-1,-2,-3]:g._add_player(id,"Readiness %d"%id)
	while not g.bots.navigation.ready():await physics_frame
	g.clock=100
	var ai=g.bots;var policy=ai.tribes.capture;var rules=g.match_mode.tribes
	for id in [-1,-2,-3]:
		g.players[id].team=0 if id!=-3 else 1;rules.apply_equipment(id,"light",[3,2,0],"energy")
		ai.brains[id]=ai.new_brain(id);g.fighters[id].position=Vector3(0,300,id*100)
	var b: Dictionary=ai.brains[-1];var actor=g.fighters[-1];var flag: Vector3=g.match_mode.bases[1]
	b.goal=flag;b.goal_key="st:flag";b.goal_kind="objective"
	var homeward: Vector3=(g.match_mode.bases[0]-flag);homeward.y=0;homeward=homeward.normalized()
	actor.position=flag-homeward*35+Vector3.UP*3;actor.velocity=homeward*18;actor.tribes_state.energy=55
	b.visible=[-3];g.fighters[-3].position=flag
	var rows: Array=[];policy.goal(-1,b,rows)
	check(rows.any(func(row):return row.key=="st:flag") and b.capture_readiness.ready,"Prepared Light selects the flag under opposition")
	check(policy.launch_allowed(-1,b,true),"Fast charged entry can commit without stopping for another run-up")
	actor.velocity=Vector3.ZERO;actor.tribes_state.energy=5;rows=[];policy.goal(-1,b,rows)
	check(b.capture_preparing and b.capture_decision=="prepare","Slow empty Light prepares a run-up instead of treating itself as ready")
	check(not policy.launch_allowed(-1,b),"Low-energy run-up cannot commit to shelf flight")
	g.clock+=46;rows=[];policy.goal(-1,b,rows)
	check(not rows.any(func(row):return row.key=="st:flag") and not b.capture_preparing,"Failed preparation changes objective after a bounded interval")
	rows=[];policy.goal(-1,b,rows)
	check(not rows.any(func(row):return row.key=="st:flag"),"Support interval prevents immediate retry cycles")
	b.erase("capture_defer_until");b.capture_prepare_at=g.clock-46;b.tower={"phase":"flight"};rows=[];policy.goal(-1,b,rows)
	check(rows.any(func(row):return row.key=="st:flag") and b.capture_decision=="committed","Fuel spent during an airborne crossing does not reverse the bot")
	b.erase("tower");b.erase("capture_prepare_at");rules.apply_equipment(-1,"heavy",[3,2,0],"energy")
	check(not policy.context(-1,b).allowed,"Unsupported Heavy does not volunteer for contested capture")
	rules.apply_equipment(-1,"medium",[3,2,0],"energy")
	check(not policy.context(-1,b).allowed,"Unsupported Medium also favours support")
	actor.position=Vector3(0,300,0);g.fighters[-2].position=actor.position+(g.match_mode.bases[0]-actor.position).normalized()*12
	g.fighters[-2].velocity=homeward*20;g.fighters[-2].tribes_state.energy=55
	check(policy.context(-1,b).allowed and policy.receiver(-1)==-2,"Healthy charged nearby Light enables a relay grab")
	g.fighters[-2].tribes_state.energy=2
	check(policy.receiver(-1)==0,"Exhausted Light does not justify handing off the escape")
	g.fighters[-2].tribes_state.energy=55;g.players[-2].hp=20
	check(policy.receiver(-1)==0,"Critically injured Light does not justify a relay grab")
	g.players[-2].hp=100;rules.apply_equipment(-2,"medium",[3,2,0],"energy")
	check(policy.receiver(-1)==0,"Another Medium is not treated as the faster Light receiver")
	rules.apply_equipment(-2,"light",[3,2,0],"energy")
	g.players[-2].dead=true
	check(policy.receiver(-1)==0,"Dead ally cannot justify a relay attempt")
	g.players[-2].dead=false;g.fighters[-2].position=Vector3(0,300,200)
	b.visible=[];actor.position=flag+Vector3(2,0,0)
	check(policy.context(-1,b).alone and policy.context(-1,b).allowed,"Medium alone at an apparently clear stand can make an opportunistic grab")
	g.match_mode.flags[1].dropped=true;rows=[];policy.goal(-1,b,rows)
	check(rows.size()==1 and rows[0].key=="st:flag" and b.capture_decision=="recover_drop","Dropped flag recovery is not blocked by stand-readiness rules")
	print("ST_CAPTURE_READINESS ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
