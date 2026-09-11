extends SceneTree
var game
var failures: Array=[]
var routes: Array=[]
func _initialize() -> void:run.call_deferred()
func q(x: float,y: float,z: float=0) -> Vector3:return Vector3(-y,z,-x)/32.0+Vector3.UP*.05
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
	return false
func route(points: Array) -> bool:
	for target in points:
		var reached: bool=await walk(target)
		routes.append({"target":str(target),"end":str(game.fighters[1].position),"pass":reached})
		print("ROUTE ",routes.back())
		if not reached:return false
	return true
func blocked(a: Vector3,b: Vector3) -> bool:
	var hit: bool=not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()
	if not hit:print("UNSEALED ",a," -> ",b)
	return hit
func run() -> void:
	var args:=OS.get_cmdline_user_args();var path: String=args[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":"as_hislop","title":"HiSlop","path":path,"scene":"user://"+hash+"-interior.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map="as_hislop"
	game.start_host("Cabin collision audit",0,100,7,true,"as")
	check(game.active,"Rebuilt HiSlop starts in Assault")
	if not game.active:finish();return
	for id in game.players:game.players[id].spectator=true
	game.players[1].spectator=false;game.players[1].dead=false;game.players[1].team=0
	var actor=game.fighters[1];actor.quake_movement=true
	await physics_frame;await physics_frame
	# Try the real capsule against the locked opening before touching the switch.
	actor.position=q(1856,-72);actor.velocity=Vector3.ZERO
	check(not await walk(q(1968,-72),120) and actor.position.z>q(1904,-72).z,"Locked cabin door physically stops a walking attacker")
	var sealed:=true
	for x in [1936,1984,2024]:
		for y in [-144,-64,64,144]:sealed=blocked(q(x,y,180),q(x,y,64)) and sealed
		for z in [56,80]:
			sealed=blocked(q(x,-240,z),q(x,-144,z)) and sealed
			sealed=blocked(q(x,240,z),q(x,144,z)) and sealed
	for y in [-56,0,56]:sealed=blocked(q(2000,y,64),q(2112,y,64)) and sealed
	check(sealed,"Cabin ceiling, former side windows and locomotive end block bypass routes")
	check(blocked(q(1872,64,64),q(1968,64,64)) and blocked(q(1872,-160,64),q(1968,-160,64)),"Solid bulkhead fills both sides of the locked door")
	actor.position=q(1496,0);actor.velocity=Vector3.ZERO
	check(await route([q(1496,-120),q(1728,-120,144),q(1760,-56,144),q(1848,-56,144),q(1856,112,144)]),"Attacker walks stairs and upper compartment into switch room")
	game.match_mode.assault.tick(.02)
	check(game.match_mode.assault.stage==1 and game.gates[0].open,"Upper terminal opens the locked cabin door")
	await create_timer(.75).timeout
	check(await route([q(1856,-56,144),q(1760,-56,144),q(1728,-120,144),q(1496,-120),q(1496,24),q(1736,24),q(1736,-72),q(1872,-72),q(1968,-72),q(2016,-112)]),"Attacker returns downstairs through vestibule and open door to final terminal")
	game.match_mode.assault.tick(.02)
	check(game.match_mode.assault.switching and game.match_mode.assault.first_finished,"Physical route completes the first Assault leg")
	finish()
func finish() -> void:
	print("HISLOP_INTERIOR_RESULT ",JSON.stringify({"failures":failures,"routes":routes}))
	game.free();quit(0 if failures.is_empty() else 1)
