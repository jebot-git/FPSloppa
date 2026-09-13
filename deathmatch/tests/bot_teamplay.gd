extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var bots
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	seed(7129)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Team AI tests",0,100,60,true,"tdm");game.set_physics_process(false);game.set_process(false)
	bots=game.bots;Fixture.setup(game)
	for id in game.players:
		game.players[id].team=0 if id in [-1,-2] else 1
		game.players[id].spectator=false;game.players[id].dead=false;game.players[id].invulnerable=0
		game.players[id].hp=100;game.players[id].yaw=0;game.players[id].armor=0
		game.players[id].tf_class="soldier"
	game.players[-3].spectator=true
	game.fighters[-1].position=Fixture.point()
	game.fighters[-2].position=Fixture.point(12,0)
	game.fighters[1].position=Fixture.point(0,-10)
	game.clock=10
	var team=bots.teamplay
	var brain: Dictionary=bots.new_brain(-1);bots.brains[-1]=brain
	var receiver: Dictionary=bots.new_brain(-2);bots.brains[-2]=receiver
	await physics_frame
	bots.perceive(-1,brain)
	check(brain.enemy==1 and team.intel(-2).is_empty(),"A sighting is not relayed instantly")
	game.clock+=.2;team.tick()
	check(team.intel(-2).is_empty(),"Radio delay applies before delivery")
	game.clock+=.2;team.tick();bots.perceive(-2,receiver)
	check(team.intel(-2).size()==1 and receiver.enemy==0,"Occluded teammate receives information without acquiring a hidden firing target")
	var known: Vector3=team.intel(-2)[0].position
	game.fighters[1].position=Fixture.point(1,-12)
	check(team.intel(-2)[0].position==known,"Enemy movement does not update a relayed snapshot")
	var rows: Array=[];bots.mode_goals(-2,receiver,rows);team.goals(-2,receiver,rows)
	check(rows.any(func(row):return row.kind=="assist" and row.position==known),"Teammate investigates the reported position")
	bots.combat(-2,receiver)
	check(not game.players[-2].fire and not game.players[-2].alt_fire,"Relayed information cannot fire through a wall")
	game.players[-3].spectator=false;game.fighters[-3].position=Fixture.point(2,-7)
	game.fighters[-2].position=Fixture.point(2,0);game.fighters[1].position=Fixture.point(0,-10)
	await physics_frame;bots.perceive(-2,receiver)
	check(receiver.enemy==1 and team.stats.get("focus_choices",0)>0,"Teammates concentrate fire on the reported visible enemy")
	game.fighters[-3].position=Fixture.point(2,-1.5)
	await physics_frame;bots.perceive(-2,receiver)
	check(receiver.enemy==-3,"Immediate close-range threat overrides a distant focus-fire call")
	check(team.intel(-3).is_empty(),"Enemy team cannot read friendly radio reports")
	game.players[1].serial+=1
	check(team.intel(-2).is_empty(),"Respawn invalidates reports about the previous life")
	game.players[1].serial-=1;game.clock+=4;team.tick()
	check(team.reports.is_empty(),"Stale reports expire")
	# Voluntary supply sharing is exercised through the real collection code.
	game.players[1].spectator=true;game.players[-3].spectator=true
	game.fighters[-1].position=Fixture.point();game.fighters[-2].position=Fixture.point(0,-2)
	game.players[-1].hp=90;game.players[-2].hp=15
	var pickup: Dictionary={"kind":"health","item":25,"position":Fixture.point(0,-1),"available":true,"respawn":0.0}
	game.pickups=[pickup]
	await physics_frame
	check(team.consider_pickup(-1,pickup) and team.pickup_owner(-1,pickup)==-2,"Nearby critical-health ally gets first choice of a pickup")
	game._collect(-1)
	check(pickup.available and game.players[-1].hp==90,"Bot actually leaves the pickup untouched when walking within collection range")
	game._collect(-2)
	check(not pickup.available and game.players[-2].hp==40,"Ally collects the offered health through normal pickup rules")
	pickup.available=true;game.players[-1].hp=1
	check(not team.leaving_pickup(-1,pickup),"A more urgent survival need overrides pickup courtesy")
	game.players[-1].hp=90;game.players[-2].team=1
	check(not team.leaving_pickup(-1,pickup),"Changing teams cancels an outstanding offer")
	game.players[-2].team=0;game.clock+=4.2;team.tick()
	check(not team.leaving_pickup(-1,pickup) and not team.consider_pickup(-1,pickup),"Ignored offers expire and cannot be renewed indefinitely")
	game.clock+=6;game.players[1].spectator=false;game.players[1].team=0;game.players[1].hp=5
	game.players[-2].hp=100;game.fighters[1].position=Fixture.point(1,-1)
	await physics_frame
	check(team.consider_pickup(-1,pickup) and team.pickup_owner(-1,pickup)==1,"Bots also offer pickups to human teammates")
	game._collect(1)
	check(game.players[1].hp==30 and not pickup.available,"Human pickup collection is unrestricted")
	# Cover is a separated firing position; ally interaction stays uninterrupted.
	game.players[1].team=1;game.players[1].hp=100;game.fighters[1].position=Fixture.point(0,-12)
	game.fighters[-2].position=Fixture.point(0,-3);game.players[-2].hp=20;game.players[-1].hp=100
	brain.enemy=1;brain.seen_position=game.fighters[1].position;brain.visible=[1]
	await physics_frame
	rows=[];bots.mode_goals(-1,brain,rows);team.goals(-1,brain,rows)
	var guards: Array=rows.filter(func(row):return row.kind=="guard" and row.support==-2)
	check(not guards.is_empty() and guards[0].position.distance_to(game.fighters[-2].position)>2,"Healthy teammate covers a vulnerable ally from a separate firing lane")
	if not guards.is_empty():
		check(bots.navigation.ray(guards[0].position+Vector3.UP*1.5,brain.seen_position+Vector3.UP).is_empty(),"Cover position can actually see the threat")
	game.players[-2].hp=100
	for interaction in ["thaw","heal","repair","checkpoint","destroy"]:
		receiver.goal_kind=interaction;rows=[];team.goals(-1,brain,rows)
		check(rows.any(func(row):return row.kind=="guard" and row.support==-2),"Teammate provides cover during "+interaction)
	receiver.goal_kind="roam";game.players[-2].hp=20
	for mode in ["tdm","ctf","tf","ft","if","koth","as"]:
		game.match_mode.kind=mode
		rows=[];bots.mode_goals(-1,brain,rows);team.goals(-1,brain,rows)
		check(rows.any(func(row):return row.kind=="guard"),"Vulnerable-ally cover works in "+mode)
	game.match_mode.kind="ctf";game.match_mode.flags[1].carrier=-2
	rows=[];bots.mode_goals(-1,brain,rows)
	var escorts: Array=rows.filter(func(row):return row.kind=="escort")
	check(not escorts.is_empty() and escorts[0].position.distance_to(game.fighters[-2].position)>2,"Carrier escort uses a formation offset rather than blocking the carrier")
	game.match_mode.flags[1].carrier=-1
	rows=[];bots.mode_goals(-1,brain,rows);team.goals(-1,brain,rows)
	check(rows.any(func(row):return row.kind=="capture") and not rows.any(func(row):return row.kind in ["guard","ambush"]),"Flag carrier keeps capture priority instead of taking a support job")
	game.match_mode.flags[1].carrier=0
	# Low cover provides an actual occluded ambush, with a timeout and orientation.
	game.players[-2].hp=100;game.players[1].spectator=true;brain.enemy=0;brain.visible=[];brain.role="defend"
	var anchor: Vector3=Fixture.point(-8,-8)
	game.match_mode.flags[0].position=anchor
	Fixture.box(game,anchor+Vector3(2.5,.4,0),Vector3(.7,.8,3))
	await physics_frame
	var spot: Dictionary=team.firing_point(-1,anchor,anchor,true)
	check(not spot.is_empty(),"Ambush search finds partial cover with a clear standing firing lane")
	if not spot.is_empty():
		rows=[];bots.candidate(rows,"defend","defend",anchor,95,true);team.goals(-1,brain,rows)
		var ambushes: Array=rows.filter(func(row):return row.kind=="ambush")
		check(not ambushes.is_empty(),"Defender selects an ambush near its objective")
		if not ambushes.is_empty():
			var chosen: Dictionary=ambushes[0];team.selected(-1,brain,chosen)
			brain.goal_kind="ambush";brain.goal=chosen.position;brain.goal_key="ambush";brain.hold=true;brain.path=PackedVector3Array()
			game.fighters[-1].position=brain.goal;game.players[-1].yaw=0
			bots.steer(-1,brain,.1)
			check(game.players[-1].crouch and game.players[-1].move.length()<.01,"Ambusher waits quietly at cover instead of running in place")
			check(brain.watch==anchor,"Ambusher watches the objective approach")
			game.clock+=7.1;rows=[];bots.candidate(rows,"defend","defend",anchor,95,true);team.goals(-1,brain,rows)
			check(not rows.any(func(row):return row.kind=="ambush"),"Ambush expires and enters cooldown when nobody arrives")
	game.match_mode.kind="dm"
	check(team.intel(-1).is_empty() and not team.consider_pickup(-1,pickup),"Free-for-all modes do not share team intelligence or supplies")
	game.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("BOT_TEAMPLAY_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
