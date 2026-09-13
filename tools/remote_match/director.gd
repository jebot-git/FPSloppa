extends RefCounted
## Twelve seconds per view; a new player every two views.
static func frame(game,seconds: float) -> Dictionary:
	var ids: Array=game.players.keys().filter(func(id):return not game.players[id].spectator and game.fighters.has(id))
	ids.sort()
	if ids.is_empty() or not is_instance_valid(game.camera):return {}
	# This is a render-frame camera. Physics interpolation would retain the
	# replay/free-camera rotation and visually undo the directed look_at().
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var shot:=int(seconds/12)
	var id: int=ids[(shot/2)%ids.size()]
	var state: Dictionary=game.players[id];var actor=game.fighters[id]
	var eye: Vector3=actor.render_position()+Vector3.UP*actor.eye_height()
	var basis:=Basis(Vector3.UP,state.yaw)*Basis(Vector3.RIGHT,state.pitch)
	var offset:=Vector3(0,.8,3.5) if shot%3==0 else Vector3(3,1.8,3) if shot%3==1 else Vector3(-2,3.5,4.5)
	var target: Vector3=eye+basis*offset
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target,1))
	game.camera.global_position=hit.position+hit.normal*.18 if not hit.is_empty() else target
	game.camera.look_at(eye-basis.z*1.2)
	game.camera.fov=85
	return {"player":id,"name":state.name,"angle":shot%3,"mode":game.match_mode.kind,"map":game.current_map}
