extends SceneTree
const Map=preload("res://tools/voxel_battle/map.gd")
var checks:=0
var errors: Array=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var begin:=Time.get_ticks_msec()
	var map:=Map.new();root.add_child(map);map.build(false)
	await physics_frame;await physics_frame
	var space:=map.get_world_3d().direct_space_state
	for position in map.spawn_positions:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*.3,position-Vector3.UP,1))
		check(not hit.is_empty(),"spawn remains physically grounded")
	for site in Map.Landscape.ADDITIONAL_SITES:
		var p: Vector3=site.position
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3,p-Vector3.UP,1))
		check(not hit.is_empty() and hit.position.y>=p.y-.02 and hit.position.y<=p.y+.4,"authored site has ground within step height "+site.name)
	for x in [-Map.LIMIT+5,Map.LIMIT-5]:
		for z in [-Map.LIMIT+5,Map.LIMIT-5]:
			var p:=Vector3(x,Map.Landscape.surface(x,z).x,z)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*2,1))
			check(not hit.is_empty(),"terrain collision reaches world corner")
	var port: Vector3=Map.Landscape.CENTERS[2]
	var water:=Vector3(port.x,0,port.z+200)
	var bed:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(water,water-Vector3.UP*12,1))
	check(not bed.is_empty() and absf(bed.position.y+8)<.1,"solid seabed stops sinking")
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(water+Vector3.UP,water-Vector3.UP*2,1)).is_empty(),"water surface has no collider")
	for bridge in map.waterways.bridges:
		var p:Vector3=bridge.frame.origin
		var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP,1))
		check(not hit.is_empty(),"road crossing retains solid bridge deck")
	for row in map.geometry:
		if row.size.y==680:check(absf(row.get_center().x)>Map.LIMIT or absf(row.get_center().z)>Map.LIMIT,"boundary beyond road extent")
	var report:={"checks":checks,"errors":errors,"environment_colliders":map.environment_colliders,"wall_boxes":map.geometry.size(),"setup_seconds":(Time.get_ticks_msec()-begin)/1000.0,"heightmap_samples":Map.COLLISION_SIDE*Map.COLLISION_SIDE,"river_bridge_sections":map.waterways.bridges.size()}
	if OS.get_cmdline_user_args().has("--nav"):
		var start:=Time.get_ticks_msec()
		var chunks=await preload("res://tools/voxel_battle/jungle_navigation.gd").build(map)
		map.add_child(chunks)
		var region: NavigationRegion3D=chunks.get_child(0)
		NavigationServer3D.map_set_cell_size(region.get_navigation_map(),.3)
		NavigationServer3D.map_set_merge_rasterizer_cell_scale(region.get_navigation_map(),.001)
		NavigationServer3D.map_set_use_edge_connections(region.get_navigation_map(),false)
		var deadline:=Time.get_ticks_msec()+30000
		var probe: Vector3=Map.Landscape.CENTERS[4]+Vector3(0,.15,-42)
		while Time.get_ticks_msec()<deadline:
			await physics_frame
			if NavigationServer3D.map_get_iteration_id(region.get_navigation_map())>0 and NavigationServer3D.map_get_closest_point(region.get_navigation_map(),probe).distance_to(probe)<.5:break
		check(NavigationServer3D.map_get_closest_point(region.get_navigation_map(),probe).distance_to(probe)<.5,"chunk navigation synchronized at radar")
		for building in map.layout.buildings:
			var origin: Vector3=Map.Landscape.CENTERS[building.kind]
			var from:=origin+Vector3(-9,.15,-42 if building.kind==4 else -62)
			for floor in building.floors:
				var end: Vector3=origin+building.center+Vector3(0,floor*map.Architecture.STOREY+.13,0)
				var route:=full_path(region.get_navigation_map(),from,end)
				check(not route.is_empty() and route[-1].distance_to(end)<.8,"navigation reaches "+building.role+" floor "+str(floor))
		var from: Vector3=Map.Landscape.CENTERS[4]+Vector3(0,.15,-42)
		for center in Map.Landscape.CENTERS:
			var end: Vector3=center+Vector3(-9,.15,-42 if center==Map.Landscape.CENTERS[4] else -62)
			var route:=full_path(region.get_navigation_map(),from,end)
			check(not route.is_empty() and route[-1].distance_to(end)<1,"POI connected to radar "+str(center))
		var routing:=preload("res://tools/voxel_battle/jungle_routing.gd").new();routing.map_source=map
		for child in chunks.get_children():
			if child is NavigationRegion3D and child.navigation_mesh.get_polygon_count()>0:routing.region=child;break
		var legs: Array=[]
		for center in Map.Landscape.CENTERS:
			var end: Vector3=center+Vector3(-9,.2,-42 if center==Map.Landscape.CENTERS[4] else -62)
			var cursor: Vector3=from;var count:=0
			while cursor.distance_to(end)>1 and count<128:
				var route:=routing.path(cursor,end,false)
				if route.is_empty() or route[-1].distance_to(cursor)<.1:break
				cursor=route[-1];count+=1
			check(cursor.distance_to(end)<1,"bounded staged route reaches POI "+str(center));legs.append(count)
		report.staged_routing={"legs_per_poi":legs,"max_leg_distance_m":routing.LEG_DISTANCE,"native_search_limit_polygons":4096,"road_graph_nodes":routing.graph.get_point_count()}
		var submerged:=0;var polygons:=0
		for child in chunks.get_children():
			if not child is NavigationRegion3D:continue
			polygons+=child.navigation_mesh.get_polygon_count()
			for vertex in child.navigation_mesh.get_vertices():
				if Map.Landscape.in_water(vertex):submerged+=1
		check(submerged==0,"navmesh has no submerged walking vertices")
		report.navigation={"polygons":polygons,"chunks":chunks.get_meta("chunks"),"seam_links":chunks.get_meta("seam_links"),"seconds":(Time.get_ticks_msec()-start)/1000.0,"cache":preload("res://tools/voxel_battle/jungle_navigation.gd").cache_path(map),"water_vertices":submerged}

	report.checks=checks;report.errors=errors
	DirAccess.make_dir_recursive_absolute("res://test-results/jungle-terrain")
	FileAccess.open("res://test-results/jungle-terrain/physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));map.free();await process_frame;quit(0 if errors.is_empty() else 1)

func full_path(map: RID,start: Vector3,end: Vector3) -> PackedVector3Array:
	var query:=NavigationPathQueryParameters3D.new();query.map=map;query.start_position=start;query.target_position=end
	query.path_search_max_polygons=0 # Offline connectivity proof only.
	var result:=NavigationPathQueryResult3D.new();NavigationServer3D.query_path(query,result)
	return result.get_path()
