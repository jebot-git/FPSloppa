extends SceneTree
const Map=preload("res://tools/voxel_battle/map.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
var errors: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Map.new();root.add_child(world);world.build(false)
	var actor:=Fighter.new();actor.setup(100,"Door probe",Color.WHITE);world.add_child(actor);actor.quake_movement=true;actor.update_height(1.70,true)
	await physics_frame;await physics_frame
	var space:=world.get_world_3d().direct_space_state
	for p in world.spawn_positions:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3,p-Vector3.UP*1,1))
		check(not hit.is_empty(),"spawn has ground "+str(p))
	for building in ([] if OS.get_cmdline_user_args().has("--nav-only") else world.layout.buildings):
		var base: Vector3=world.Landscape.CENTERS[building.kind]
		for entry in building.entries:
			actor.position=base+entry;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view();actor.reset_jetpack()
			var direction: float=-1 if entry.z>building.center.z else 1
			for i in 60:
				await physics_frame
				actor.simulate(Vector2(0,direction),0,true,1.0/60,false)
			var local: Vector3=actor.position-base-building.center
			check(absf(local.z)<building.size.y*.5-.6,"170cm actor crosses "+building.role+" door "+str(entry))
			check(absf(local.y-.1)<.2,"door floor stays supported "+building.role)
		if building.floors>1:
			actor.position=base+building.center+Vector3(building.size.x/2-1.5,.4,-building.size.y/2+.5)
			actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view()
			for i in 110:
				await physics_frame
				actor.simulate(Vector2(0,1),0,true,1.0/60,false)
			check(absf(actor.position.y-base.y-3.3)<.25,"170cm actor climbs stairs "+building.role+" "+str(building.center))
	# A 170 cm human corridor across the entire painted road width plus shoulder
	# margin. Check physical wall boxes AND render boxes at all three LODs.
	var road_samples:=0
	for road in world.Landscape.main_roads:
		var a: Vector3=road.a;var b: Vector3=road.b
		var width: float=road.width
		var side: Vector3=(b-a).cross(Vector3.UP).normalized();side.y=0
		var steps:=ceili(Vector2(b.x-a.x,b.z-a.z).length()/2)
		for i in steps+1:
			var p:=a.lerp(b,float(i)/steps);p.y=world.Landscape.surface(p.x,p.z).x
			var size:=side.abs()*(width*2+.6)+Vector3(1.8,1.3,1.8)
			var bounds:=AABB(p+Vector3(0,.35,0)-Vector3(size.x/2,0,size.z/2),size)
			var physical_clear:=true;var visual_clear:=true
			for obstacle in world.geometry:
				if bounds.intersects(obstacle):physical_clear=false;break
			for row in world.layout.render_boxes:
				var center: Vector3=world.Landscape.CENTERS[row.kind]+row.center
				if bounds.intersects(AABB(center-row.size*.5,row.size)):visual_clear=false;break
			check(physical_clear,"physical road clearance "+str(p))
			check(visual_clear,"all LOD road clearance "+str(p));road_samples+=1
	for lane in world.Landscape.access_roads:
		for i in 12:
			var p: Vector3=lane.a.lerp(lane.b,float(i)/11)
			var nearest: Dictionary=world.Landscape.nearest_road(Vector2(p.x,p.z),world.Landscape.road_bins)
			check(nearest.is_empty() or nearest.distance>=nearest.road.width+.89,"entrance lane stops outside asphalt "+str(p))
			var bounds:=AABB(p+Vector3(-.35,.35,-.35),Vector3(.7,1.3,.7))
			var clear:=true
			for obstacle in world.geometry:
				if bounds.intersects(obstacle):clear=false;break
			check(clear,"access lane clears other buildings "+str(p))
		var end: Vector3=lane.b
		var nearest: Dictionary=world.Landscape.nearest_road(Vector2(end.x,end.z),world.Landscape.road_bins)
		check(absf(nearest.distance-nearest.road.width-.9)<.02,"access ends at road shoulder")
	var elevated:=0
	for cover in world.Landscape.COVER:
		var baseline:=18.0+sin(cover.x*.006)*cos(cover.y*.005)*11.0+sin(cover.x*.018+cover.y*.014)*3.0
		if world.Landscape.surface(cover.x,cover.y).x>baseline+3:elevated+=1
	check(elevated>=6,"heightmap provides at least six raised terrain cover points")
	for i in 4:
		check(world.Landscape.CENTERS[i].length()>210,"outer POI uses playable perimeter")
	var feature_totals: Array=[0,0,0]
	for z in range(23,41):
		for x in range(23,41):
			var coord:=Vector2i(x,z);var rows: Array=world.Landscape.features(coord)
			check(rows==world.Landscape.features(coord),"deterministic environmental tile "+str(coord))
			check(rows.size()<=16,"bounded features per tile")
			for row in rows:
				feature_totals[row.kind]+=1
				check(world.Landscape.planting_allowed(Vector2(row.position.x,row.position.z)),"feature clears road/site/dock")
				check(absf(row.position.y-world.Landscape.surface(row.position.x,row.position.z).x)<.001,"feature grounded")
	for total in feature_totals:check(total>50,"logical ecology contains each feature family")
	# Bake the same production navmesh, then demand connected routes to each storey.
	var region:=NavigationRegion3D.new();world.add_child(region)
	var nav:=preload("res://deathmatch/bots.gd").new_mesh("voxel_valley")
	NavigationServer3D.map_set_cell_size(region.get_navigation_map(),nav.cell_size)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(region.get_navigation_map(),.0001)
	region.navigation_mesh=nav
	var data:=NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav,data,world)
	NavigationServer3D.bake_from_source_geometry_data(nav,data)
	var routing:=preload("res://deathmatch/bot_ai/navigation.gd").new()
	routing.region=region
	var deadline:=Time.get_ticks_msec()+30000
	while not routing.ready() and Time.get_ticks_msec()<deadline:await physics_frame
	check(routing.ready(),"navigation synchronized")
	for building in world.layout.buildings:
		var origin: Vector3=world.Landscape.CENTERS[building.kind]
		var start: Vector3=origin+Vector3(-9,.15,-62)
		for floor_index in building.floors:
			var end: Vector3=origin+building.center+Vector3(0,floor_index*world.Architecture.STOREY+.13,0)
			var path:=NavigationServer3D.map_get_path(region.get_navigation_map(),start,end,true)
			check(not path.is_empty() and path[-1].distance_to(end)<.6,"connected interior "+building.role+" "+str(building.center)+" floor "+str(floor_index))
	# Shared streamed tile edges remain bit-identical with the authored source.
	var landscape:=world.Landscape.new()
	for coord in [Vector2i(28,28),Vector2i(32,32),Vector2i(35,35)]:
		var a: PackedFloat32Array=landscape.generate_tile(coord).heights.to_float32_array()
		var b: PackedFloat32Array=landscape.generate_tile(coord+Vector2i.RIGHT).heights.to_float32_array()
		for z in 65:check(a[z*65+64]==b[z*65],"tile seam")
	var edges: Dictionary={}
	var vertices:=nav.get_vertices()
	for i in nav.get_polygon_count():
		var poly:=nav.get_polygon(i)
		for j in poly.size():
			var a:=str(vertices[poly[j]]);var b:=str(vertices[poly[(j+1)%poly.size()]])
			var key:=a+":"+b if a<b else b+":"+a
			edges[key]=int(edges.get(key,0))+1
	for edge in edges:
		check(edges[edge]<=2,"navigation edge is manifold "+edge)
	var report:={"checks":checks,"errors":errors,"road_samples":road_samples,"access_lanes":world.Landscape.access_roads.size(),"raised_cover_points":elevated,"feature_totals":feature_totals,"environment_colliders":world.environment_colliders,"buildings":world.layout.buildings.size(),"navigation_polygons":nav.get_polygon_count()}
	DirAccess.make_dir_recursive_absolute("res://test-results/voxel-battle")
	FileAccess.open("res://test-results/voxel-battle/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VALLEY_VALIDATION ",JSON.stringify(report));world.free();await process_frame;quit(0 if errors.is_empty() else 1)
