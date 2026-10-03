extends SceneTree
## Differential tests against the retained AI, with identical world state and RNG.
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Aim=preload("res://deathmatch/bot_ai/aim.gd")
const TEAM_FIELDS=["pending","reports","report_at","reservations","yield_at","next_tick","stats","callout_at"]
var game
var bots
var checks:=0
var failures:Array=[]
var rng:=RandomNumberGenerator.new()
func _initialize():run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label);push_error(label)
func clone_brain(brain:Dictionary) -> Dictionary:
	var result:=brain.duplicate(true)
	result.aiming=Aim.new()
	for property in brain.aiming.get_property_list():
		if property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE and property.name!="rng":result.aiming.set(property.name,brain.aiming.get(property.name))
	result.aiming.rng.state=brain.aiming.rng.state
	return result
func compare(a,b,label:String) -> void:
	if a is Dictionary and b is Dictionary:
		check(a.size()==b.size(),label+" keys")
		for key in a:
			check(b.has(key),label+" has "+str(key))
			if b.has(key):compare(a[key],b[key],label+"."+str(key))
	elif a is Array or a is PackedVector3Array:
		check(a.size()==b.size(),label+" size")
		if a.size()==b.size():
			for i in a.size():compare(a[i],b[i],label+"["+str(i)+"]")
	elif a is Vector3 or a is Vector2:check(a.distance_to(b)<.00003,label+" "+str(a)+" / "+str(b))
	elif a is float or a is int:
		check(a==b or absf(float(a)-float(b))<.000003,label+" "+str(a)+" / "+str(b))
	elif a is Aim:
		for property in a.get_property_list():
			if property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE and property.name!="rng":compare(a.get(property.name),b.get(property.name),label+"."+property.name)
		check(a.rng.state==b.rng.state,label+" RNG")
	else:check(a==b,label)
func team_snapshot() -> Dictionary:
	var result:Dictionary={}
	for field in TEAM_FIELDS:result[field]=bots.teamplay.get(field)
	return result.duplicate(true)
func restore_team(snapshot:Dictionary) -> void:
	for field in TEAM_FIELDS:bots.teamplay.set(field,snapshot[field].duplicate(true) if snapshot[field] is Array or snapshot[field] is Dictionary else snapshot[field])
