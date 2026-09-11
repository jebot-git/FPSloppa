extends SceneTree
var game
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var path: String=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-as-test.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map=key
	game.start_host("Assault test",0,20,7,true,"as")
	check(game.active,"AS map starts")
	if not game.active:finish();return
	await physics_frame;await physics_frame
	for attempt in 1200:
		if game.bots.ready_to_walk:break
		await create_timer(.05).timeout
	check(game.bots.ready_to_walk,"Navigation bake completes")
	for id in game.players:game.players[id].spectator=true
	var state: Dictionary=game.players[1];state.spectator=false;state.dead=false;state.team=0
	var rules=game.match_mode.assault;var fortress=game.match_mode.fortress
	var actor=game.fighters[1]
	check(state.weapon==2 and state.owned==[2] and state.hp==100,"AS uses normal pistol-only spawn and 100 HP")
	check(not fortress.enabled() and fortress.speed(1)==1.0 and not fortress.select_class(1,"engineer"),"Classes and class abilities are unavailable in AS")
	check(fortress.buildings.size()==3,"Three defender-owned map sentries exist")
	rules.tick(.02);check(is_equal_approx(rules.budget,420),"First attack gets configured seven-minute budget")
	actor.position=rules.objectives[1].position;rules.tick(.02)
	check(rules.stage==0,"Final console is locked until first objective")
	state.team=1;actor.position=rules.objectives[0].position;rules.tick(.02)
	check(rules.stage==0,"Defenders cannot activate attacker objectives")
	state.team=0;state.dead=true;rules.tick(.02)
	check(rules.stage==0,"Dead attackers cannot activate objectives")
	state.dead=false;state.spectator=true;rules.tick(.02)
	check(rules.stage==0,"Spectators cannot activate objectives")
	state.spectator=false
	game._use_for(1)
	check(not game.gates[0].open,"Use cannot bypass the locked cabin door")
	rules.tick(.02);check(rules.stage==1,"Live attacker activates upper switch")
	check(game.gates[0].open and game.gates[0].until>game.clock+420,"Switch opens the cabin door for the rest of the assault")
	game._spawn(1);check(rules.stage==1,"Activated switch survives attacker respawn")
	# Checkpoint updates persist and change roles' respawn locations independently.
	for row in game.map_assault:
		if row.kind=="info_as_checkpoint" and int(row.checkpoint)==2:actor.position=row.position
	rules.tick(.02)
	check(rules.checkpoint==2 and rules.spawns(0)[0].distance_to(game.ctf_spawns[0][0])>50,"Front checkpoint advances attack spawns")
	test_all_sentries()
	# Reuse real shared hit tests, blast damage and enemy-only sentry targeting.
	state.invulnerable=0;state.hp=100;state.armor=0;state.team=0
	var gun: Dictionary=fortress.buildings[100001]
	actor.position=gun.position+Vector3(0,0,-3)
	game.clock=10;fortress.tick(.5)
	check(state.hp<100,"Sentry damages a visible attacker using production damage")
	state.team=1;state.hp=100;game.clock=11;fortress.tick(.5)
	check(state.hp==100,"Sentry does not shoot its defending team")
	var trace: Dictionary=fortress.trace(gun.position+Vector3(0,1,-3),gun.position+Vector3(0,1,3),1.0)
	check(not trace.is_empty(),"Sentry participates in shared weapon hit detection")
	state.team=0;fortress.damage_building(100001,1,150)
	check(not fortress.buildings.has(100001),"Sentry can be destroyed")
	game.round_left=360;actor.position=rules.objectives[1].position;rules.tick(.02)
	check(rules.switching and rules.first_finished and is_equal_approx(rules.first_time,60),"First completion records a 60-second target and switches roles")
	var kills: int=state.kills
	rules.next_leg()
	check(rules.attacking==1 and rules.leg==1 and rules.stage==0 and rules.checkpoint==0 and is_equal_approx(game.round_left,60),"Return attack gets exactly the first team's completion time")
	check(fortress.buildings.size()==3 and fortress.buildings[100001].team==0 and not game.gates[0].open,"Sentries and door reset for the new defenders")
	check(state.team==0 and state.kills==kills,"Team identities and frag statistics persist across role swap")
	state.team=1;state.dead=false;actor.position=rules.objectives[0].position;rules.tick(.02)
	game.round_left=10;actor.position=rules.objectives[1].position;rules.tick(.02)
	check(rules.finished and game.match_mode.scores==[0,1],"Faster second attack wins the paired assault")
	# Held-defense and draw cases, without geometry shortcuts.
	game.intermission=0;game.match_mode.reset();rules.budget=420;game.round_left=0;rules.timeout()
	check(rules.switching and not rules.first_finished,"First timeout still grants the other team an attack")
	rules.next_leg();check(is_equal_approx(game.round_left,420),"Failed first attack grants the full budget")
	game.round_left=0;rules.timeout()
	check(rules.finished and game.match_mode.scores==[0,0],"Neither team completing produces a draw")
	game.intermission=0;game.match_mode.reset();rules.budget=420;game.round_left=350;rules.complete_leg(true);rules.next_leg();game.round_left=0;rules.timeout()
	check(game.match_mode.scores==[1,0],"First team wins when the return attack times out")
	var copy=load("res://deathmatch/modes/match.gd").new();copy.game=game;copy.assault.setup(copy);copy.fortress.setup(copy);copy.receive(game.match_mode.snapshot())
	check(copy.kind=="as" and copy.assault.finished and copy.assault.attacking==1 and copy.fortress.buildings.size()==3,"Objective, role and sentry state survives snapshot replication")
	copy.fortress.free()
	check(not game.Maps.supports_assault("res://maps/lqdm1.bsp"),"Ordinary maps do not advertise AS support")
	var config=load("res://deathmatch/server/config.gd").parse('set sv_gametype "as"\nset as_maplist "tf_hispeed_concept"')
	check(not config.has("error") and config.values.mode_maps.as==["tf_hispeed_concept"],"Dedicated configuration accepts AS and its separate maplist")
	finish()
