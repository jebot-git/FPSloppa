extends SceneTree
var g
var checks: Array=[]
var failures: Array=[]
var route_data: Dictionary
var probes: Dictionary
func _initialize():run.call_deferred()
func v(p: Array) -> Vector3:return Vector3(p[0],p[1],p[2])
func check(ok: bool,label: String):
	checks.append({"name":label,"passed":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func ray(a: Vector3,b: Vector3) -> Dictionary:return g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func standing(p: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.3;shape.height=1.65;query.shape=shape;query.transform.origin=p+Vector3.UP*.85;query.collision_mask=1
	return not ray(p+Vector3.UP*.35,p-Vector3.UP*.4).is_empty() and g.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func run():
	Engine.physics_ticks_per_second=1000;Engine.max_physics_steps_per_frame=64;Engine.time_scale=1000.0/60
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="tb_cindercoil";g.start_host("Cindercoil acceptance",0,100,10,true,"tb")
	g.set_process(false);g.set_physics_process(false);g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	await physics_frame;await physics_frame
	route_data=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Cindercoil/route.json"));probes=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Cindercoil/probes.json"))
	var tb=g.match_mode.titanball;var w=g.match_mode.fortress.walkers;var r: Dictionary=w.robots.test
	check(g.current_map=="tb_cindercoil" and tb.attacker_spawns.size()==3 and g.spawn_points.size()==16,"Runtime loads circular BSP and sixteen TB spawns")
	check(absf(r.path.get_baked_length()-350)<.05 and tb.CHECKPOINTS==[80.,230.],"350 m route and 80/230 m checkpoints preserved")
	check(absf(r.points.back().y-r.points.front().y-14)<.01,"Road rises fourteen metres toward defender base")
	var monotone:=true;var max_grade:=0.0
	for i in 700:
		var a: Vector3=w.Route.sample(r.path,i*.5).origin;var b: Vector3=w.Route.sample(r.path,i*.5+.5).origin
		monotone=monotone and b.y>=a.y-.001;max_grade=maxf(max_grade,(b.y-a.y)/maxf(.01,Vector2(b.x-a.x,b.z-a.z).length()))
	check(monotone and max_grade<.06,"Gradual monotone ascent stays below six percent grade")
	check(tb.preparing() and g.round_left==600,"Sixty-second preparation preserves ten-minute active timer")
	check(not ray(Vector3(0,1,-8),Vector3(0,1,-2)).is_empty(),"Closed hangar blocks direct exit")
	check(ray(Vector3(18,1.45,-8),Vector3(18,1.45,-2)).is_empty(),"Hangar firing slit transmits shots")
	var query:=PhysicsShapeQueryParameters3D.new();var cap:=CapsuleShape3D.new();cap.radius=.3;cap.height=.6;query.shape=cap;query.collision_mask=1;query.transform.origin=Vector3(18,1.45,-8);query.motion=Vector3(0,0,6)
	check(g.get_world_3d().direct_space_state.cast_motion(query)[0]<1,"Hangar slit excludes prone capsules")
	tb.advance_time(60);await physics_frame;await physics_frame
	check(not tb.preparing() and ray(Vector3(0,1,-8),Vector3(0,1,-2)).is_empty() and g.round_left==600,"Gate opens after preparation without using active time")
	var edges_closed:=true
	for d in range(22,351,2):
		var pose: Transform3D=w.Route.sample(r.path,d)
		for side in [-1,1]:
			if side==1 and probes.tunnels.any(func(p):return absf(p.distance-d)<10):continue
			var a: Vector3=pose.origin+pose.basis.x*side*18+Vector3.UP*1.2
			var b: Vector3=pose.origin+pose.basis.x*side*29+Vector3.UP*1.2
			if ray(a,b).is_empty():edges_closed=false;print("OPEN_EDGE ",d," side ",side)
	check(edges_closed,"Road edges enclose both flanks outside authored tunnel entrances")
	for p in probes.spawns:check(standing(v(p.position)),"Spawn floor/capsule: team %d stage %d %s"%[p.team,p.stage,str(p.position)])
	check(g.pickups.is_empty() and tb.stations.size()==6,"Six shared dispensers and no natural pickups")
	for p in tb.stations:check(standing(p),"Dispenser floor/capsule "+str(p))
	for p in tb.vantages:check(standing(p.position),"Tactical high ground floor/capsule "+str(p.position))
	g.fighters[1].position=Vector3(-30,30,-80)
	var blocked: Array=[]
	for i in 701:
		var d: float=i*.5;var pose: Transform3D=w.Route.sample(r.path,d)
		r.distance=d;r.position=pose.origin;r.yaw=pose.basis.get_euler().y;r.speed=w.SPEED
		for turn in [-w.Tuning.LATERAL_LIMIT,0.,w.Tuning.LATERAL_LIMIT]:
			r.body_yaw=turn;w._update_body(w.bodies.test,r)
			if w.bodies.test.test_move(pose,Vector3.ZERO):blocked.append([d,turn])
	check(blocked.is_empty(),"Titan clears ascending route every half metre at all three torso angles")
	if not blocked.is_empty():print("BLOCKED_ROUTE ",blocked.slice(0,40))
	# Actual authority movement, including smooth acceleration and endpoint braking.
	w.reset();r=w.robots.test;g.players[1].team=0;g.players[1].input_blocked=false;g.fighters[1].position=r.position;g.fighters[1].velocity=Vector3.ZERO
	check(w.try_board(1,"test"),"Attacker boards Titan at lower base")
	var elapsed:=0.0;var stalled:=0
	while elapsed<480 and tb.winner<0:
		await physics_frame;g.clock+=.1;w.tick(.1);elapsed+=.1
		if r.state=="blocked":stalled+=1
		if stalled>10:break
	check(tb.winner==0 and r.distance>=349.98,"Authoritative Titan drives entire rising circle and delivers")
	check(tb.cleared==2 and g.round_left==960,"Both rear-clearance awards apply exactly once")
	w.configure([]);g.intermission=0
	# Open gate navigation; inaccessible scenery roofs are removed from the bake.
	var mesh=preload("res://deathmatch/bots.gd").new_mesh("tb_cindercoil");var geometry:=NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh,geometry,g.get_node("Map"));NavigationServer3D.bake_from_source_geometry_data(mesh,geometry)
	var pruning: Dictionary=preload("res://tools/titanball/navigation_bake.gd").retain_walkable_component(mesh,tb.attacker_spawns[0][0]);print("NAV_COMPONENT ",pruning)
	ResourceSaver.save(mesh,"res://maps/navigation/tb_cindercoil.res");FileAccess.open("res://maps/Cindercoil/navigation-sha256.txt",FileAccess.WRITE).store_string(FileAccess.get_sha256("res://maps/tb_cindercoil.bsp")+"\n")
	var nav:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(nav,true)
	NavigationServer3D.map_set_cell_size(nav,mesh.cell_size);NavigationServer3D.map_set_cell_height(nav,mesh.cell_height)
	var region:=NavigationRegion3D.new();g.add_child(region);region.set_navigation_map(nav);region.navigation_mesh=mesh
	for frame in 120:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav)>=2:break
	NavigationServer3D.map_force_update(nav)
	for origin in [tb.attacker_spawns[0][0],tb.defender_spawns[0]]:
		for destination in g.spawn_points+tb.stations+tb.vantages.map(func(p):return p.position)+probes.tunnels.map(func(p):return v(p.hub)):
			var path=NavigationServer3D.map_get_path(nav,origin,destination,true)
			check(not path.is_empty() and path[-1].distance_to(destination)<1.0,"Navigation from "+("attacker" if origin==tb.attacker_spawns[0][0] else "defender")+" reaches "+str(destination))
	for tunnel in probes.tunnels:
		check(standing(v(tunnel.entry)) and standing(v(tunnel.hub)),"Connecting tunnel has standing entrances "+str(tunnel.distance))
		await walk([tunnel.entry,tunnel.hub],"Tunnel "+str(tunnel.distance))
		await walk([tunnel.hub,tunnel.entry],"Tunnel return "+str(tunnel.distance))
	var tunnel_edge:=ray(Vector3(31.3,4,13),Vector3(31.3,-9,13))
	check(not tunnel_edge.is_empty() and tunnel_edge.position.y>0,"First tunnel side floor supports strafing beside the central walking line")
	for i in probes.tunnels.size():
		for j in probes.tunnels.size():
			if i==j:continue
			var a:=v(probes.tunnels[i].hub);var b:=v(probes.tunnels[j].hub)
			var path:=NavigationServer3D.map_get_path(nav,a,b,true);var distance:=0.0
			for step in range(1,path.size()):distance+=path[step-1].distance_to(path[step])
			check(path.size()>1 and path[-1].distance_to(b)<1 and distance<30,"Central hall directly connects tunnels %d to %d"%[i,j])
	for bridge in probes.bridges:
		await walk([bridge.bottom]+bridge.steps,"Tower %s side %s"%[bridge.distance,bridge.side])
		var descent: Array=[bridge.bottom]+bridge.steps;descent.reverse()
		await walk(descent,"Tower descent %s side %s"%[bridge.distance,bridge.side])
	region.free();NavigationServer3D.free_rid(nav)
	var report:={"checks":checks,"failures":failures,"blocked_route":blocked,"drive_seconds":elapsed,"max_grade":max_grade,"navigation":pruning,"sha256":FileAccess.get_sha256("res://maps/tb_cindercoil.bsp")}
	FileAccess.open("res://test-results/cindercoil/acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CINDERCOIL_RESULT ",checks.size()," checks; ",failures)
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
func walk(points: Array,label: String):
	var actor=g.fighters[1];actor.position=v(points[0]);actor.velocity=Vector3.ZERO;actor.collision_mask=3
	var ok:=true
	for settle in 10:await physics_frame;actor.simulate(Vector2.ZERO,0,true,1.0/60)
	for point in points.slice(1):
		var target:=v(point);var reached:=false
		for frame in 1200:
			await physics_frame;var delta: Vector3=target-actor.position
			if Vector2(delta.x,delta.z).length()<.3 and absf(delta.y)<.6:reached=true;break
			actor.simulate(Vector2(delta.x,delta.z).normalized(),0,true,1.0/60)
		if not reached:print("STUCK ",label," target=",target," at=",actor.position);ok=false;break
	check(ok,label+" real fighter traversal")
