extends RefCounted
## Anticipate outdoor wall contacts using the body's travel, including descent.
## Corrections are ordinary walking, jump and jet inputs, never velocity edits.
const Physics=preload("res://deathmatch/movement/tribes.gd")
var ai_ref: WeakRef
var ai:
	get:return ai_ref.get_ref()
	set(value):ai_ref=weakref(value)

func wall(start: Vector3,end: Vector3) -> Dictionary:
	var side: Vector3=(end-start).normalized().cross(Vector3.UP)*.45
	var nearest: Dictionary={};var distance:=INF
	for height in [.08,.8,1.5]:
		for offset in [Vector3.ZERO,side,-side]:
			var hit: Dictionary=ai.navigation.ray(start+offset+Vector3.UP*height,end+offset+Vector3.UP*height)
			# Walkable terrain needs the slope controller, not wall avoidance.
			if hit.is_empty() or hit.normal.y>.35:continue
			var travel: float=start.distance_to(hit.position)
			if travel<distance:nearest=hit;distance=travel
	return nearest

func threat(id: int,wish: Vector3) -> Dictionary:
	var game=ai.game;var actor=game.fighters[id];var s: Dictionary=game.players[id]
	var acceleration:=Vector3.ZERO
	if not actor.is_supported():
		acceleration=Vector3.DOWN*20
		if s.jet_held and actor.tribes_state.energy>3:acceleration+=Physics.jet_acceleration(actor.velocity,wish,actor.tribes_state.airtime,s.tribes_class)
	var start: Vector3=actor.position
	for step in 7:
		var time: float=(step+1)*.2
		var end: Vector3=actor.position+actor.velocity*time+acceleration*.5*time*time
		var hit:=wall(start,end)
		if not hit.is_empty():hit.time=time;return hit
		start=end
	return {}

func steer(id: int,brain: Dictionary) -> void:
	var game=ai.game;var actor=game.fighters[id];var s: Dictionary=game.players[id]
	# Tower landings, indoor portals and flag catches have precise controllers.
	if brain.get("travel_phase","") not in ["ski","run_up","climb","coast"] or brain.get("staging",false):return
	var next: Vector3=brain.path[brain.step] if brain.step<brain.path.size() else brain.goal
	# A verified raised portal is an intended landing, not a wall to flank.
	# Let its lift/braking controller establish entry height before crossing.
	if actor.position.distance_to(brain.goal)<65 and ai.tribes.routes.covered(brain.goal) or next.y>actor.position.y+2 and actor.position.distance_to(next)<40 and ai.tribes.routes.clear(actor.position,next):
		brain.erase("st_obstacle");return
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z);var speed:=velocity.length()
	if actor.position.distance_to(brain.goal)<8:return
	var action: Dictionary=brain.get("st_obstacle",{})
	if not action.is_empty() and (game.clock>action.until or actor.position.distance_to(action.point)<2):
		brain.erase("st_obstacle");action={}
	if action.is_empty() and speed>3 and game.clock>=float(brain.get("obstacle_probe_at",0)):
		brain.obstacle_probe_at=game.clock+.12
		var wish:=Basis(Vector3.UP,s.yaw)*Vector3(s.move.x,0,s.move.y)
		var hit:=threat(id,wish)
		if not hit.is_empty():
			var forward:=velocity.normalized()
			var clear_over: bool=ai.navigation.ray(actor.position+Vector3.UP*1.8,actor.position+Vector3.UP*4.5).is_empty() and wall(actor.position+Vector3.UP*3,hit.position+forward*2+Vector3.UP*3).is_empty()
			if clear_over and hit.time<=.8 and actor.tribes_state.energy>10:
				action={"kind":"vault","point":hit.position+forward*4,"direction":forward,"until":game.clock+hit.time+.35}
			elif not clear_over:
				# Commit to one clear flank instead of alternating left/right at
				# the wall. Braking early is preferable to losing all speed on it.
				for angle in [40,-40,65,-65,85,-85,110,-110]:
					var direction:=forward.rotated(Vector3.UP,deg_to_rad(angle))
					var point: Vector3=actor.position+direction*clampf(speed*1.4,8,24)
					if not wall(actor.position,point).is_empty():continue
					var floor_hit: Dictionary=ai.navigation.ray(point+Vector3.UP*3,point-Vector3.UP*8)
					if floor_hit.is_empty() or floor_hit.normal.y<.6:continue
					action={"kind":"flank","point":floor_hit.position+Vector3.UP*.06,"until":game.clock+2.5};break
			if not action.is_empty():brain.st_obstacle=action;ai.tribes.tactics.count("obstacles_anticipated")
	if action.is_empty():return
	var desired: Vector3
	if action.kind=="vault":
		desired=action.direction*.15;s.ski=true;s.jet_held=true;s.jump=actor.is_supported() and not actor.jump_held
	else:
		var direction: Vector3=action.point-actor.position;direction.y=0;direction=direction.normalized()
		desired=direction;s.ski=false;s.jump=false;s.jet_held=false
		if not actor.is_supported():desired=(direction*speed-velocity).limit_length(1)*.65;s.ski=true;s.jet_held=actor.tribes_state.energy>3
	s.move=ai.tribes.movement(id,desired)
	brain.travel_phase="obstacle_"+action.kind
