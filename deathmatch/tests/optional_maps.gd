extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
var failures: Array=[]
var reports: Array=[]
func _initialize():call_deferred("run")
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var args:=OS.get_cmdline_user_args()
	var threewave:=args.has("--threewave")
	var paths: Array=[]
	if threewave:
		var directory: String=args[args.find("--threewave")+1]
		for number in range(1,7):paths.append(directory.path_join("threewave_ctf2m%d.bsp"%number))
	else:
		for number in range(9,14):paths.append("res://optional-map-pack/lqdm%d.bsp"%number)
	for path: String in paths:
		var report: Dictionary={"map":path.get_file().get_basename(),"validation":Maps.validate(path),"meshes":0,"triangles":0,"collision_shapes":0,"invalid_triangles":0,"spawn_checks":[],"teleports":0}
		if not report.validation.is_empty():failures.append(report);continue
		var map:=Maps.read(path)
		if not map:failures.append("Cannot parse "+path);continue
		world.add_child(map);await physics_frame;await physics_frame
		for node in map.find_children("*","MeshInstance3D",true,false):
			if not node.mesh:continue
			report.meshes+=1
			var faces:=PackedVector3Array()
			for surface in range(node.mesh.get_surface_count()):
				var arrays: Array=node.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				if indices.is_empty():faces.append_array(vertices)
				else:
					for index in indices:faces.append(vertices[index])
			report.triangles+=faces.size()/3
			for i in range(0,faces.size(),3):
				if not faces[i].is_finite() or not faces[i+1].is_finite() or not faces[i+2].is_finite() or (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()<1e-14:
					report.invalid_triangles+=1
					if report.invalid_triangles<3:print("BAD_TRIANGLE ",node.name," ",faces.slice(i,i+3))
		for node in map.find_children("*","CollisionShape3D",true,false):
			if node.shape is ConcavePolygonShape3D:
				var faces: PackedVector3Array=node.shape.get_faces()
				for triangle in range(0,faces.size(),3):
					if (faces[triangle+1]-faces[triangle]).cross(faces[triangle+2]-faces[triangle]).length_squared()<1e-14:failures.append("Degenerate collision in "+path)
		report.collision_shapes=map.find_children("*","CollisionShape3D",true,false).size()
		var destinations: Array=[]
		for node in map.get_children():
			if "attributes" in node and node.attributes.get("classname","")=="info_teleport_destination":destinations.append(node.attributes.get("targetname",""))
		for node in map.get_children():
			if not "attributes" in node:continue
			var kind: String=node.attributes.get("classname","")
			if kind=="trigger_teleport":
				report.teleports+=1
				if not destinations.has(node.attributes.get("target","")):failures.append("Unresolved teleport in "+path)
			if not kind in ["info_player_deathmatch","info_player_team1","info_player_team2"]:continue
			var pos: Vector3=node.global_position-Vector3.UP*.70
			var floor:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.15,pos-Vector3.UP*4,1))
			var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.29;capsule.height=1.63;query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.835);query.collision_mask=1;query.margin=0.001
			var blocked:=not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
			report.spawn_checks.append({"position":[pos.x,pos.y,pos.z],"floor":not floor.is_empty(),"blocked":blocked})
			if floor.is_empty() or blocked:failures.append("Unsafe spawn in "+path+": "+str(pos))
		if report.meshes==0 or report.collision_shapes==0 or report.invalid_triangles>0:failures.append("Invalid geometry: "+str(report))
		reports.append(report);map.free();await physics_frame
	var output:="res://test-results/threewave-validation.json" if threewave else "res://optional-map-pack/validation.json"
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"maps":reports,"failures":failures},"  "));file.close()
	print("OPTIONAL_MAPS_RESULT ",JSON.stringify(failures));world.free();quit(0 if failures.is_empty() else 1)
