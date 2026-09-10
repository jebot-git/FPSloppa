extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
var game
var failures: Array=[]
var reports: Array=[]
var current: Dictionary={}
func _initialize():call_deferred("run")
func require(value: bool,label: String) -> void:
	if not value:failures.append(current.get("id","")+": "+label);print("FAIL ",failures.back())
func point(value: Array) -> Vector3:return Vector3(-value[1],value[2],-value[0])/32.0
func floor_at(pos: Vector3) -> Dictionary:
	var space=game.get_world_3d().direct_space_state
	var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.9,pos-Vector3.UP*2,1))
	if not hit.is_empty():return hit
	# Exact triangle seams can reject a zero-width ray. Require four agreeing
	# 2 mm probes AND physical foot support before accepting that precision case.
	var nearby: Array=[]
	for offset in [Vector3(.002,0,0),Vector3(-.002,0,0),Vector3(0,0,.002),Vector3(0,0,-.002)]:
		var probe: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+offset+Vector3.UP*.9,pos+offset-Vector3.UP*2,1))
		if probe.is_empty() or probe.normal.y<.99:return {}
		nearby.append(probe)
	var height: float=nearby[0].position.y
	for probe in nearby:
		if absf(probe.position.y-height)>.002:return {}
	var support:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.05
	support.shape=sphere;support.collision_mask=1;support.transform.origin=Vector3(pos.x,height+.025,pos.z)
	if space.intersect_shape(support,1).is_empty():return {}
	current.seam_support_checks=int(current.get("seam_support_checks",0))+1
	hit=nearby[0];hit.position=Vector3(pos.x,height,pos.z)
	return hit
func clear_at(pos: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.65
	query.shape=shape;query.collision_mask=1;query.margin=.001;query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.85)
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func walkable(pos: Vector3) -> bool:
	var floor:=floor_at(pos)
	return not floor.is_empty() and floor.normal.y>.65 and clear_at(floor.position)
