extends SceneTree
var game
var failures: Array=[]
var routes: Array=[]
var layout_test:=false
var walk_seconds:=0.0
func _initialize() -> void:run.call_deferred()
func q(x: float,y: float,z: float=0) -> Vector3:return Vector3(-y*(1.25 if layout_test else 1.0),z,-x*(1.75 if layout_test else 1.0))/32.0+Vector3.UP*.05
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func walk(target: Vector3,frames: int=480) -> bool:
	var actor=game.fighters[1]
	for frame in frames:
		await physics_frame
		var delta: Vector3=target-actor.position
		if Vector2(delta.x,delta.z).length()<.2 and absf(delta.y)<.65:return true
		actor.simulate(Vector2(delta.x,delta.z).normalized(),0,true,1.0/Engine.physics_ticks_per_second)
		walk_seconds+=1.0/Engine.physics_ticks_per_second
	return false
func route(points: Array) -> bool:
	for target in points:
		var reached: bool=await walk(target)
		routes.append({"target":str(target),"end":str(game.fighters[1].position),"pass":reached})
		print("ROUTE ",routes.back())
		if not reached:return false
	return true
func blocked(a: Vector3,b: Vector3) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(a,b,1);query.hit_from_inside=true
	var hit: bool=not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if not hit:print("UNSEALED ",a," -> ",b)
	return hit
