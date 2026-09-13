extends RefCounted
## Spawn selection runs before the physics server has synchronized every actor.
## Check live logical positions too, so simultaneous spawns cannot overlap and
## repeatedly lift each other's capsules during penetration recovery.
static func clear(game,id:int,point:Vector3)->bool:
	var runtime=game.get_node_or_null("Map/MapRuntime")
	if runtime:
		if runtime.has_contents and runtime.contents.at(point+Vector3.UP*.75) in [-4,-5]:return false
		for volume in runtime.regions:
			if volume.kind=="trigger_hurt" and runtime.node_bounds(volume.area).grow(.35).has_point(point):return false
	for other in game.players:
		if other==id or game.players[other].dead or game.players[other].spectator:continue
		var actor=game.fighters[other]
		if absf(point.y-actor.position.y)<1.7 and Vector2(point.x-actor.position.x,point.z-actor.position.z).length()<.7:return false
	var shape:=CapsuleShape3D.new();shape.radius=.31;shape.height=1.65
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.transform.origin=point+Vector3.UP*.84
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
static func position(game,id:int,preferred:Vector3)->Vector3:
	if clear(game,id,preferred):return preferred
	var space=game.get_world_3d().direct_space_state
	for radius:float in [.8,1.6,2.4]:
		for slot in 8:
			var angle:=TAU*float(posmod(slot+id,8))/8
			var probe:=preferred+Vector3(cos(angle),0,sin(angle))*radius
			var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(probe+Vector3.UP*.6,probe-Vector3.UP*.6,1))
			if hit.is_empty() or hit.normal.y<.7:continue
			var point:Vector3=hit.position+Vector3.UP*.05
			if clear(game,id,point):return point
	return preferred
