extends SceneTree
## Rebuild authored objective coordinates from the bundled, baked walkable geometry.
func _initialize():call_deferred("run")
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
	for row in rows:
		game._load_map(row.id);await physics_frame;await physics_frame
		var region:=NavigationRegion3D.new();game.add_child(region)
		region.navigation_mesh=load("res://deathmatch/maps/navigation/"+row.id+".res")
		var nav_map: RID=region.get_navigation_map()
		for attempt in range(10):await physics_frame
		var best:=-1.0;var bases: Array=[];var route:=PackedVector3Array()
		for a in game.spawn_points:
			for b in game.spawn_points:
				var start:=NavigationServer3D.map_get_closest_point(nav_map,a);var end:=NavigationServer3D.map_get_closest_point(nav_map,b)
				if start.distance_to(a)>1.5 or end.distance_to(b)>1.5:continue
				var path:=NavigationServer3D.map_get_path(nav_map,start,end,true)
				if path.is_empty() or path[-1].distance_to(end)>.5:continue
				if a.distance_squared_to(b)>best:best=a.distance_squared_to(b);bases=[a,b];route=path
		if bases.is_empty():push_error("No connected objective bases on "+row.id);quit(1);return
		var hill: Vector3=bases[0];var quality:=-1e9
		for i in range(1,route.size()):
			var count:=maxi(1,ceili(route[i-1].distance_to(route[i])))
			for j in range(count):
				var point:=route[i-1].lerp(route[i],float(j)/count)+Vector3.UP*.1
				var space:=0.0
				for n in range(12):
					var direction:=Vector3(cos(n*TAU/12),0,sin(n*TAU/12))
					var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point+Vector3.UP+direction*3,1))
					space+=3.0 if hit.is_empty() else hit.position.distance_to(point+Vector3.UP)
				var value: float=space-absf(point.distance_to(bases[0])-point.distance_to(bases[1]))*.5
				if value>quality:quality=value;hill=point
		bases=[safe_base(game,bases[0],route),safe_base(game,bases[1],route)]
		row.objectives={"red":array(bases[0]),"blue":array(bases[1]),"hill":array(hill)}
		row.modes=["dm","tdm","ctf","koth"]
		print("OBJECTIVES ",row.id," distance=",sqrt(best)," path_points=",route.size()," hill=",hill)
		region.free()
	var file:=FileAccess.open("res://deathmatch/maps/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  ")+"\n");file.close()
	game.free();quit()
func array(v: Vector3) -> Array:return [snappedf(v.x,.001),snappedf(v.y,.001),snappedf(v.z,.001)]

func safe_base(game: Node3D,original: Vector3,route: PackedVector3Array) -> Vector3:
	var best:=original;var quality:=-1e9
	for i in range(1,route.size()):
		for step in range(6):
			var point:=route[i-1].lerp(route[i],step/5.0)
			if point.distance_to(original)>6:continue
			var floor: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP*2,1))
			if floor.is_empty() or floor.normal.y<.9:continue
			point=floor.position+Vector3.UP*.06
			var minimum:=2.0;var total:=0.0
			for n in range(16):
				var direction:=Vector3(cos(n*TAU/16),0,sin(n*TAU/16))
				var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point+Vector3.UP+direction*2,1))
				var distance: float=2.0 if hit.is_empty() else hit.position.distance_to(point+Vector3.UP)
				minimum=minf(minimum,distance);total+=distance
			var score: float=minimum*8+total*.1-point.distance_to(original)*.2
			if score>quality:quality=score;best=point
	return best
