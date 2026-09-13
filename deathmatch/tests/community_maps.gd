extends SceneTree
var failures: Array=[]
var results: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var approved: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/community_maps/approved.json"))
	for row in approved:
		var id: String=row.id
		var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
		game.set_process(false);game.set_physics_process(false)
		game.selected_map=id;game.start_host("Community map audit",0,100,6,true,"dm")
		check(game.active and game.current_map==id,id+" starts through catalog")
		if not game.active:game.free();continue
		game.get_node("Map/MapRuntime").set_physics_process(false)
		await physics_frame;await physics_frame
		check(game.spawn_points.size()>=2,id+" supplies multiplayer spawns")
		check(game.pickups.size()>10,id+" supplies real weapon/ammo/health pickups")
		check(game.bots.ready_to_walk,id+" loads baked navigation")
		var space=game.get_world_3d().direct_space_state
		var blocked:=0
		for spawn in game.spawn_points:
			var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new()
			capsule.radius=.32;capsule.height=1.7;query.shape=capsule
			query.collision_mask=1;query.transform.origin=spawn+Vector3.UP*.9
			if not space.intersect_shape(query).is_empty():blocked+=1;print("BLOCKED_SPAWN ",id," ",spawn)
		check(blocked==0,id+" spawn capsules clear geometry")
		var runtime=game.get_node("Map/MapRuntime")
		var portals:=0;var broken:=0
		for region in runtime.regions:
			if region.kind=="trigger_teleport":
				portals+=1
				if not runtime.destinations.has(region.data.get("target","")):broken+=1
		check(broken==0,id+" all authored teleport triggers resolve to destinations")
		results.append({"id":id,"spawns":game.spawn_points.size(),"pickups":game.pickups.size(),"portals":portals,"doors":game.gates.size(),"lifts":game.lifts.size(),"blocked_spawns":blocked})
		game.free()
	FileAccess.open("res://docs/validation/community-maps.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"maps":results},"  "))
	print("COMMUNITY_MAPS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