func run() -> void:
	var args:=OS.get_cmdline_user_args();var path: String=args[0]
	layout_test=not "--tiny" in args
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	var hash:=FileAccess.get_sha256(path)
	var map_id:="as_hislop" if layout_test else "as_hislop_tiny"
	game.map_catalog=[{"id":map_id,"title":"HiSlop","path":path,"scene":"res://maps/cache/"+hash+".scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map=map_id
	game.start_host("Cabin collision audit",0,100,7,true,"as")
	check(game.active,"Rebuilt HiSlop starts in Assault")
	if not game.active:finish();return
	for id in game.players:game.players[id].spectator=true
	game.players[1].spectator=false;game.players[1].dead=false;game.players[1].team=0
	var actor=game.fighters[1];actor.quake_movement=true
	await physics_frame;await physics_frame
	if "--views" in args:await views();finish();return
	if layout_test:
		game.get_node("Map/MapRuntime").set_physics_process(false)
		var nav:=PackedVector3Array()
		for attempt in 120:
			if NavigationServer3D.region_get_iteration_id(game.bots.region.get_rid())>0:
				nav=NavigationServer3D.map_get_path(game.bots.region.get_navigation_map(),q(-2528,0),q(2016,64,144),true)
				if not nav.is_empty():break
			await physics_frame
		check(game.bots.ready_to_walk and not nav.is_empty() and nav[-1].distance_to(q(2016,64,144))<1,"Variant navigation connects helicopter to upper switch")
		var space=game.get_world_3d().direct_space_state
		var clear:=true
		for spawn in game.ctf_spawns[0]+game.ctf_spawns[1]+game.match_mode.assault.spawns(0)+game.match_mode.assault.spawns(1):
			var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7;query.shape=capsule;query.collision_mask=1;query.transform.origin=spawn+Vector3.UP*.9
			if not space.intersect_shape(query).is_empty():clear=false;print("BAD_SPAWN ",spawn)
		check(clear,"Initial and checkpoint spawn capsules clear all new rooms")
		for end in [-1776,-1136,-496,144,784,1424]:
			for y in [-248,0,248]:
				actor.position=q(end-24,y);actor.velocity=Vector3.ZERO
				check(await route([q(end+44,y)]) and actor.position.y>-.2,"Walk across car seam %d lane %d without jumping"%[end,y])
		for p in [[504,-120],[680,-120],[504,120],[680,120]]:
			actor.position=q(p[0],p[1]);actor.velocity=Vector3.ZERO
			check(await route([q(p[0],0),q(740,0)]),"Defender spawn room has a walkable exit "+str(p))
		# The two upper passenger rooms still connect after the middle-car obstacle.
		actor.position=q(856,-120);actor.velocity=Vector3.ZERO
		check(await route([q(1080,-120,144),q(1168,-72,144),q(1184,56,144),q(1280,56,144),q(1360,56,0),q(1400,0)]),"CAR 2 stair and alternating passenger doors remain traversable")
	# Try the real capsule against the locked opening before touching the switch.
	actor.position=q(1856,-72);actor.velocity=Vector3.ZERO
	check(not await walk(q(1968,-72),120) and actor.position.z>q(1904,-72).z,"Locked cabin door physically stops a walking attacker")
	var sealed:=true
	for x in [1936,1984,2024]:
		for y in [-144,-64,64,144]:sealed=blocked(q(x,y,240),q(x,y,64)) and sealed
		for z in [56,80]:
			sealed=blocked(q(x,-240,z),q(x,-144,z)) and sealed
			sealed=blocked(q(x,240,z),q(x,144,z)) and sealed
	for y in [-56,0,56]:sealed=blocked(q(2000,y,64),q(2112,y,64)) and sealed
	check(sealed,"Cabin ceiling, former side windows and locomotive end block bypass routes")
	check(blocked(q(1872,64,64),q(1968,64,64)) and blocked(q(1872,-160,64),q(1968,-160,64)),"Solid bulkhead fills both sides of the locked door")
	actor.position=q(1496,0);actor.velocity=Vector3.ZERO
	walk_seconds=0
	var upper: Array=[q(1496,-120),q(1728,-120,144),q(1760,-56,144),q(1848,-56,144)]
	upper.append_array([q(1936,-56,144),q(1936,80,144),q(2016,80,144)] if layout_test else [q(1856,112,144)])
	check(await route(upper),"Attacker walks stairs and upper compartment into switch room")
	var upper_seconds:=walk_seconds;walk_seconds=0
	game.match_mode.assault.tick(.02)
	check(game.match_mode.assault.stage==1 and game.gates[0].open,"Upper terminal opens the locked cabin door")
	await create_timer(.75).timeout
	var lower: Array=[q(1936,80,144),q(1936,-56,144)] if layout_test else []
	lower.append_array([q(1856,-56,144),q(1760,-56,144),q(1728,-120,144),q(1496,-120),q(1496,24),q(1736,24),q(1736,-72),q(1872,-72),q(1968,-72),q(2016,-112)])
	check(await route(lower),"Attacker returns downstairs through vestibule and open door to final terminal")
	print("LAYOUT_ROUTE_SECONDS ",JSON.stringify({"expanded":layout_test,"stair_to_switch":upper_seconds,"switch_to_controls":walk_seconds,"speed":5.2,"combat":false}))
	game.match_mode.assault.tick(.02)
	check(game.match_mode.assault.switching and game.match_mode.assault.first_finished,"Physical route completes the first Assault leg")
	finish()
func finish() -> void:
	print("HISLOP_INTERIOR_RESULT ",JSON.stringify({"failures":failures,"routes":routes}))
	if layout_test and not "--views" in OS.get_cmdline_user_args():FileAccess.open("res://test-results/assault-layouts/hislop/result.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"routes":routes},"  "))
	game.free();quit(0 if failures.is_empty() else 1)
func views() -> void:
	if DisplayServer.get_name()=="headless":return
	if game.hud:game.hud.hide()
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	var camera: Camera3D=game.get_node("Overview");camera.make_current();camera.fov=85
	game.match_mode.draw_objectives();game.match_mode.fortress.draw()
	for view in [["train",q(-2360,-640,700),q(-128,0,48)],["crossing",q(-544,-260,62),q(-408,-220,24)],["spawn-rooms",q(744,0,64),q(464,0,64)],["passenger",q(1184,0,208),q(1104,-80,208)],["switch",q(1992,112,208),q(2028,-96,200)]]:
		camera.position=view[1];camera.look_at(view[2]);await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/assault-layouts/hislop/"+view[0]+".png")