func length_of(path: PackedVector3Array) -> float:
	var distance:=0.0
	for i in range(1,path.size()):distance+=path[i-1].distance_to(path[i])
	return distance
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://optional-arena-pack/manifest.json"))
	var args:=OS.get_cmdline_user_args();var only:=""
	if args.has("--only"):only=args[args.find("--only")+1]
	DirAccess.make_dir_recursive_absolute("res://optional-arena-pack/navigation")
	for row: Dictionary in rows:
		if not only.is_empty() and row.id!=only:continue
		current={"id":row.id,"sha256":row.sha256,"mode":row.mode,"failures_before":failures.size(),"spawn_checks":0,"route_checks":0,"portal_samples":0,"triangles":0,"max_route_m":0.0}
		var path: String=ProjectSettings.globalize_path("res://optional-arena-pack/"+row.id+".bsp")
		require(Loader.validate(path).is_empty(),"BSP geometry/index/lump validation")
		var entry: Dictionary={"id":row.id,"title":row.title,"path":path,"sha256":FileAccess.get_sha256(path),"scene":"user://arena-pack-baked-validation/"+FileAccess.get_sha256(path)+".scn"}
		game.map_catalog=[entry];require(game._load_map(row.id),"Runtime load");game.match_mode.kind=row.mode;game.match_mode.reset()
		await physics_frame;await physics_frame
		var level: Node=game.get_node("Map").get_child(0)
		current.baked_faces=int(level.get_meta("baked_light_faces",0));current.baked_rgb=bool(level.get_meta("baked_light_rgb",false))
		require(current.baked_faces>0 and current.baked_rgb,"Embedded coloured bake imported")
		var meshes:=level.find_children("*","MeshInstance3D",true,false)
		current.meshes=meshes.size();require(not meshes.is_empty(),"Visible geometry exists")
		for mesh: MeshInstance3D in meshes:
			if not mesh.mesh:continue
			var faces:=mesh.mesh.get_faces();current.triangles+=faces.size()/3
			for i in range(0,faces.size(),3):
				require(faces[i].is_finite() and faces[i+1].is_finite() and faces[i+2].is_finite() and (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()>1e-14,"Finite nondegenerate render triangle")
		for collider: CollisionShape3D in level.find_children("*","CollisionShape3D",true,false):
			if collider.shape is ConcavePolygonShape3D:
				var faces: PackedVector3Array=collider.shape.get_faces()
				for i in range(0,faces.size(),3):require((faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()>1e-14,"Nondegenerate collision triangle")
		for spawn: Vector3 in game.spawn_points:
			current.spawn_checks+=1;require(walkable(spawn),"Safe spawn "+str(spawn))
		if row.mode in ["ctf","tf"]:
			require(game.ctf_spawns[0].size()==4 and game.ctf_spawns[1].size()==4,"Four native spawns per team")
			require(game.map_objectives.has("red") and game.map_objectives.has("blue"),"Native flags")
		if row.mode=="tf":require(game.tf_resupply[0].size()==2 and game.tf_resupply[1].size()==2,"Two resupply zones per team")
		var goals: Array=[]
		for goal: Dictionary in row.goals:
			var pos:=point(goal.position)-Vector3.UP*.70;goals.append(pos)
			require(walkable(pos),"Safe objective "+goal.kind)
			if goal.kind=="hill":require(game.match_mode.hill.distance_to(pos)<.1,"Current build selects authored hill")
		for pickup: Dictionary in game.pickups:
			require(walkable(pickup.position),"Reachable pickup floor "+str(pickup.position));goals.append(pickup.position)
		# Verify each authored connection through actual collision, including ramp slopes.
		for link: Array in row.links:
			var from:=Vector3.ZERO;var to:=Vector3.ZERO
			for room: Dictionary in row.rooms:
				if room.grid==link[0]:from=point(room.position)
				if room.grid==link[1]:to=point(room.position)
			var direction: Vector3=(to-from).normalized();var horizontal:=Vector3(direction.x,0,direction.z).normalized()
			var start: Vector3=from+horizontal*(row.half_room-24)/32.0
			var end: Vector3=to-horizontal*(row.half_room-24)/32.0
			var samples:=maxi(2,ceili(start.distance_to(end)/.5))
			for i in range(samples+1):
				current.portal_samples+=1;require(walkable(start.lerp(end,float(i)/samples)),"Capsule-clear connecting ramp "+str(link)+" sample "+str(i))
		var nav: NavigationMesh=preload("res://deathmatch/bots.gd").new_mesh()
		var source:=NavigationMeshSourceGeometryData3D.new();NavigationServer3D.parse_source_geometry_data(nav,source,level)
		NavigationServer3D.bake_from_source_geometry_data(nav,source)
		var region:=NavigationRegion3D.new();region.navigation_mesh=nav;game.add_child(region)
		var navigation:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(navigation,true);region.set_navigation_map(navigation)
		NavigationServer3D.map_force_update(navigation)
		await physics_frame;await physics_frame
		for attempt in range(80):
			if NavigationServer3D.map_get_iteration_id(navigation)>0 and NavigationServer3D.map_get_closest_point(navigation,game.spawn_points[0]).distance_to(game.spawn_points[0])<2:break
			await create_timer(.05).timeout
		print("NAV_STATE ",row.id," ",NavigationServer3D.map_get_regions(navigation)," iteration ",NavigationServer3D.map_get_iteration_id(navigation)," closest ",NavigationServer3D.map_get_closest_point(navigation,game.spawn_points[0]))
		current.nav_polygons=nav.get_polygon_count();require(nav.get_polygon_count()>0,"Bot navigation exists")
		var destinations: Array=goals+game.spawn_points
		for spawn: Vector3 in game.spawn_points:
			for goal: Vector3 in destinations:
				if spawn.distance_to(goal)<1:continue
				var route:=NavigationServer3D.map_get_path(navigation,spawn,goal,true)
				current.route_checks+=1
				require(route.size()>1 and route[-1].distance_to(goal)<1.05,"Connected bot route "+str(spawn)+" -> "+str(goal))
				current.max_route_m=maxf(current.max_route_m,length_of(route))
		if row.mode in ["ctf","tf"]:
			var distances: Array=[0.0,0.0]
			for team in [0,1]:
				for spawn: Vector3 in game.ctf_spawns[team]:distances[team]+=length_of(NavigationServer3D.map_get_path(navigation,spawn,game.match_mode.bases[1-team],true))
			current.team_route_ratio=maxf(distances[0],distances[1])/maxf(1,minf(distances[0],distances[1]))
			require(current.team_route_ratio<1.08,"Balanced team approach lengths")
		# Record spawn sightlines for review, without claiming an anti-camping guarantee.
		var exposed:=0;var pairs:=0
		for i in game.spawn_points.size():
			for j in range(i+1,game.spawn_points.size()):
				var a: Vector3=game.spawn_points[i]+Vector3.UP*1.4;var b: Vector3=game.spawn_points[j]+Vector3.UP*1.4
				if a.distance_to(b)<1:continue
				pairs+=1
				if game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty():exposed+=1
		current.direct_spawn_sightline_ratio=float(exposed)/maxi(1,pairs)
		require(ResourceSaver.save(nav,"res://optional-arena-pack/navigation/"+row.id+".res")==OK,"Save bot navigation")
		region.free();NavigationServer3D.free_rid(navigation);await physics_frame
		current.passed=failures.size()==current.failures_before;current.erase("failures_before");reports.append(current)
		print("ARENA_MAP_CHECK ",JSON.stringify(current))
	var output:=FileAccess.open("res://test-results/arena-pack-validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"maps":reports,"failures":failures},"  "));output.close()
	print("ARENA_PACK_RESULT ",JSON.stringify(failures));game.free();quit(0 if failures.is_empty() else 1)