func finish() -> void:
	print("ASSAULT_RESULT ",JSON.stringify({"failures":failures}))
	game.free();quit(0 if failures.is_empty() else 1)

# Probe each authored emplacement independently through the production targeting
# and damage path. Floor/capsule checks ensure targets are actual playable space.
func test_all_sentries() -> void:
	var fortress=game.match_mode.fortress
	var saved: Dictionary=fortress.buildings.duplicate(true)
	var state: Dictionary=game.players[1]
	var actor=game.fighters[1]
	var original_position: Vector3=actor.position
	var space=game.get_world_3d().direct_space_state
	var reports: Array=[]
	for key in saved:
		var gun: Dictionary=saved[key].duplicate(true)
		fortress.buildings={key:gun}
		var muzzle: Vector3=gun.position+Vector3.UP*1.1
		var visible: Array[Vector3]=[]
		var blocked: Array[Vector3]=[]
		for dx in range(-12,13,2):
			for dz in range(-12,13,2):
				if Vector2(dx,dz).length()<2:continue
				var top: Vector3=gun.position+Vector3(dx,3,dz)
				var floor_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*7,1))
				if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
				var feet: Vector3=floor_hit.position+Vector3.UP*.05
				var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new()
				capsule.height=1.65;capsule.radius=.30;q.shape=capsule;q.collision_mask=1;q.margin=.001;q.transform.origin=feet+Vector3.UP*.83
				if not space.intersect_shape(q).is_empty():continue
				var target:=feet+Vector3.UP*.9
				if muzzle.distance_to(target)>=18:continue
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle,target,1)).is_empty():visible.append(feet)
				else:blocked.append(feet)
		check(not visible.is_empty(),"Sentry %s has a capsule-clear grounded firing lane"%key)
		check(not blocked.is_empty(),"Sentry %s has a grounded occlusion control"%key)
		var hits:=0
		for feet in visible:
			actor.position=feet;state.team=1-int(gun.team);state.dead=false;state.spectator=false;state.invulnerable=0;state.hp=100;state.armor=0
			game.clock+=1;gun.ready=0;gun.next=0;fortress.tick_sentries()
			if state.hp==88:hits+=1
		check(hits==visible.size() and hits>0,"Sentry %s deals 12 damage at every visible probe (%s/%s)"%[key,hits,visible.size()])
		var wall_hits:=0
		for feet in blocked:
			actor.position=feet;state.hp=100;game.clock+=1;gun.next=0;fortress.tick_sentries()
			if state.hp!=100:wall_hits+=1
		check(wall_hits==0,"Sentry %s cannot shoot through map solids"%key)
		if not visible.is_empty():
			actor.position=visible[0];state.team=int(gun.team);state.hp=100;game.clock+=1;gun.next=0;fortress.tick_sentries()
			check(state.hp==100,"Sentry %s protects defenders"%key)
			state.team=1-int(gun.team);state.spectator=true;game.clock+=1;gun.next=0;fortress.tick_sentries()
			check(state.hp==100,"Sentry %s ignores spectators"%key)
			state.spectator=false;state.invulnerable=game.clock+10;gun.next=0;fortress.tick_sentries()
			check(state.hp==100,"Sentry %s respects spawn protection"%key)
			state.invulnerable=0;state.dead=true;gun.next=0;fortress.tick_sentries()
			check(state.hp==100,"Sentry %s ignores dead players"%key)
			state.dead=false;gun.next=0;fortress.tick_sentries();var hp: int=state.hp
			game.clock+=.25;fortress.tick_sentries();check(state.hp==hp,"Sentry %s observes firing cooldown"%key)
			game.clock+=.26;fortress.tick_sentries();check(state.hp==hp-12,"Sentry %s fires again after cooldown"%key)
			gun.team=1-int(gun.team);state.team=1-int(gun.team);state.hp=100;game.clock+=1;gun.next=0;fortress.tick_sentries()
			check(state.hp==88,"Sentry %s hits the opposite attacker after role swap"%key)
		reports.append({"id":key,"position":str(gun.position),"visible_probes":visible.size(),"hits":hits,"occluded_probes":blocked.size(),"wall_hits":wall_hits})
	fortress.buildings=saved;actor.position=original_position;state.team=0;state.spectator=false;state.dead=false;state.invulnerable=0
	FileAccess.open("res://test-results/hispeed-sentries.json",FileAccess.WRITE).store_string(JSON.stringify({"map_sha256":FileAccess.get_sha256(OS.get_cmdline_user_args()[0]),"sentries":reports},"  "))
