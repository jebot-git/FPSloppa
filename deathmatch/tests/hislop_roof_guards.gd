extends SceneTree
var game
var failures: Array=[]
var measurements: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func point(x: float,y: float,z: float,tiny: bool=false) -> Vector3:
	return Vector3(-y*(1.0 if tiny else 1.25),z,-x*(1.0 if tiny else 1.75))/32.0
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="as_hislop";game.start_host("Roof defence",0,100,60,true,"as")
	game.bots.free();game.bots=null;game.set_physics_process(false);game.set_process(false)
	for id in game.players.keys():
		if id!=1:game.players[id].spectator=true
	for tiny in [false,true]:
		game._load_map("as_hislop_tiny" if tiny else "as_hislop");game.match_mode.reset()
		await physics_frame;await physics_frame
		var base: Array=game.map_assault.filter(func(r):return not r.has("fpsloppa_roof_guard")).duplicate(true)
		var first_guard: int=100000+base.filter(func(r):return r.kind=="info_as_sentry").size()
		for extra in [0,1,2]:
			game.map_assault=base.duplicate(true)
			for p in [Vector3(1728,128,320),Vector3(1952,-112,320)].slice(0,extra):
				game.map_assault.append({"kind":"info_as_sentry","position":point(p.x,p.y,p.z,tiny)+Vector3.UP*.05})
			for armor in [0,150]:
				for approach in ["straight","left","right"]:
					var start:=point(1504,0,320,tiny) if approach=="straight" else point(1696,-144 if approach=="left" else 144,320,tiny)
					var end:=point(1824,0,320,tiny)
					var duration:=start.distance_to(end)/8.0
					prepare(armor)
					var damage:=0;var hp_before:=100;var armour_before: int=armor
					for frame in ceili(duration*60):
						game.clock+=1.0/60.0;game.fighters[1].position=start.lerp(end,minf(1.0,float(frame+1)/60.0/duration));game.match_mode.fortress.tick_sentries()
						if game.players[1].dead:break
					damage=hp_before+armour_before-game.players[1].hp-game.players[1].armor
					measurements.append({"tiny":tiny,"extra_turrets":extra,"armor":armor,"approach":approach,"exposure_seconds":snappedf(duration,.01),"damage":damage,"remaining_hp":game.players[1].hp})
			prepare(0);game.players[1].team=1-game.match_mode.assault.attacking
			game.fighters[1].position=point(1784,0,320,tiny)
			for i in 180:game.clock+=1.0/60.0;game.match_mode.fortress.tick_sentries()
			check(game.players[1].hp==100,"Roof guards spare defenders (%s, +%d)"%["tiny" if tiny else "default",extra])
			if extra==2:
				prepare(0);game.fighters[1].position=point(2016,64,144,tiny)
				# Test only additional roof turrets for interior occlusion.
				for key in game.match_mode.fortress.buildings.keys():
					if key<first_guard:game.match_mode.fortress.buildings.erase(key)
				for i in 180:game.clock+=1.0/60.0;game.match_mode.fortress.tick_sentries()
				check(game.players[1].hp==100,"Roof guards cannot fire through the objective-room roof")
				prepare(0);game.players[1].hp=1000
				game.fighters[1].position=point(1680,128,320,tiny)
				var target: Vector3=game.match_mode.fortress.buildings[first_guard].position+Vector3.UP*.7
				var origin: Vector3=game.fighters[1].position+Vector3.UP*1.45
				var aim: Vector3=(target-origin).normalized()
				game.players[1].merge({"weapon":6,"owned":[0,2,6],"ammo":[50,0,20,0],"yaw":atan2(-aim.x,-aim.z),"pitch":asin(aim.y),"xr":{},"vr_device":false},true)
				for shot in 2:
					game.players[1].cooldown=0;check(game.variant_combat.fire(1),"Attacker can fire a UT rocket along the roof")
					for step in 100:game._update_projectiles(.01)
				check(not game.match_mode.fortress.buildings.has(first_guard),"Two ordinary UT rockets can clear the first roof guard")
				game.match_mode.assault.next_leg()
				check(game.match_mode.fortress.buildings.values().all(func(b):return b.team==0 and b.hp==150),"Roof guards reset and change teams after role swap")
	check(measurements.filter(func(r):return r.extra_turrets==2 and r.armor==0).all(func(r):return r.damage>=48 and r.remaining_hp>0),"Two guards threaten all tested roof approaches without an automatic full-health kill")
	print("HISLOP_ROOF_GUARDS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"measurements":measurements}))
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
func prepare(armor: int) -> void:
	game.match_mode.assault.attacking=0;game.match_mode.assault.install_sentries()
	for b in game.match_mode.fortress.buildings.values():b.ready=0;b.next=0;b.scan_at=0
	game.players[1].merge({"team":0,"dead":false,"spectator":false,"hp":100,"armor":armor,"tier":2,"invulnerable":0.0,"input_blocked":false,"cooldown":0.0},true)
