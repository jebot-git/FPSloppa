extends SceneTree
var game
var failures: Array=[]
var checks:=0
var routes: Array=[]
func _initialize() -> void:run.call_deferred()
func q(x: float,y: float,z: float=0) -> Vector3:return Vector3(-y,z,-x)/32.0+Vector3.UP*.05
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func route(points: Array,swim: bool=false,dive: bool=false) -> bool:
	var actor=game.fighters[1];var runtime=game.get_node("Map/MapRuntime")
	for target in points:
		var reached:=false
		for frame in 600:
			await physics_frame
			var delta: Vector3=target-actor.position
			if Vector2(delta.x,delta.z).length()<.22 and (swim or absf(delta.y)<.65):reached=true;break
			if swim:runtime._physics_process(1.0/60)
			actor.simulate(Vector2(delta.x,delta.z).normalized(),0,true,1.0/60,swim and not dive,Vector3(0,clampf(delta.y,-1,1),0) if dive else Vector3.ZERO)
		var row:={"target":str(target),"end":str(actor.position),"pass":reached}
		routes.append(row);print("ROUTE ",row)
		if not reached:return false
	return true
func blocked(a: Vector3,b: Vector3) -> bool:
	return not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.selected_map="as_frigate";game.start_host("Frigate audit",0,100,6,true,"as")
	check(game.active and game.current_map=="as_frigate","Catalog Frigate starts in Assault")
	if not game.active:finish();return
	game.get_node("Map/MapRuntime").set_physics_process(false)
	for id in game.players:game.players[id].spectator=true
	var s: Dictionary=game.players[1];s.spectator=false;s.dead=false;s.team=0
	var actor=game.fighters[1];var rules=game.match_mode.assault;var tf=game.match_mode.fortress
	await physics_frame;await physics_frame
	if "--views" in OS.get_cmdline_user_args():await views();finish();return
	check(game.Maps.supports_assault("res://maps/as_frigate.bsp") and rules.objectives.size()==2,"BSP advertises ordered Assault objectives and both teams")
	check(tf.buildings.size()==2 and tf.buildings[100100].hp==240,"Defending sentry and 240 HP compressor are installed")
	check(game.bots.ready_to_walk,"Prebaked navigation loads")
	var space=game.get_world_3d().direct_space_state
	var clear:=true
	for spawn in game.ctf_spawns[0]+game.ctf_spawns[1]+rules.spawns(0)+rules.spawns(1):
		var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7;query.shape=capsule;query.collision_mask=1;query.transform.origin=spawn+Vector3.UP*.9
		if not space.intersect_shape(query).is_empty():clear=false;print("BAD_SPAWN ",spawn)
	check(clear,"All initial player capsules clear the map and furniture")
	# The old map can already have iteration 1 while the new region is still
	# synchronizing asynchronously. Wait for the new region and a usable path.
	var nav:=PackedVector3Array()
	for attempt in 120:
		if NavigationServer3D.map_get_iteration_id(game.bots.region.get_navigation_map())>0 and NavigationServer3D.region_get_iteration_id(game.bots.region.get_rid())>0:
			nav=NavigationServer3D.map_get_path(game.bots.region.get_navigation_map(),q(-1120,-960),q(192,0,320),true)
			if not nav.is_empty():break
		await physics_frame
	print("FRIGATE_NAV points=",nav.size())
	check(not nav.is_empty() and nav[-1].distance_to(q(192,0,320))<1,"Baked navigation connects attacker spawn to bridge through dynamic doorway")
	if "--nav" in OS.get_cmdline_user_args():
		var points: Array=[q(-1120,-960),q(352,-768),q(352,-256),q(-432,0),q(-560,208,16),q(-224,208,160),q(-304,-128,176),q(-32,-128,320),q(96,-128,320),q(192,0,320)]
		for i in range(1,points.size()):
			var part:=NavigationServer3D.map_get_path(game.bots.region.get_navigation_map(),points[i-1],points[i],true)
			print("NAV_SEGMENT ",i," size=",part.size()," from=",NavigationServer3D.map_get_closest_point(game.bots.region.get_navigation_map(),points[i-1])," to=",NavigationServer3D.map_get_closest_point(game.bots.region.get_navigation_map(),points[i]))
		finish();return
	actor.position=q(-800,0);actor.velocity=Vector3.ZERO
	check(await route([q(-1008,-64),q(-1008,-200),q(-672,-200,160)]),"Alternate aft staircase reaches the mess deck with full capsule clearance")
	actor.position=q(-1120,-960);actor.velocity=Vector3.ZERO
	check(await route([q(-1024,-768),q(352,-768),q(352,-256),q(224,-128),q(96,-128),q(0,0),q(-304,0),q(-544,-128),q(-688,-128),q(-800,0)]),"Continuous warehouse, gangway and compartment route reaches the aft compressor")
	actor.position=rules.objectives[0].position;rules.tick(.02)
	check(rules.stage==0 and not rules.activate(1),"Walking, Use and VR activation cannot bypass compressor damage")
	actor.position=rules.objectives[1].position
	check(not rules.activate(1),"Final gun console cannot skip the compressor")
	var initial: int=tf.buildings[100100].hp
	for mode in ["defender","dead","spectator","unknown"]:
		s.team=1 if mode=="defender" else 0;s.dead=mode=="dead";s.spectator=mode=="spectator";game.match_mode.friendly_fire=true
		tf.damage_building(100100,9999 if mode=="unknown" else 1,1000)
		check(tf.buildings.has(100100) and tf.buildings[100100].hp==initial,mode+" cannot damage the mission compressor, including friendly fire")
	s.team=0;s.dead=false;s.spectator=false;game.match_mode.friendly_fire=false
	rules.destroyed(1,0);check(rules.stage==0,"Destruction callback cannot advance while compressor still exists")
	check(blocked(q(-64,-128,372),q(64,-128,372)) and blocked(q(416,0,400),q(224,0,400)) and blocked(q(224,0,576),q(224,0,372)),"Locked bridge door, forward windows and roof physically block bypasses")
	var bot: Dictionary=game.players[-1];bot.team=0;bot.dead=false;bot.spectator=false;bot.weapon=2;bot.owned=[2];bot.ammo[0]=100;bot.cooldown=0
	game.fighters[-1].position=q(-800,0);s.spectator=true
	for attempt in 12:game.clock+=.25;game.bots.tick(.25)
	game._fire(-1)
	check(bot.fire and tf.buildings[100100].hp<initial,"Attacking bot aims and damages compressor with its normal pistol")
	bot.spectator=true;s.spectator=false;tf.buildings[100100].hp=initial
	# Aim an actual spawn pistol at the compressor and use the normal hitscan path.
	actor.position=q(-800,0);actor.velocity=Vector3.ZERO;s.owned=[2];s.weapon=2;s.ammo[0]=100;s.invulnerable=0
	var target: Vector3=tf.buildings[100100].position+Vector3.UP*.85
	var direction: Vector3=(target-game._weapon_transform(1).origin).normalized();s.yaw=atan2(-direction.x,-direction.z);s.pitch=asin(direction.y)
	for shot in 50:
		if not tf.buildings.has(100100):break
		game.clock+=1;s.cooldown=0;game._fire(1)
	check(rules.stage==1 and not tf.buildings.has(100100),"Actual pistol fire destroys compressor and advances exactly one stage")
	check(game.gates[0].open,"Compressor destruction opens bridge door")
	# Door movement is normally in arena process; put it at its fully open endpoint.
	game.gates[0].node.position=game.gates[0].base_position+game.gates[0].travel
	actor.position=q(-800,0);actor.velocity=Vector3.ZERO
	check(await route([q(-688,-128),q(-544,-128),q(-432,0),q(-432,112),q(-560,112),q(-560,208),q(-224,208,160),q(-224,0,160),q(-320,0,160),q(-304,-128,176),q(32,-128,320),q(96,-128,320),q(192,0,320)]),"Continuous aft-to-mess-deck stairs and bridge stairs reach the unlocked final console")
	s.vr_device=true;check(rules.activate(1) and rules.switching and rules.first_finished,"VR Use at the gun console completes first attack")
	rules.next_leg();check(rules.stage==0 and rules.attacking==1 and tf.buildings[100100].hp==240 and tf.buildings[100100].team==0 and not game.gates[0].open,"Role swap restores compressor, defender ownership and locked door")
	s.team=1;s.dead=false;s.spectator=false;game.intermission=0
	var original_position: Vector3=actor.position
	actor.position=q(672,384,-192);actor.velocity=Vector3.ZERO;actor.jump_held=false;actor.reset_view()
	var runtime=game.get_node("Map/MapRuntime")
	check(runtime.contents.at(q(672,352,-144))==-3,"Starboard intake contains swimmable water")
	var entered: bool=await route([q(672,288,-192)],true,true)
	check(entered and await route([q(752,176,-128),q(352,192,0),q(288,192,0)],true) and actor.position.y>-.1,"Swimming intake route exits onto main deck via ramp without precision jumping")
	actor.position=q(1512,-928,-192);actor.velocity=Vector3.ZERO;actor.jump_held=false;actor.reset_view()
	check(await route([q(1312,-928,-32),q(1216,-928,0)],true) and actor.position.y>-.1,"Harbor escape ramp returns a swimmer to the quay")
	actor.in_water=false;actor.position=original_position
	var copy=load("res://deathmatch/modes/match.gd").new();copy.game=game;copy.assault.setup(copy);copy.fortress.setup(copy);copy.receive(game.match_mode.snapshot())
	check(copy.assault.attacking==1 and copy.fortress.buildings[100100].kind=="compressor" and copy.fortress.buildings[100100].hp==240,"Objective health, kind and attack roles survive client snapshot replication")
	copy.fortress.free()
	game.headless=false;tf.draw();game.headless=true
	check(tf.visuals["b100100"].has_node("ObjectiveHealth"),"Compressor renders dedicated tanks, damage panel and health label")
	game._rotate_map(game.lobby.ID);await process_frame
	check(tf.buildings.is_empty() and tf.visuals.is_empty(),"Leaving Frigate removes sentry and compressor from lobby")
	finish()
func views() -> void:
	if DisplayServer.get_name()=="headless":return
	if game.hud:game.hud.hide()
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	var camera: Camera3D=game.get_node("Overview");camera.make_current();camera.fov=78
	game.match_mode.draw_objectives();game.match_mode.fortress.draw()
	for view in [["harbor",q(1472,-1232,704),q(-160,0,176)],["dock",q(832,-784,64),q(-128,0,208)],["compressor",q(-704,-64,56),q(-896,32,48)],["mess",q(-960,224,216),q(-384,0,208)],["bridge",q(64,-160,376),q(304,0,376)],["intake",q(896,576,-32),q(608,224,-128)]]:
		camera.position=view[1];camera.look_at(view[2]);await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/frigate/"+view[0]+".png")
func finish() -> void:
	var report:={"checks":checks,"failures":failures,"routes":routes}
	print("FRIGATE_RESULT ",JSON.stringify(report))
	if not "--views" in OS.get_cmdline_user_args():FileAccess.open("res://test-results/frigate/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free();quit(0 if failures.is_empty() else 1)
