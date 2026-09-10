extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	for name in ["tf_ironspan","tf_relayworks"]:
		var path: String=ProjectSettings.globalize_path("res://optional-tf-map-pack/"+name+".bsp")
		var row: Dictionary={"id":name,"title":name,"path":path,"scene":"user://"+FileAccess.get_sha256(path)+"-navtest.scn","sha256":FileAccess.get_sha256(path)}
		game.map_catalog=[row];check(game._load_map(name),"Load "+name);game.match_mode.kind="tf";game.match_mode.reset()
		await physics_frame;await physics_frame
		check(game.ctf_spawns[0].size()==4 and game.ctf_spawns[1].size()==4,"Both teams have four spawns "+name)
		check(game.map_objectives.size()==2 and game.match_mode.bases[0].distance_to(game.match_mode.bases[1])>30,"Distinct native flags "+name)
		check(game.tf_resupply[0].size()==1 and game.tf_resupply[1].size()==1,"Both teams have resupply "+name)
		var nav: NavigationMesh=preload("res://deathmatch/bots.gd").new_mesh()
		var source:=NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nav,source,game.get_node("Map").get_child(0))
		NavigationServer3D.bake_from_source_geometry_data(nav,source)
		var region:=NavigationRegion3D.new();region.navigation_mesh=nav;game.add_child(region)
		await physics_frame;await physics_frame
		var map: RID=region.get_navigation_map();NavigationServer3D.map_force_update(map)
		for attempt in range(100):
			if NavigationServer3D.map_get_iteration_id(map)>0 and NavigationServer3D.map_get_closest_point(map,game.ctf_spawns[0][0]).distance_to(game.ctf_spawns[0][0])<2:break
			await create_timer(.05).timeout
		print("NAV_POLYGONS ",name," ",nav.get_polygon_count()," active=",NavigationServer3D.map_is_active(map)," regions=",NavigationServer3D.map_get_regions(map)," iteration=",NavigationServer3D.map_get_iteration_id(map)," closest=",NavigationServer3D.map_get_closest_point(map,game.ctf_spawns[0][0]))
		for team in [0,1]:
			for point in game.ctf_spawns[team]:
				for goal in game.match_mode.bases+game.match_mode.captures:
					var route:=NavigationServer3D.map_get_path(map,point,goal,true)
					if route.size()<2 or route[-1].distance_to(goal)>=1:print("BAD_ROUTE ",point," -> ",goal," : ",route)
					check(route.size()>1 and route[-1].distance_to(goal)<1.0,"Connected spawn/flag/capture route "+name)
		ResourceSaver.save(nav,"res://optional-tf-map-pack/"+name+"-navigation.res")
		region.free()
	print("TF_MAPS_RESULT ",JSON.stringify(failures));game.free();quit(0 if failures.is_empty() else 1)
