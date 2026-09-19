extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
var g
var failures: Array=[]
var checks: Array=[]
func v(p: Array) -> Vector3:return Vector3(p[0],p[1],p[2])
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func ray(a: Vector3,b: Vector3) -> Dictionary:return g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func standing(p: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.3;shape.height=1.65;query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.84);query.collision_mask=1
	return not ray(p+Vector3.UP*.4,p-Vector3.UP*.4).is_empty() and g.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1";g.start_host("BSP acceptance",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():if id<0:g._peer_left(id)
	Fixture.build(g);g.fighters[1].position=Vector3(0,0,3)
	await physics_frame;await physics_frame
	var tb=g.match_mode.titanball;var w=g.match_mode.fortress.walkers;var r: Dictionary=w.robots.test
	check(g.current_map=="tb_ashfall" and tb.attacker_spawns.size()==3 and g.spawn_points.size()==16,"Compiled BSP supplies route and all forward/team spawn groups")
	check(g.pickups.is_empty() and tb.stations.size()==6 and g.match_mode.fortress.buildings.size()==6,"No natural pickups; BSP defines six universal dispensers")
	for point in tb.stations:
		if not standing(point):print("BAD_STATION ",point)
	check(tb.stations.all(func(p):return standing(p)),"All six resupply stations have floor and player clearance")
	check(tb.vantages.size()==24 and tb.vantages.all(func(p):return standing(p.position)),"Twenty-four authored overpass, balcony and defensive-platform positions have standing clearance")
	check(tb.preparing() and g.round_left==600,"BSP match begins with preparation and untouched ten-minute clock")
	check(not ray(Vector3(0,1,16),Vector3(0,1,22)).is_empty(),"BSP hangar gate blocks passage during preparation")
	check(ray(Vector3(18,1.45,16),Vector3(18,1.45,22)).is_empty() and ray(Vector3(18,1.45,22),Vector3(18,1.45,16)).is_empty(),"BSP firing slit permits bidirectional harassment")
	var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=.6;query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,Vector3(18,1.45,16));query.motion=Vector3(0,0,6);query.collision_mask=1
	check(g.get_world_3d().direct_space_state.cast_motion(query)[0]<1.,"BSP slit excludes prone player capsule")
	var prep: float=tb.advance_time(60.);await physics_frame;await physics_frame
	check(prep==0 and g.round_left==600 and ray(Vector3(0,1,16),Vector3(0,1,22)).is_empty(),"After sixty preparation seconds the BSP gate opens without spending match time")
	var spawns_clear:=true
	for point in g.spawn_points:
		if not standing(point):print("BAD_SPAWN ",point);spawns_clear=false
	check(spawns_clear,"Every BSP spawn has floor and standing clearance")
	var closed:=true;var route_clear:=true
	for i in range(int(tb.ROUTE_METRES*2)+1):
		var distance: float=i*.5
		var pose: Transform3D=w.Route.sample(r.path,distance)
		r.distance=distance;r.position=pose.origin;r.yaw=pose.basis.get_euler().y;r.speed=w.SPEED
		for turn in [-w.Tuning.LATERAL_LIMIT,0.,w.Tuning.LATERAL_LIMIT]:
			r.body_yaw=turn;w._update_body(w.bodies.test,r)
			if w.bodies.test.test_move(pose,Vector3.ZERO):print("BLOCKED_ROUTE ",distance," yaw ",turn);route_clear=false
		if distance<22:continue
		for side in [-1.,1.]:
			var origin: Vector3=pose.origin+Vector3.UP*2
			if ray(origin,origin+pose.basis.x*side*80).is_empty():print("OPEN_EDGE ",i," ",side);closed=false
	check(route_clear,"Robot clears full BSP route at half-metre intervals and both 7.5-degree torso limits")
	check(closed,"Buildings or ruins close both street edges along the entire city route")
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Ashfall/probes.json"))
	check(absf(r.path.get_baked_length()-350.)<.05 and tb.CHECKPOINTS==[80.,230.],"Route remains 350 m with checkpoints at 80 m and 230 m")
	var stations_match: bool=tb.stations.size()==probes.stations.size()
	for i in probes.stations.size():
		stations_match=stations_match and tb.stations.any(func(p):return p.distance_to(v(probes.stations[i].position))<.05)
	check(stations_match,"Runtime resupply positions match current-route authored stations")
	check(probes.stations[1].distance<80 and probes.stations[2].distance>80 and probes.stations[2].distance-80<=24 and probes.stations[3].distance<230 and 230-probes.stations[3].distance<=15 and probes.stations[4].distance>230 and probes.stations[4].distance-230<=16,"Resupply flanks both current checkpoints within 24 m")
	var approach: Transform3D=w.Route.sample(r.path,230.)
	var base: Transform3D=w.Route.sample(r.path,350.)
	check(not ray(approach.origin+Vector3.UP*1.6,base.origin+Vector3.UP*1.6).is_empty(),"Curved final approach blocks the ground-level checkpoint-to-base sightline")
	var cover_ok:=true
	for item in probes.get("cover",[]):
		var p:=v(item.centre)
		if ray(p+Vector3.UP*5,p+Vector3.UP*.1).is_empty():print("MISSING_COVER ",item);cover_ok=false
	check(probes.get("cover",[]).size()==42 and cover_ok,"All 42 wreck/rubble/wall groups have real BSP cover geometry")
	var rooms_ok:=0
	for room in probes.rooms:
		if standing(v(room.centre)):rooms_ok+=1
		else:print("BAD_ROOM ",room.centre)
	check(rooms_ok>=8,"At least eight street-level ambush room probes are accessible standing spaces")
	var bridges_clear:=true
	for bridge in probes.bridges+probes.get("balconies",[]):
		if not standing(v(bridge.top)) or not standing(v(bridge.bottom)):print("BAD_BRIDGE ",bridge," bottom=",standing(v(bridge.bottom))," top=",standing(v(bridge.top)));bridges_clear=false
	check(bridges_clear,"Overpass and balcony access points have standing clearance")
	# Bake reusable navigation from this BSP after opening the preparation gate.
	w.configure([])
	var mesh=preload("res://deathmatch/bots.gd").new_mesh()
	var geometry:=NavigationMeshSourceGeometryData3D.new();NavigationServer3D.parse_source_geometry_data(mesh,geometry,g.get_node("Map"));NavigationServer3D.bake_from_source_geometry_data(mesh,geometry)
	var pruning: Dictionary=preload("res://tools/titanball/navigation_bake.gd").retain_walkable_component(mesh)
	print("TB_NAV_WALKABLE_COMPONENT ",JSON.stringify(pruning))
	check(mesh.get_polygon_count()>0,"BSP produces reusable navigation geometry")
	ResourceSaver.save(mesh,"res://maps/navigation/tb_ashfall.res")
	FileAccess.open("res://maps/Ashfall/navigation-sha256.txt",FileAccess.WRITE).store_string(FileAccess.get_sha256("res://maps/tb_ashfall.bsp")+"\n")
	var nav:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(nav,true);NavigationServer3D.map_set_cell_size(nav,mesh.cell_size);NavigationServer3D.map_set_cell_height(nav,mesh.cell_height)
	var region:=NavigationRegion3D.new();g.add_child(region);region.set_navigation_map(nav);region.navigation_mesh=mesh
	for frame in 120:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav)>=2:break
	NavigationServer3D.map_force_update(nav)
	var all_spawns_connected:=true
	for spawn in g.spawn_points:
		var path:=NavigationServer3D.map_get_path(nav,g.spawn_points[0],spawn,true)
		if path.is_empty() or path[-1].distance_to(spawn)>1.:all_spawns_connected=false
	check(all_spawns_connected,"All sixteen spawns remain connected after excluding unreachable scenery tops")
	var routes: Array=[]
	for point in tb.stations:
		var path:=NavigationServer3D.map_get_path(nav,g.spawn_points[0],point,true)
		check(path.size()>1 and path[-1].distance_to(point)<1.5,"Navigation reaches resupply station "+str(point))
	for point in tb.vantages:
		var path:=NavigationServer3D.map_get_path(nav,g.spawn_points[0],point.position,true)
		check(path.size()>1 and path[-1].distance_to(point.position)<1.5,"Navigation reaches tactical high ground "+str(point.position))
	for bridge in probes.bridges+probes.get("balconies",[]):
		var path:=NavigationServer3D.map_get_path(nav,v(bridge.bottom),v(bridge.top),true)
		print("CLOSEST ",NavigationServer3D.map_get_closest_point(nav,v(bridge.bottom))," -> ",NavigationServer3D.map_get_closest_point(nav,v(bridge.top)))
		print("NAV ",v(bridge.bottom)," to ",v(bridge.top)," path ",path)
		var ok:=path.size()>1 and path[-1].distance_to(v(bridge.top))<1.5
		if bridge.get("kind","")=="balcony_connection":
			check(ok and Array(path).all(func(p):return p.y>=5.8),"Middle overpass connects directly from the 6 m balcony without returning to street level")
		routes.append({"kind":"elevated_access","pass":ok,"points":path.size()});check(ok,"Navigation reaches elevated access "+str(v(bridge.top)))
	region.free();NavigationServer3D.free_rid(nav)
	FileAccess.open("res://test-results/titanball/acceptance.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"routes":routes,"sha256":FileAccess.get_sha256("res://maps/tb_ashfall.bsp")},"  "))
	print("TB_BSP_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
