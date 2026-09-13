extends RefCounted
## Public payload state drives roles; combat still requires ordinary perception.
var ai
func robot() -> Dictionary:
	var rows: Dictionary=ai.game.match_mode.fortress.walkers.robots
	return rows.values()[0] if not rows.is_empty() else {}
func pilot_input(id: int,brain: Dictionary) -> bool:
	var game=ai.game
	if game.match_mode.kind!="tb" or not game.match_mode.fortress.walkers.mounted(id):return false
	var s: Dictionary=game.players[id]
	s.move=Vector2.ZERO;s.jump=false;s.fire=false;s.alt_fire=false;s.swim=Vector3.ZERO;s.slow=false;s.crouch=false;s.prone=false
	brain.role="pilot";brain.goal_kind="pilot";brain.goal_key="tb:piloting";brain.hold=true;brain.enemy=0;brain.path=PackedVector3Array()
	return true
func goals(id: int,brain: Dictionary,rows: Array) -> void:
	var game=ai.game;var tb=game.match_mode.titanball;var w=game.match_mode.fortress.walkers
	var r:=robot()
	if r.is_empty():return
	var slot: int=ai.team_rank(id);var attacking: bool=game.players[id].team==tb.ATTACKERS
	var assigned: int=ai.objectives.nearest(id,w.transform(r)*w.LADDER,"tb:pilot") if attacking and r.pilot==0 else 0
	var high: bool=false
	if assigned!=id:high=high_ground(id,rows,r,attacking)
	if attacking and assigned==id:
		brain.role="board"
		ai.candidate(rows,"tb:board","tb_board",w.transform(r)*w.LADDER,650,true)
	elif attacking:
		brain.role="escort"
		var distance: float=12.0 if tb.preparing() else minf(298.,r.distance+8.+float(slot%3)*4)
		var pose: Transform3D=w.Route.sample(r.path,distance)
		var side:=1.0 if slot%2==0 else -1.0
		var point: Vector3=ai.navigation.project_local(pose*Vector3(side*(7.+slot%3),0,0))
		ai.candidate(rows,"tb:escort:%s"%slot,"guard",point,160 if high else 220,true);rows[-1].look=pose.origin+pose.basis.z*18
	else:
		brain.role="intercept"
		var distance: float=clampf(r.distance+20.+float(slot%3)*7,30,294)
		var pose: Transform3D=w.Route.sample(r.path,distance)
		var side:=1.0 if slot%2==0 else -1.0
		var point: Vector3=pose*Vector3(side*(9.+slot%3*2),0,0)
		# Sample real ledges/overpasses when present, with planner/nav reachability checks.
		var floor_hit: Dictionary=ai.navigation.ray(point+Vector3.UP*15,point-Vector3.UP)
		if not floor_hit.is_empty() and floor_hit.normal.y>.7:point=floor_hit.position
		ai.candidate(rows,"tb:intercept:%s"%slot,"defend" if game.match_mode.fortress.enabled() and game.players[id].tf_class=="engineer" else "guard",ai.navigation.project_local(point),160 if high else 235,true)
		rows[-1].look=r.position+Vector3.UP*5
		ai.candidate(rows,"tb:ground:%s"%slot,"guard",ai.navigation.project_local(pose*Vector3(side*7,0,0)),145 if high else 205,true);rows[-1].look=r.position+Vector3.UP*5
	supplies(id,rows)
func high_ground(id: int,rows: Array,r: Dictionary,attacking: bool) -> bool:
	var game=ai.game;var tb=game.match_mode.titanball
	if not game.players[id].tf_class in ["soldier","demoman"] or attacking and tb.preparing():return false
	var desired_side: int=-1 if game.players[id].tf_class=="soldier" else 1
	var selected:=-1;var score:=INF
	for i in tb.vantages.size():
		var point: Dictionary=tb.vantages[i]
		var ahead: float=point.distance-r.distance
		if ahead<(-30. if attacking else -8.) or ahead>(50. if attacking else 105.):continue
		var candidate_score: float=absf(ahead-(12. if attacking else 35.))+(0. if point.side==desired_side else 35.)
		# Prefer the edge facing the current payload, retaining a fixed authored goal.
		candidate_score+=point.position.distance_to(r.position)*.05
		if candidate_score<score:score=candidate_score;selected=i
	if selected<0:return false
	var target: Vector3=tb.vantages[selected].position
	ai.candidate(rows,"tb:high:%s"%selected,"guard",target,460,true);rows[-1].look=r.position+Vector3.UP*7
	return true
func supplies(id: int,rows: Array) -> void:
	var game=ai.game;var tf=game.match_mode.fortress;var s: Dictionary=game.players[id]
	var missing: float=1.-float(s.hp)/tf.max_health(id)
	var ammo_need:=0.0
	for ammo in 4:ammo_need=maxf(ammo_need,ai.ammo_value(id,ammo)/70.)
	var need:=maxf(missing,ammo_need)
	if need<.35:return
	var value:=650. if missing>.65 or ammo_need>.92 else 150.*need
	for key in tf.buildings:
		var b: Dictionary=tf.buildings[key]
		if b.kind=="dispenser" and (b.get("universal",false) or b.team==s.team) and game.clock>=b.ready:
			ai.candidate(rows,"tb:supply:%s"%key,"supply",b.position,value,true)
func steering(id: int,brain: Dictionary,desired: Vector3) -> Vector3:
	var game=ai.game
	if game.match_mode.kind!="tb":return desired
	var w=game.match_mode.fortress.walkers;var r:=robot()
	if r.is_empty():return desired
	var s: Dictionary=game.players[id];var actor=game.fighters[id]
	if s.team==game.match_mode.titanball.ATTACKERS:
		if brain.goal_kind=="tb_board" and w.ladder_visible(r):
			var offset: Vector3=actor.position-w.transform(r)*w.LADDER
			if Vector2(offset.x,offset.z).length()<1.1 and absf(offset.y)<1.8:
				s.jump=not actor.jump_held;s.fire=false;s.alt_fire=false;return Vector3.ZERO
		return desired
	# Keep the next two metres of motion outside the known moving foot envelope.
	# This remains active when parked, since an attacker can board at any moment.
	var centre: Vector3=w.transform(r)*w.CRUSH_OFFSET
	if absf(actor.position.y-centre.y)>w.CRUSH_HEIGHT+1:return desired
	var away: Vector3=actor.position-centre;away.y=0
	var ahead: Vector3=actor.position+desired*2;var closest:=Geometry3D.get_closest_point_to_segment(centre,actor.position,ahead)
	if Vector2(closest.x-centre.x,closest.z-centre.z).length()<w.CRUSH_RADIUS+1.5:
		var radial:=away.normalized() if away.length()>.01 else Vector3.RIGHT
		var tangent:=radial.cross(Vector3.UP)
		if tangent.dot(brain.goal-actor.position)<0:tangent=-tangent
		desired=(radial*(1. if away.length()<w.CRUSH_RADIUS+1.5 else .25)+tangent*.8).normalized();s.jump=false
	return desired
