extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var tf
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func role(id: int,name: String) -> void:
	g.players[id].tf_next=name;g._spawn(id);g.players[id].invulnerable=0;g.players[id].cooldown=0;tf.cooldowns[id]=0
func _initialize():call_deferred("run")
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("Tester",0,5,10,true,"tf");g.bots.free();g.bots=null;g.set_physics_process(false);tf=g.match_mode.fortress
	check(g.match_mode.kind=="tf" and g.match_mode.team_game(),"TF selectable and assigns teams")
	g.players[1].team=0;g.players[-1].team=1;g.players[-2].team=0;g.players[-3].team=1
	for name in tf.CLASSES:
		role(1,name);var data: Dictionary=tf.CLASSES[name]
		check(g.players[1].hp==data.hp and g.players[1].armor==data.armor and g.players[1].owned==data.owned,"Class loadout "+name)
		check(is_equal_approx(tf.speed(1),data.speed),"Class movement "+name)
		check(is_equal_approx(g.fighters[1].get_child(0).shape.radius,.30),"Unified hitbox "+name)
	role(1,"soldier");g.players[1].hp=20
	check(tf.select_class(1,"medic") and g.players[1].hp==20 and g.players[1].tf_class=="soldier","Class selection queues without healing")
	check(not tf.select_class(1,"administrator") and not tf.select_class(999,"scout"),"Invalid/unauthenticated class requests rejected")
	g._spawn(1);check(g.players[1].tf_class=="medic" and g.players[1].hp==110,"Queued class applied on respawn")
	role(1,"sniper");check(tf.weapon_data(1,9).damage==90,"TF rail is not instagib")
	check(tf.action(1) and tf.weapon_data(1,9).damage==150,"Sniper focus changes damage and movement")
	check(not tf.action(1),"Ability cooldown enforced")
	g.players[1].ammo[0]=1;check(not tf.can_fire(1,9),"TF rail requires two bullets")
	g.players[1].ammo[0]=200;g.players[1].armor=200;tf.resupply(1,1);check(g.players[1].ammo[0]==200 and g.players[1].armor==200,"Resupply never removes collected armor or ammo")
	role(1,"heavy");tf.action(1);check(tf.incoming_damage(1,100,"SHOTGUN",false)==65,"Heavy brace reduces combat damage")
	check(tf.incoming_damage(1,1000,"fall",true)==1000,"Brace cannot block hazards")
	role(1,"medic");role(-2,"soldier");g.players[-2].hp=40
	for id in g.players:g.fighters[id].position=Fixture.point(12,12)
	g.fighters[1].position=Fixture.point(0,4);g.players[1].yaw=0;g.players[1].pitch=0;g.fighters[-2].position=Fixture.point(0,0)
	check(tf.action(1) and g.players[-2].hp==75,"Medic heals aimed teammate")
	tf.cooldowns[1]=0;g.players[-2].team=1
	check(not tf.action(1),"Medic cannot heal an enemy")
	role(1,"spy");g.avatars.choices[-2]={"hash":g.avatars.library.selected,"size":1}
	check(tf.action(1) and not tf.cloaked(1) and not g.players[1].tf_disguise.is_empty(),"Default Spy copies enemy identity without invisibility")
	check(tf.display_avatar(1,"")==g.avatars.library.selected,"Disguise reuses validated custom/default VRM")
	tf.incoming_damage(1,5,"PISTOL",false);check(not tf.cloaked(1) and g.players[1].tf_disguise.is_empty(),"Damage reveals spy and restores avatar identity")
	tf.cooldowns[1]=0;tf.action(1);g.players[1].melee=true;g.players[1].last_input=g.clock;g.players[1].melee_state.clear();g._update_melee_hand(1,false)
	check(not tf.cloaked(1) and not g.players[1].tf_disguise.is_empty(),"Missed physical melee preserves Spy disguise")
	g.players[1].melee=false
	tf.cooldowns[1]=0;g.match_mode.flags[1].carrier=1
	check(not tf.action(1),"Flag carrier cannot cloak")
	g.match_mode.flags[1].carrier=0
	role(1,"pyro");check(tf.weapon_data(1,7).range==8 and tf.weapon_data(1,7).name=="FLAMETHROWER","Pyro uses short-range flame weapon")
	role(-1,"soldier");tf.ignite(-1,1);check(tf.burns.has(-1),"Enemy ignition")
	role(1,"engineer");g.players[1].team=0;g.fighters[1].position=Fixture.point(0,4);g.players[1].yaw=0;g.players[1].pitch=0
	for id in [-1,-2,-3]:g.fighters[id].position=Fixture.point(12,12)
	g.spawn_points=[Fixture.point(-12,12),Fixture.point(12,12)];g.match_mode.bases=g.spawn_points.duplicate()
	await physics_frame
	check(tf.action(1) and tf.buildings.size()==1,"Engineer builds sentry on clear visible floor")
	if not tf.buildings.is_empty():
		var key: int=tf.buildings.keys()[0];tf.cooldowns[1]=0
		check(not tf.action(1),"One sentry per engineer")
		tf.damage_building(key,-1,500);check(tf.buildings.is_empty(),"Enemy fire destroys sentry")

	await test_grenades()

	var objective_calls: Array=[]
	g.announcer.cue_received.connect(func(cue,_target):
		if cue=="objective_completed":objective_calls.append(cue)
	)
	# TF captures are independent of the home flag; defenders wait for timed returns.
	for id in g.players:g.fighters[id].position=Fixture.point(-15,-15)
	g.players[1].team=0;g.fighters[1].position=Fixture.point(0,0)
	g.match_mode.bases=[Fixture.point(0,0),Fixture.point(0,12)];g.match_mode.captures=g.match_mode.bases.duplicate()
	g.match_mode.return_flag(0);g.match_mode.return_flag(1)
	g.match_mode.flags[0].dropped=true;g.match_mode.flags[0].return_at=g.clock+30
	g.match_mode.tick(.01);check(g.match_mode.flags[0].dropped,"TF defenders cannot touch-return own flag")
	g.match_mode.flags[1].carrier=1;var old_score: int=g.match_mode.scores[0]
	g.match_mode.tick(.01);check(g.match_mode.scores[0]==old_score+1,"TF captures while own flag is away")
	check(objective_calls.size()==1,"TF flag capture announces objective completed exactly once")
	var before: Dictionary=g.match_mode.snapshot();tf.receive(before.fortress)
	check(g.players[1].tf_class=="engineer","Snapshot preserves class state")
	g.match_mode.kind="dm";check(tf.speed(1)==1 and tf.weapon_data(1,9).damage==10000,"Other modes retain original speed and weapon data")
	print("FORTRESS_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)

func test_grenades() -> void:
	for id in g.players:
		g.fighters[id].set_physics_process(false)
		g.fighters[id].position=Fixture.point(-15,-15)
	for name in ["soldier","demoman","pyro"]:
		role(1,name);g.fighters[1].position=Fixture.point(0,4);g.players[1].yaw=0;g.players[1].pitch=0
		await physics_frame
		var origin: Vector3=g._shot_origin(1)
		check(tf.action(1),name+" throws a grenade")
		if not tf.charges.has(1):continue
		var start: Vector3=tf.charges[1].position
		check(start.distance_to(origin)<.4 and tf.charges[1].velocity.length()>10,name+" starts at weapon with launch velocity")
		var before_v: float=tf.charges[1].velocity.y
		g.clock+=.1;tf.tick_charges(.1)
		check(tf.charges.has(1) and tf.charges[1].position.distance_to(start)>1 and tf.charges[1].velocity.y<before_v,name+" travels under gravity")
		if name=="demoman":
			check(not tf.action(1),"Pipe cannot detonate before arming")
			check(tf.status(1).contains("USE DETONATE PIPE:") and not tf.status(1).contains("READY"),"HUD names the pending pipe detonation and arming countdown")
			var snapshot: Dictionary=tf.snapshot();var server_clock: float=g.clock
			var expected: float=tf.ability_state(1).remaining
			g.clock=server_clock+500;tf.receive(snapshot)
			check(absf(tf.ability_state(1).remaining-expected)<.001,"Pipe arming indicator survives different server/client clocks")
			g.clock=server_clock;tf.charges.clear()
			tf.cooldowns[1]=0;tf.action(1);g.clock+=.71
			check(tf.status(1).contains("DETONATE PIPE: READY"),"HUD shows armed pipe ready without waiting for throw cooldown")
			check(tf.action(1) and not tf.charges.has(1),"Armed pipe detonates through Use and resets cooldown")
			check(tf.ability_state(1).remaining>7.9,"Pipe detonation starts eight-second cooldown")
		else:
			g.clock+=1.21;tf.tick_charges(.01)
			check(not tf.charges.has(1),name+" fuse removes projectile and detonates")
	# A thin wall catches a fast grenade even with a large simulation step.
	role(1,"soldier");g.fighters[1].position=Fixture.point(8,0);g.players[1].yaw=-PI/2;g.players[1].pitch=0
	await physics_frame
	check(tf.action(1),"Wall-bounce grenade launches")
	if tf.charges.has(1):
		g.clock+=.2;tf.tick_charges(.2)
		check(tf.charges.has(1) and tf.charges[1].position.x<Fixture.ORIGIN.x+9.88 and tf.charges[1].velocity.x<0,"Swept grenade bounces off thin wall without tunnelling")
	tf.charges.clear()
	# Impact with an opposing player detonates before the timed fuse.
	role(1,"soldier");role(-1,"soldier");g.players[-1].team=1;g.players[1].team=0
	g.fighters[1].position=Fixture.point(0,4);g.players[1].yaw=0;g.players[1].pitch=0;g.fighters[-1].position=Fixture.point(0,1)
	g.players[-1].armor=0;var health: int=g.players[-1].hp
	await physics_frame
	check(tf.action(1),"Impact grenade launches")
	for step in 20:g.clock+=.02;tf.tick_charges(.02)
	check(not tf.charges.has(1) and g.players[-1].hp<health,"Grenade player impact detonates and applies authoritative damage")
	role(1,"soldier");g.players[1].ammo[2]=0
	check(not tf.action(1) and not tf.charges.has(1),"Grenades require ammunition")
	g.players[1].ammo[2]=3;g.players[1].dead=true
	check(not tf.action(1),"Dead players cannot throw grenades")
	g.players[1].dead=false;g.players[1].spectator=true
	check(not tf.action(1),"Spectators cannot throw grenades")
	g.players[1].spectator=false;role(1,"engineer")
