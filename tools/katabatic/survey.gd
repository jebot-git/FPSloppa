extends SceneTree
## Survey actual imported collision before accepting equipment/route positions.
const Loader=preload("res://deathmatch/maps/loader.gd")
func _initialize():run.call_deferred()
func run():
	var level=Loader.read("res://maps/ctf_katabatic.bsp");assert(level!=null);root.add_child(level)
	await physics_frame;await physics_frame
	var space=level.get_world_3d().direct_space_state
	var shape:=CapsuleShape3D.new();shape.radius=.45;shape.height=1.8
	var report:={"points":[],"valid_portals":[],"corrections":[]}
	for node in level.find_children("*","Node3D",true,false):
		if node.get_script()!=preload("res://deathmatch/maps/entity.gd"):continue
		var kind: String=node.attributes.get("classname","")
		if not (kind.begins_with("info_player") or kind.begins_with("info_tribes_") or kind.begins_with("item_flag")):continue
		var p: Vector3=node.global_position-Vector3.UP*.7
		var floor_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.15,p-Vector3.UP*.25,1))
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform.origin=p+Vector3.UP*.95
		var clear: bool=space.intersect_shape(query,1).is_empty()
		var ok: bool=clear and not floor_hit.is_empty() and floor_hit.normal.y>.65
		if kind=="info_tribes_navigation":
			if ok:report.valid_portals.append([p.x,p.y,p.z])
			continue
		report.points.append({"kind":kind,"position":[p.x,p.y,p.z],"clear":clear,"supported":not floor_hit.is_empty()})
	FileAccess.open("res://test-results/st-katabatic/survey.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("KATABATIC_SURVEY ",JSON.stringify({"points":report.points.size(),"valid_portals":report.valid_portals.size(),"bad":report.points.filter(func(p):return not p.clear or not p.supported)}))
	level.free();quit()
