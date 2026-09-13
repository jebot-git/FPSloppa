extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class FailedRoutes extends RefCounted:
	func hazardous(_point: Vector3) -> bool:return false
	func path(_start: Vector3,_end: Vector3,_jump: bool) -> PackedVector3Array:return PackedVector3Array()
	func cost(_start: Vector3,end: Vector3,_route: PackedVector3Array) -> float:return 1.0 if end.x==7 else INF
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Roles",0,100,60,true,"koth");game.set_process(false);game.set_physics_process(false);Fixture.setup(game)
	var ai=game.bots
	for id in [-4,-5,-6,-7,-8]:game._add_player(id,"Bot")
	game.players[1].spectator=true
	for id in range(-8,0):
		game.players[id].team=0 if id<=-5 else 1;game.players[id].dead=false;game.players[id].spectator=false
		game.fighters[id].position=Fixture.point((id+8)*2,0);ai.brains[id]=ai.new_brain(id)
	game.match_mode.hill=Fixture.point();game.match_mode.hill_owner=-1;game.clock=10
	await physics_frame
	var holder: int=ai.objectives.nearest(-8,game.match_mode.hill,"hill")
	check(holder==-8,"Nearest live teammate occupies hill")
	game.fighters[-7].position=Fixture.point(.1,0)
	check(ai.objectives.nearest(-7,game.match_mode.hill,"hill")==holder,"Small movement does not churn holder assignment")
	game.match_mode.hill_owner=0
	var rows: Array=[];ai.mode_goals(-7,ai.brains[-7],rows)
	check(rows.size()==1 and rows[0].kind=="guard","Secured hill assigns support outside the scoring job")
	rows.clear();ai.mode_goals(holder,ai.brains[holder],rows)
	check(rows[0].kind=="objective" and rows[0].position==game.match_mode.hill,"Holder remains inside real scoring volume")
	game.players[holder].dead=true
	check(ai.objectives.nearest(-7,game.match_mode.hill,"hill")!=holder,"Holder death immediately transfers responsibility")
	game.match_mode.hill_owner=1;rows.clear();ai.mode_goals(-6,ai.brains[-6],rows)
	check(rows[0].kind=="objective" and rows[0].position.distance_to(game.match_mode.hill)<2.5,"Retake support enters scoring radius instead of camping outside")
	game.players[holder].dead=false;game.match_mode.kind="ctf";game.match_mode.bases=[Fixture.point(),Fixture.point(20,0)]
	game.match_mode.flags=[{"carrier":0,"dropped":false,"position":Fixture.point()},{"carrier":0,"dropped":false,"position":Fixture.point(20,0)}]
	var roles: Array=[]
	for id in [-8,-7,-6,-5]:
		rows.clear();ai.mode_goals(id,ai.brains[id],rows);roles.append(ai.brains[id].role)
	check(roles==["defend","support","attack","attack"],"Four-player CTF roster has one defender, one support and two attackers")
	game.players[-8].dead=true;rows.clear();ai.mode_goals(-6,ai.brains[-6],rows)
	check(ai.brains[-6].role=="attack","Death does not reshuffle every living CTF role")
	game.players[-8].dead=false;game.match_mode.flags[1].carrier=-5
	var escorts:=0
	for id in [-8,-7,-6]:
		rows.clear();ai.mode_goals(id,ai.brains[id],rows)
		if rows.any(func(row):return row.kind=="escort"):escorts+=1
	check(escorts==1,"Only one teammate follows closely while others screen the carrier or home")
	rows.clear();ai.mode_goals(-7,ai.brains[-7],rows)
	check(rows.any(func(row):return str(row.key).begins_with("carrier:screen:")),"Support teammate screens the carrier return route")
	game.match_mode.flags[1].carrier=0;game.clock=20
	var anchor:Vector3=Fixture.point(40,0)
	for id in [-8,-7,-6,-5]:game.fighters[id].position=Fixture.point(-20,0)
	game.fighters[-6].position=anchor
	ai.objectives.pushes[0]={"anchor":anchor,"arrival":-1.0,"released_until":0.0}
	rows.clear();check(ai.objectives.push_goal(-6,2,rows),"Lone attacker initially waits for its push partner")
	game.clock+=3.1;rows.clear()
	check(not ai.objectives.push_goal(-6,2,rows),"Missing push partner cannot hold an attacker beyond three seconds")
	ai.objectives.pushes[0]={"anchor":anchor,"arrival":-1.0,"released_until":0.0}
	game.fighters[-5].position=anchor+Vector3.RIGHT
	rows.clear();check(not ai.objectives.push_goal(-6,2,rows),"Two ready attackers release their push immediately")
	ai.objectives.pushes[0]={"anchor":anchor,"arrival":-1.0,"released_until":0.0}
	game.match_mode.flags[1].carrier=-6;rows.clear();ai.mode_goals(-6,ai.brains[-6],rows)
	check(rows.any(func(row):return row.kind=="capture") and not rows.any(func(row):return str(row.key).begins_with("push:")),"Flag carrier bypasses attack rendezvous")
	game.match_mode.flags[1].carrier=0;game.match_mode.flags[1].dropped=true
	rows.clear();ai.mode_goals(-6,ai.brains[-6],rows)
	check(rows.any(func(row):return row.key=="flag") and not rows.any(func(row):return str(row.key).begins_with("push:")),"Dropped flag recovery bypasses attack rendezvous")
	game.match_mode.kind="if";game.match_mode.special.frozen={-5:{}}
	var thawers:=0
	for id in [-8,-7,-6]:
		rows.clear();ai.mode_goals(id,ai.brains[id],rows)
		if rows.any(func(row):return row.kind=="thaw"):thawers+=1
	check(thawers==1,"A frozen teammate receives one assigned thawer")
	game.players[1].spectator=false;game.players[1].team=0;game.fighters[1].position=game.fighters[-5].position
	ai.objectives.leases.clear()
	check(ai.objectives.nearest(-8,game.fighters[-5].position,"thaw:-5")<0,"A nearby human is not assigned a bot-only rescue obligation")
	game.players[1].spectator=true
	game.match_mode.special.frozen.clear();game.match_mode.kind="dm"
	game.players[-8].yaw=0;game.fighters[-8].position=Fixture.point();game.fighters[-4].position=Fixture.point(0,-4)
	for id in [-7,-6,-5,-3,-2,-1]:game.players[id].spectator=true
	var brain: Dictionary=ai.new_brain(-8);ai.perceive(-8,brain);var acquired: float=brain.seen_at
	game.clock+=.3;game.players[-4].spectator=true;ai.perceive(-8,brain)
	game.clock+=.2;game.players[-4].spectator=false;ai.perceive(-8,brain)
	check(brain.enemy==-4 and brain.seen_at==acquired,"Brief loss of sight does not restart reaction delay")
	var fallback=load("res://tools/ai_study/fallback_ai.gd").new();game.add_child(fallback);fallback.game=game;fallback.teamplay.ai=fallback
	fallback.navigation=FailedRoutes.new();game.pickups=[];game.spawn_points=[]
	var rescue_brain: Dictionary=fallback.new_brain(-8);fallback.plan(-8,rescue_brain)
	check(rescue_brain.goal_key=="7" and fallback.teamplay.stats.route_queries==7,"Unreachable top six goals do not hide a reachable seventh choice")
	game.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("BOT_ROLE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
