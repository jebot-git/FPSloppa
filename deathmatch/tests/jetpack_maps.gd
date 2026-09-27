extends SceneTree
var g
var checks:=0
var failures: Array=[]
var maps: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	for row in g.map_catalog:
		if not (row.id.begins_with("qsrc_dm") or row.id.begins_with("ctf_") and row.get("distribution","")=="base" or row.id=="de_dust2_rebuilt"):continue
		var mode: String="ctf" if "ctf" in row.modes else "dm"
		g.match_mode.configure({"sv_gametype":mode,"sv_jetpacks":1})
		var loaded: bool=g._load_map(row.id);check(loaded,row.id+": loads");if not loaded:continue
		await physics_frame;await physics_frame;g.match_mode.reset()
		var positions: Array=g.jetpacks.positions()
		check(positions.size()==(2 if mode=="ctf" else 1),row.id+": capped pickup count")
		for i in positions.size():
			var point: Vector3=positions[i]
			var space=g.get_world_3d().direct_space_state
			var floor_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.3,point-Vector3.UP*.5,1))
			check(not floor_hit.is_empty() and floor_hit.normal.y>.7,row.id+": pickup rests on a floor")
			var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.65
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform.origin=point+Vector3.UP*.85
			check(space.intersect_shape(query,1).is_empty(),row.id+": player capsule can occupy pickup")
			check(g.pickups.all(func(p):return p.kind=="jetpack" or p.position.distance_to(point)>1.3),row.id+": jetpack does not overlap another pickup")
			if mode=="ctf":check(point.distance_squared_to(g.match_mode.bases[i])<point.distance_squared_to(g.match_mode.bases[1-i]),row.id+": one pack per base region")
		maps.append({"map":row.id,"mode":mode,"positions":positions.map(func(p):return [p.x,p.y,p.z])})
		print("JETPACK_MAP ",row.id," ",positions)
	var result:={"checks":checks,"failures":failures,"maps":maps,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/jetpacks/maps.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("JETPACK_MAPS_RESULT ",JSON.stringify({"checks":checks,"maps":maps.size(),"failures":failures}));g.free();quit(0 if failures.is_empty() else 1)
