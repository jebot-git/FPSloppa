extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	check(game.map_catalog.size()>=5,"five bundled maps")
	for row in game.map_catalog:
		check(game._load_map(row.id),row.title+" loads")
		await physics_frame
		await physics_frame
		check(game.spawn_points.size()>=8,row.title+" deathmatch spawns")
		check(game.pickups.size()>15,row.title+" pickups mapped")
		var floor_count:=0
		for pos in game.spawn_points:
			var query:=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.5,pos-Vector3.UP*4,1)
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): floor_count+=1
		check(floor_count==game.spawn_points.size(),row.title+" all spawns above solid floor (%d/%d)"%[floor_count,game.spawn_points.size()])
		print("MAP_DETAILS ",row.id," gates=",game.gates.size()," lifts=",game.lifts.size()," floor=",game.fall_limit)
	check(not game._load_map("entryway_debug"),"Removed Entryway map is unavailable")
	check(not game.map_catalog.any(func(row): return row.id=="entryway_debug"),"Entryway excluded from deathmatch catalog")
	check(not game._load_map("../../bad"),"unknown map identifiers rejected")
	print("MAP_TEST_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
