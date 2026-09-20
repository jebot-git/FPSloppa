extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
func _initialize():
	create_timer(90).timeout.connect(func():quit(3))
	run.call_deferred()
func save(node: Node,path: String):
	var packed:=PackedScene.new();assert(packed.pack(node)==OK);assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
func run():
	var zone:=int(OS.get_cmdline_user_args()[0]);var campaign:=OS.get_cmdline_user_args().has("--campaign")
	var folder:=("res://maps/CampaignDistricts/" if campaign else "res://maps/CQDistricts/")+"district_%02d/"%zone
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"layout.json"))
	var level:=Loader.read(folder+"district.bsp");assert(level!=null);root.add_child(level)
	assert(level.get_meta("baked_light_invalid_faces",0)==0)
	assert(level.get_meta("baked_light_overflow_faces",0)==0)
	assert(level.get_meta("baked_light_rgb",false))
	var report:={"zone":zone,"bsp_sha256":FileAccess.get_sha256(folder+"district.bsp"),"baked_faces":level.get_meta("baked_light_faces",0),"invalid_faces":level.get_meta("baked_light_invalid_faces",0),"connected_routes":0,"gate_rays":0,"route_failures":[]}
	preload("res://deathmatch/maps/filtering.gd").new().apply(level,2,true)
	# Navigation and server collision come from this district only, before cosmetic art.
	var mesh:=preload("res://deathmatch/bots.gd").new_mesh();mesh.cell_size=.5;mesh.cell_height=.1;mesh.agent_radius=.5;mesh.agent_height=1.75;mesh.edge_max_length=12
	mesh.filter_baking_aabb=AABB(Vector3(-136,-1,-136),Vector3(272,33,272))
	var data:=NavigationMeshSourceGeometryData3D.new();NavigationServer3D.parse_source_geometry_data(mesh,data,level)
	NavigationServer3D.bake_from_source_geometry_data(mesh,data);assert(mesh.get_polygon_count()>0)
	mesh.set_meta("bsp_source_sha256",FileAccess.get_sha256(folder+"district.bsp"));assert(ResourceSaver.save(mesh,folder+"navigation.res")==OK)
	var nav:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(nav,true);NavigationServer3D.map_set_cell_size(nav,mesh.cell_size);NavigationServer3D.map_set_cell_height(nav,mesh.cell_height)
	var region:=NavigationRegion3D.new();level.add_child(region);region.set_navigation_map(nav);region.navigation_mesh=mesh
	for frame in 120:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav)>=2:break
	NavigationServer3D.map_set_active(nav,true);NavigationServer3D.map_force_update(nav)
	var points: Array=[]
	for p in layout.spawns:points.append(Vector3(p[0],p[1],p[2]))
	for room in layout.rooms:
		for p in room.points:points.append(Vector3(p[0],p[1],p[2]))
	for row in layout.routes:
		for key in ["from","to"]:var p: Array=row[key];points.append(Vector3(p[0],p[1],p[2]))
	for p in layout.pickup_positions+layout.street_points:points.append(Vector3(p[0],p[1],p[2]))
	for gate in layout.gates:
		var p:=Vector3(gate.position[0],.1,gate.position[2]);var n:=Vector3(gate.normal[0],0,gate.normal[2]);points.append(p-n*.6)
		for off in [-10,0,10]:
			var at: Vector3=p+n.cross(Vector3.UP)*off+Vector3.UP*1.5
			assert(level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+n*3,at-n*3,1)).is_empty(),"Blocked gate")
			report.gate_rays+=1
	for point in points:
		var nearest:=NavigationServer3D.map_get_closest_point(nav,point)
		if nearest.distance_to(point)>=1.2:report.route_failures.append("Point off navigation: %s / %s"%[point,nearest]);continue
		if point.distance_to(Vector3(-20,.1,-20))<.01:report.connected_routes+=1;continue
		var route:=NavigationServer3D.map_get_path(nav,Vector3(-20,.1,-20),point,true)
		if route.is_empty() or route[-1].distance_to(point)>1.2:report.route_failures.append("Unreachable district %d point %s end %s"%[zone,point,route[-1] if not route.is_empty() else Vector3.INF]);continue
		report.connected_routes+=1
	report.nav_polygons=mesh.get_polygon_count();region.free();NavigationServer3D.free_rid(nav)
	if not report.route_failures.is_empty():
		for failure in report.route_failures:push_error(failure)
		level.free();quit(2);return
	# Test the resulting collision, not merely the generator's roof-area estimate.
	if layout.has("enclosure"):
		var space:=level.get_world_3d().direct_space_state
		var enclosed:=0
		for sample in layout.enclosure.roof_samples:
			var at:=Vector3(sample[0],sample[1],sample[2])
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(at,at+Vector3.UP*80,1)).is_empty():enclosed+=1
		report.roof_samples=layout.enclosure.roof_samples.size();report.covered_samples=enclosed
		assert(float(enclosed)/report.roof_samples>=(.5 if layout.get("profile","")=="mixed" else .85),"Insufficient street enclosure")
		report.carriageway_rays=0
		for road in layout.streets:
			for i in road.size()-1:
				var a:=Vector3(road[i][0],1.4,road[i][1]);var b:=Vector3(road[i+1][0],1.4,road[i+1][1]);var sideways:=(b-a).normalized().cross(Vector3.UP)
				for step in range(3,int(a.distance_to(b))-2,4):
					var at:=a.move_toward(b,step)
					if maxf(absf(at.x),absf(at.z))>119:continue
					assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(at-sideways*3.4,at+sideways*3.4,1)).is_empty(),"Obstructed two-car lane %d %s"%[zone,at])
					report.carriageway_rays+=1
		report.open_courtyards=0
		for court in layout.enclosure.courtyards:
			var open_rays:=0
			for offset in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				var at:=Vector3(court.center[0]+offset.x*court.radius*.6,1.8,court.center[1]+offset.y*court.radius*.6)
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(at,at+Vector3.UP*80,1)).is_empty():open_rays+=1
			assert(open_rays>0,"Courtyard has no open sky")
			report.open_courtyards+=1
		var capsule:=CapsuleShape3D.new();capsule.radius=.45;capsule.height=1.8
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
		report.jetpack_clearance_samples=0
		for hop in layout.enclosure.jetpack_hops:
			# Geometric design envelope only: a straight 4 m hop with .8 m rise.
			# Includes the player's volume; this does not certify flight physics.
			for step in 21:
				var t:=step/20.0
				var at:=Vector3(hop.from[0],hop.from[1],hop.from[2]).lerp(Vector3(hop.to[0],hop.to[1],hop.to[2]),t)
				at.y+=1.05+sin(t*PI)*.8;query.transform=Transform3D(Basis.IDENTITY,at)
				assert(space.intersect_shape(query,1).is_empty(),"Blocked jetpack design envelope %d %s"%[zone,at])
				report.jetpack_clearance_samples+=1
	var server:=Loader.read(folder+"district.bsp",true);preload("res://deathmatch/server/geometry.gd").strip(server);save(server,folder+"collision.scn");server.free()
	var art:=Node3D.new();art.name="CityPresentation";art.set_script(preload("res://deathmatch/conquest/presentation.gd"));level.add_child(art);art.owner=level
	preload("res://tools/km_benchmark/city_art.gd").district(art,level,layout,int(layout.get("render_zone",zone)))
	if campaign:
		var overlay:=preload("res://deathmatch/server/cluster/campaign_visuals.gd").new();overlay.name="CampaignVisuals";overlay.metadata=layout.campaign;level.add_child(overlay);overlay.owner=level
		for child in overlay.get_children():child.owner=level
	for row in layout.occluder_boxes:
		var low:=Vector3(row.minimum[0],row.minimum[1],row.minimum[2]);var high:=Vector3(row.maximum[0],row.maximum[1],row.maximum[2]);var occluder:=OccluderInstance3D.new();var box:=BoxOccluder3D.new();box.size=(high-low-Vector3.ONE*.1).max(Vector3.ONE*.01);occluder.occluder=box;occluder.position=(high+low)*.5;level.add_child(occluder);occluder.owner=level
	save(level,folder+"presentation.scn");level.free()
	FileAccess.open(folder+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CQ_DISTRICT_PREPARED ",JSON.stringify(report));quit()
