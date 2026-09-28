extends SceneTree
const Penetration=preload("res://deathmatch/counterstrike/penetration.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/de-restoration/penetration-fixture.json"))
	var world:=Node3D.new();root.add_child(world)
	# All boxes share one concave collider, exactly the merged-RID problem.
	var faces:=PackedVector3Array()
	for box in data.boxes:
		var mesh:=BoxMesh.new();mesh.size=Penetration.v3(box.size)
		var arrays:=mesh.get_mesh_arrays()
		for index in arrays[Mesh.ARRAY_INDEX]:faces.append(arrays[Mesh.ARRAY_VERTEX][index]+Penetration.v3(box.position))
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var triangles:=ConcavePolygonShape3D.new();triangles.set_faces(faces);shape.shape=triangles;body.add_child(shape);world.add_child(body)
	var p:=Penetration.new();check(p.configure(data.data,world),"Authored metadata validates")
	await physics_frame;await physics_frame
	var space:=world.get_world_3d().direct_space_state
	for row in [[0.0,true,.25],[5.0,false,2.0],[10.0,true,.125],[15.0,false,.3],[20.0,true,.2],[25.0,false,.02],[30.0,true,.25],[35.0,true,.125],[40.0,false,.625]]:
		var start:=Vector3(-2,1.3,row[0]);var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+Vector3.RIGHT*6,1))
		check(not hit.is_empty() and absf(hit.position.x)<.0001,"Actual merged collision entry at lane "+str(row[0]))
		var exit:=p.exit_surface(hit.position,Vector3.RIGHT,39.0/32)
		check(not exit.is_empty()==row[1],"Material/thickness limit at lane "+str(row[0]))
		if not exit.is_empty():check(absf(exit.thickness-float(row[2]))<.0001,"Exact connected-solid thickness at lane "+str(row[0]))
	var diagonal:=Vector3(1,0,.5).normalized()
	var passage:=p.exit_surface(Vector3(0,1.3,0),diagonal,39.0/32)
	check(not passage.is_empty() and absf(passage.thickness-.25/diagonal.x)<.0001,"Oblique incidence increases thickness")
	var first:=p.exit_surface(Vector3(0,1.3,35),Vector3.RIGHT,39.0/32)
	var second:=space.intersect_ray(PhysicsRayQueryParameters3D.create(first.position,Vector3(3,1.3,35),1))
	check(not second.is_empty() and absf(second.position.x-.5)<.0001,"Second wall on the SAME collider remains hittable after exit")
	check(p.exit_surface(Vector3(0,1.3,25),Vector3.RIGHT,45.0/32).is_empty(),"Unknown material fails closed")
	check(p.exit_surface(Vector3(0,1.3,99),Vector3.RIGHT,45.0/32).is_empty(),"Missing volume fails closed")
	var malformed: Dictionary=data.data.duplicate(true);malformed.tree[0][2]=false;malformed.tree[0][3]=[0]
	check(not Penetration.new().configure(malformed,world),"Cyclic volume tree is rejected")
	check(Penetration.WEAPONS[9][0]==2 and Penetration.WEAPONS[6][0]==1 and not Penetration.WEAPONS.has(11),"AWP/rifle/P90 penetration counts match source firing calls")
	var report:={"checks":checks,"failures":failures,"passed":failures.is_empty(),"actual_physics":"Merged concave collider; entry and second-wall traces use Godot physics"}
	FileAccess.open("res://test-results/de-restoration/penetration-physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PENETRATION_PHYSICS_RESULT ",JSON.stringify(report));world.free();quit(0 if failures.is_empty() else 1)
