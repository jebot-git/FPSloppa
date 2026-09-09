extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	for row in g.map_catalog:
		g._load_map(row.id);g.match_mode.kind="ctf";g.match_mode.reset()
		var region:=NavigationRegion3D.new();g.add_child(region);region.navigation_mesh=load("res://deathmatch/maps/navigation/"+row.id+".res")
		for i in range(10):await physics_frame
		var nav: RID=region.get_navigation_map()
		for attempt in range(60):
			if NavigationServer3D.map_get_closest_point(nav,g.match_mode.bases[0]).distance_to(g.match_mode.bases[0])<2:break
			await physics_frame
		var points: Array=g.match_mode.bases.duplicate();points.append(g.match_mode.hill)
		for i in range(points.size()):
			var p: Vector3=points[i]
			var floor: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.5,p-Vector3.UP*2,1))
			check(not floor.is_empty() and floor.normal.y>.65,row.id+" objective %d has walkable floor"%i)
			var target:=NavigationServer3D.map_get_closest_point(nav,p)
			var path:=NavigationServer3D.map_get_path(nav,points[0],target,true)
			check(not path.is_empty() and path[-1].distance_to(target)<.5,row.id+" objective %d connected to red base"%i)
		for team in range(2):
			check(g.match_mode.spawns(team).size()>=2,row.id+" team %d has multiple home-side spawns"%team)
		# Exercise objective graphics even with the headless renderer.
		g.headless=false;g.match_mode.draw_objectives();check(g.match_mode.visuals.get_child_count()==4,row.id+" has two base markers and two flag models")
		g.match_mode.kind="koth";g.match_mode.draw_objectives();check(g.match_mode.visuals.get_child_count()==1,row.id+" has a hill marker")
		g.headless=true;region.free()
	print("TEAM_OBJECTIVES_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
