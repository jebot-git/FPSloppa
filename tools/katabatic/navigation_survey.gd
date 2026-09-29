extends SceneTree
var g
func _initialize():run.call_deferred()
func vector(a):return Vector3(a[0],a[1],a[2])
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_katabatic";g.start_host("Katabatic navigation survey",0,100,15,true,"st")
	g.set_process(false);g.set_physics_process(false);await physics_frame;await physics_frame
	var routes=g.bots.tribes.routes;routes.build();var first: int=routes.points.size()
	var space=g.get_world_3d().direct_space_state
	var shape:=CapsuleShape3D.new();shape.radius=.45;shape.height=1.8
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	var candidates=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/st-katabatic/floor-candidates.json"))
	for a in candidates:
		var p: Vector3=vector(a);query.transform.origin=p+Vector3.UP*.95
		if not space.intersect_shape(query,1).is_empty():continue
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.12,p-Vector3.UP*.2,1))
		if hit.is_empty() or hit.normal.y<.65:continue
		routes.add(p)
	for i in range(first,routes.points.size()):
		for j in routes.nearby(routes.points[i]):
			if i==j or routes.points[i].distance_to(routes.points[j])>27:continue
			if routes.clear(routes.points[i],routes.points[j]):routes.graph.connect_points(i,j,false)
			if routes.clear(routes.points[j],routes.points[i]):routes.graph.connect_points(j,i,false)
	var selected: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/katabatic/portals.json"))
	for row in g.match_mode.tribes.stations().rows:
		var path=routes.path(g.ctf_spawns[row.team][0],row.position)
		print("SURVEY_ROUTE ",row.kind," ",row.position," nodes ",path.size())
		for p in path:
			var id: int=routes.graph.get_closest_point(p)
			if id<first:continue
			var item=[p.x,p.y,p.z]
			if item not in selected:selected.append(item)
	FileAccess.open("res://tools/katabatic/portals.json",FileAccess.WRITE).store_string(JSON.stringify(selected,"  "))
	print("SURVEY_SELECTED ",selected.size()," candidates ",routes.points.size()-first)
	g.disconnect_game();g.queue_free();await process_frame;quit()
