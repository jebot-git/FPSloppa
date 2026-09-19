extends SceneTree
func _initialize():run.call_deferred()
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	var results: Dictionary={}
	for id in ["koth_solstice","koth_torture","koth_hyperborea","koth_alichar"]:
		game._load_map(id);game.match_mode.kind="koth";game.match_mode.reset()
		await physics_frame;await physics_frame
		var mesh=load("res://maps/navigation/"+id+".res");var vertices: PackedVector3Array=mesh.get_vertices()
		var rows: Array=[];var seen: Dictionary={};var space=game.get_world_3d().direct_space_state
		for index in mesh.get_polygon_count():
			var point:=Vector3.ZERO;var polygon=mesh.get_polygon(index)
			for vertex in polygon:point+=vertices[vertex]
			point/=polygon.size()
			var key:=Vector3i(point/2)
			if seen.has(key):continue
			seen[key]=true
			if point.distance_to(game.match_mode.hill)<14 or point.distance_to(game.match_mode.hill)>50:continue
			if not game.spawn_points.any(func(spawn):return spawn.distance_to(point)<22):continue
			var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP*2,1))
			if hit.is_empty() or hit.normal.y<.95:continue
			point=hit.position
			var low:=point.y;var high:=point.y;var clear:=true
			for radius in [0.,1.8,3.5]:
				for angle in 16:
					var sample:=point+Vector3(radius,0,0).rotated(Vector3.UP,TAU*angle/16)
					var floor=space.intersect_ray(PhysicsRayQueryParameters3D.create(sample+Vector3.UP*.6,sample-Vector3.UP*.6,1))
					if floor.is_empty() or floor.normal.y<.9:clear=false;break
					low=minf(low,floor.position.y);high=maxf(high,floor.position.y)
					var head=space.intersect_ray(PhysicsRayQueryParameters3D.create(floor.position+Vector3.UP*.15,floor.position+Vector3.UP*3.3,1))
					if not head.is_empty():clear=false;break
				if not clear:break
			if not clear or high-low>.35:continue
			var pickup_distance:=1000.
			for pickup in game.pickups:pickup_distance=minf(pickup_distance,point.distance_to(pickup.position))
			rows.append({"position":[point.x,high,point.z],"floor_delta":high-low,"pickup_distance":pickup_distance,"distance":point.distance_to(game.match_mode.hill)})
		rows.sort_custom(func(a,b):return a.distance>b.distance)
		var selected: Array=[]
		for row in rows:
			var point:=Vector3(row.position[0],row.position[1],row.position[2])
			if selected.any(func(other):return point.distance_to(Vector3(other.position[0],other.position[1],other.position[2]))<10):continue
			selected.append(row)
			if selected.size()>=12:break
		results[id]=selected;print("ROTATION_SURVEY ",id," ",JSON.stringify(selected))
	DirAccess.make_dir_recursive_absolute("res://test-results/koth-rotation")
	FileAccess.open("res://test-results/koth-rotation/survey.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	game.free();quit()
