extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var checks:=0
var failures: Array=[]
var g
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	for map in preload("res://deathmatch/modes/defusal_maps.gd").IDS:
		seed(7129);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
		g.max_clients=16;g.selected_map=map;g.start_host("DE behavior regression",0,20,60,true,"de")
		g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true
		for id in [-1,-2,-3]:g._peer_left(id)
		for i in 12:g._add_player(-1000-i,"Bot "+str(i));g.players[-1000-i].team=i%2
		var de=g.match_mode.defusal;de.reset();de.tick(0)
		while not g.bots.ready_to_walk or not g.bots.navigation.ready():await physics_frame
		for id in g.players:
			if id<0:g.bots.brains[id]=g.bots.new_brain(id);de.bot_input(id)
		g.clock=de.phase_end;de.tick(0)
		for i in 4:
			var defending:=0
			for id in g.bots.brains:
				g.bots.plan(id,g.bots.brains[id])
				if de.role(id)==1 and g.bots.brains[id].goal_key.begins_with("de:site:"):defending+=1
				elif de.role(id)==1:
					var rows: Array=[];de.bot_goals(g.bots,id,rows)
					print("DE_ROUTE_DIAGNOSTIC ",map," ",id," at=",g.fighters[id].position," rows=",rows," nav=",NavigationServer3D.map_get_closest_point(g.bots.region.get_navigation_map(),rows[0].position)," clear=",g.bots.navigation.landing_clear(rows[0].position))
			check(defending==6,map+": all six CTs retain site routes, planning pass "+str(i+1))
		g.disconnect_game();g.free();await process_frame
	# Exercise ordinary perception and weapon authority while a bot is busy.
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("DE interaction regression",0,20,60,true,"de")
	g.set_process(false);g.set_physics_process(false);Fixture.setup(g)
	for id in [1,-3]:g.players[id].spectator=true;g.fighters[id].position=Fixture.point(18,18)
	var de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0)
	de.sites=[Fixture.point(),Fixture.point()];de.site_bounds=[AABB(Fixture.point(-2,-2)-Vector3.UP*.1,Vector3(4,4,4))]
	for id in [-1,-2]:
		g.players[id].dead=false;g.players[id].spectator=false;g.players[id].hp=10000;g.players[id].invulnerable=0;g.players[id].armor=0
		g.players[id].owned=[0,6];g.players[id].weapon=6;g.players[id].ammo=[60,0,90,0]
		g.fighters[id].velocity=Vector3.ZERO
	g.players[-1].team=de.attacking;g.players[-2].team=1-de.attacking
	g.fighters[-1].position=Fixture.point();g.fighters[-2].position=Fixture.point(0,-4);g.players[-1].yaw=0
	await physics_frame;await physics_frame
	de.carrier=0;de.bomb_position=Fixture.point()+Vector3.UP*.2
	check(de.recover_bomb(-1),"Bot recovers a teammate's dropped bomb")
	de.sites=[Fixture.point(0,-12),Fixture.point(0,-12)]
	g.bots.brains[-1]=g.bots.new_brain(-1);de.bot_input(-1)
	check(de.carrier==-1 and not de.held and not de.combat_blocked(-1),"Recovered bomb is stowed on chest while traveling; gun is usable")
	de.sites=[Fixture.point(),Fixture.point()];de.held=true;de.arm_index=2
	g.bots.brains[-1].next=0
	g.bots.tick(1.0/60)
	check(g.bots.brains[-1].enemy==-2 and not de.held and de.arm_index==0,"Perception interrupts planting and releases the gun")
	var shots: int=g.players[-1].shots
	for i in 90:
		await physics_frame;g.clock+=1.0/60
		g.bots.tick(1.0/60);g.players[-1].cooldown=maxf(0,g.players[-1].cooldown-1.0/60);g.variant_combat.cs.tick_input(-1,1.0/60)
	check(g.players[-1].shots>shots,"Interrupted planter fires real weapon shots at the visible enemy")
	g.players[-1].team=1-de.attacking;g.players[-2].team=de.attacking
	de.carrier=0;de.planted=true;de.bomb_position=Fixture.point()+Vector3.UP*.15;de.fuse_end=g.clock+45
	de.defuser=-1;de.account(-1).kit=true;de.account(-1).tool=true;de.cut_mask=1
	g.bots.brains[-1].next=0;g.bots.tick(1.0/60)
	check(de.defuser==0 and not de.account(-1).tool and de.cut_mask==0 and not de.combat_blocked(-1),"Threatened defuser puts cutters away and resets partial defusal")
	g.players[-2].spectator=true;g.bots.brains[-1]=g.bots.new_brain(-1)
	de.defuser=-1;de.account(-1).tool=true;g.fighters[-1].position=Fixture.point(0,8)
	de.bot_input(-1)
	check(de.defuser==0 and not de.account(-1).tool and not de.combat_blocked(-1),"Leaving defuse range cannot strand bot with its gun holstered")
	g.fighters[-1].position=Fixture.point();g.bots.brains[-1]=g.bots.new_brain(-1)
	for i in 3:g.clock+=.7;de.bot_input(-1)
	check(de.phase=="post" and de.cut_mask==7,"Once the threat clears, bot resumes and completes shared-authority defusal")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/de-bot-review/regression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DE_BOT_BEHAVIOR_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