func run() -> void:
	rng.seed=83194
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Native bot parity",0,100,60,true,"dm");game.set_process(false);game.set_physics_process(false)
	Fixture.setup(game);bots=game.bots
	check(bots.native_ai!=null,"Native bot class loaded")
	if bots.native_ai==null:quit(1);return
	game.clock=20
	for id in game.players:
		game.players[id].invulnerable=0;game.players[id].spectator=false
		game.fighters[id].position=Fixture.point(0,0 if id==-1 else -3*(1-id))
	for frame in 10:
		await physics_frame
		for actor in game.fighters.values():actor.simulate(Vector2.ZERO,0,false,1./60)
	var actor=game.fighters[-1]
	var obstacle=Fixture.box(game,Fixture.point(0,-2)+Vector3.UP*.85,Vector3(3,.3,1))
	await physics_frame
	for trial in 300:
		actor.configure_cs16(trial%4==3)
		actor.cs16_stamina=.8 if trial%8==3 else 0.0
		game.clock=20+trial*.137
		game.match_mode.kind="tdm" if trial%3==0 else "dm"
		game.armory.select(["doom","quake","ut99","cs16"][trial%4])
		for id in game.players:
			game.players[id].team=0 if id in [-1,-3] else 1
			game.players[id].dead=trial%17==0 and id==-2
			game.players[id].spectator=trial%19==0 and id==1
			game.players[id].owned=[0,1,2,3,4,5,6,7,8,9];game.players[id].ammo=[100,100,100,100]
			game.fighters[id].position=Fixture.point(0 if id==-1 else rng.randf_range(-12,12),0 if id==-1 else rng.randf_range(-16,4))
			game.fighters[id].velocity=Vector3(rng.randf_range(-8,8),rng.randf_range(-3,3),rng.randf_range(-8,8))
		actor.in_water=trial%5==0;actor.underwater=trial%10==0;actor.jump_held=trial%7==0
		actor.position.y+=2 if trial%5==1 else 0
		seed(3000+trial)
		var brain:Dictionary=bots.new_brain(-1)
		brain.goal=Fixture.point(rng.randf_range(-18,18),rng.randf_range(-18,18));brain.goal.y+=rng.randf_range(-3,3)
		brain.goal_kind=["roam","enemy","cover","defend","guard","ambush","item","objective","search","explore","heal","repair","destroy","escort","capture"][trial%15]
		brain.goal_key="parity:"+str(trial);brain.enemy=-2 if trial%4 else 0
		brain.remembered_enemy=-2 if trial%3 else 0;brain.seen_at=game.clock-(trial%8)*.12
		brain.seen_position=game.fighters[-2].position;brain.last_seen_at=game.clock-(trial%9)*.07;brain.observed_velocity=game.fighters[-2].velocity
		brain.action_at=INF;brain.translocate_at=INF;brain.hold=trial%2==0
		brain.watch=Fixture.point(3,-6);brain.weapon_at=0 if trial%2 else game.clock+1
		if trial%11==0:brain.goal=actor.position;brain.hold=true
		if trial%4==0:brain.path=PackedVector3Array([actor.position,actor.position+Vector3(0,0,-1),brain.goal])
		if trial%7==0:brain.progress_at=game.clock-3;brain.progress_position=actor.position
		if trial%6==0:brain.dodge_until=game.clock+1;brain.dodge=Vector3.RIGHT
		if trial%9==0:brain.recover_until=game.clock+1;brain.recover_direction=Vector3.LEFT;brain.recover_jump=true;brain.recover_prone=trial%18==0
		if trial%13==0:brain.pad_until=game.clock+2;brain.pad_end=brain.goal;brain.pad_chain=trial%26==0
		if trial%17==0:brain.drop_until=game.clock+1;brain.drop_end=brain.goal
		if trial%19==0:brain.stuck=1.49;brain.last=actor.position
		game.players[-1].weapon=trial%10;game.players[-1].yaw=rng.randf_range(-PI,PI);game.players[-1].pitch=rng.randf_range(-.8,.8)
		game.variant_combat.charging={-1:{"time":.7,"alt":trial%2==0}} if trial%6==0 else {}
		for method in ["perceive","combat","steer"]:
			var original:Dictionary=game.players.duplicate(true);var team:=team_snapshot()
			var reference:=clone_brain(brain);var native:=clone_brain(brain)
			seed(90000+trial)
			if method=="perceive":bots.perceive_reference(-1,reference)
			else:bots.call(method+"_reference",-1,reference,1./60)
			var reference_players:Dictionary=game.players.duplicate(true);var reference_team:=team_snapshot();var reference_random:=randi()
			game.players=original.duplicate(true);restore_team(team);seed(90000+trial)
			if method=="perceive":bots.native_ai.perceive(bots,-1,native)
			else:bots.native_ai.call(method,bots,-1,native,1./60)
			var label:="%d %s"%[trial,method]
			check(reference_random==randi(),label+" global RNG")
			compare(reference,native,label+" brain");compare(reference_players,game.players,label+" players");compare(reference_team,team_snapshot(),label+" team")
			game.players=original;restore_team(team)
	# Reproduce a target disappearing between perception and steering (worker/human leave).
	game.match_mode.kind="dm";game.armory.select("quake")
	game.players[-1].dead=false;game.players[-1].spectator=false;game.players[-1].weapon=2
	game.fighters[-2].free();game.fighters.erase(-2);game.players.erase(-2)
	var stale:Dictionary=bots.new_brain(-1)
	stale.enemy=-2;stale.goal_kind="enemy";stale.goal=actor.position+Vector3(4,0,0)
	stale.action_at=INF;stale.translocate_at=INF
	var original:Dictionary=game.players.duplicate(true)
	var reference:=clone_brain(stale);var native:=clone_brain(stale)
	seed(7701);bots.steer_reference(-1,reference,1./60)
	var expected:Dictionary=game.players.duplicate(true)
	game.players=original;seed(7701);bots.native_ai.steer(bots,-1,native,1./60)
	compare(reference,native,"departed enemy steering brain")
	compare(expected,game.players,"departed enemy steering players")
	check(game.players[-1].move.is_finite(),"Departed target cannot crash native steering")
	obstacle.free();game.disconnect_game();game.free()
	print("NATIVE_BOTS_RESULT ",JSON.stringify({"checks":checks,"cases":900,"failures":failures}));quit(0 if failures.is_empty() else 1)
