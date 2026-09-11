extends RefCounted
## Authoritative blade contacts; physics never moves a tracked hand.
const Hit=preload("res://deathmatch/hit_detection.gd")
const Art=preload("res://deathmatch/art.gd")
const CC_RANGE:=.95
const RADIUS:=.065
const PARRY_DELAY:=.30
var contact_at: Dictionary={}

func reset() -> void:contact_at.clear()

static func blade(game: Node,id: int) -> Array[Vector3]:
	var pose: Transform3D=game._weapon_transform(id)
	var length: float=CC_RANGE if game.match_mode.kind=="cc" else game.W.DATA[1].range
	if not game.players[id].xr.is_empty():
		var tip: Vector3=Art.held_transform(pose,1)*Art.muzzle(1)
		return [pose.origin,tip-pose.basis.z*(.04 if game.match_mode.kind=="cc" else .09)]
	return [pose.origin,pose.origin-pose.basis.z*length]

func feedback(game: Node,id: int,pos: Vector3,normal: Vector3,other: int=0) -> void:
	if game.clock<float(contact_at.get(id,-1.0)):return
	contact_at[id]=game.clock+.18
	if other!=0:contact_at[other]=game.clock+.18
	game._saw_contact.rpc(pos,normal,id,other)

func fire(game: Node,id: int) -> void:
	var line:=blade(game,id)
	var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	# A VR hand on the far side of a wall cannot cut or parry through it.
	var chest: Vector3=game.fighters[id].position+Vector3.UP*game.fighters[id].torso_height()
	var obstruction:=space.intersect_ray(PhysicsRayQueryParameters3D.create(chest,line[0],1))
	if not obstruction.is_empty():feedback(game,id,obstruction.position,obstruction.normal);return
	var hit: Dictionary=game._trace(line[0],line[1],id,0.0,.035)
	var nearest: float=line[0].distance_to(hit.position)
	var other_id:=0
	var contact:=Vector3.ZERO
	for other in game.players:
		var s: Dictionary=game.players[other]
		if other==id or s.dead or s.spectator or s.weapon!=1 or game.match_mode.special.blocked(other):continue
		var guard:=blade(game,other)
		if line[0].distance_to(guard[0])>line[0].distance_to(line[1])+guard[0].distance_to(guard[1])+RADIUS*2:continue
		var possible:=Geometry3D.get_closest_points_between_segments(line[0],hit.position,guard[0],guard[1])
		if possible[0].distance_to(possible[1])>RADIUS*2 or line[0].distance_to(possible[0])>=nearest:continue
		if game._weapon_blocked(other):continue
		# Both segments stop at world geometry before testing blade contact.
		var fraction:=Hit.world_fraction(space,guard[0],guard[1],.035)
		guard[1]=guard[0].lerp(guard[1],minf(1.0,fraction))
		var points:=Geometry3D.get_closest_points_between_segments(line[0],hit.position,guard[0],guard[1])
		var distance:=line[0].distance_to(points[0])
		if points[0].distance_to(points[1])<=RADIUS*2 and distance<nearest:
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(points[0],points[1],1)).is_empty():continue
			nearest=distance;other_id=other;contact=(points[0]+points[1])*.5
	if other_id!=0:
		game.players[id].cooldown=maxf(game.players[id].cooldown,PARRY_DELAY)
		game.players[other_id].cooldown=maxf(game.players[other_id].cooldown,PARRY_DELAY)
		feedback(game,id,contact,(line[0]-line[1]).normalized(),other_id)
		return
	if hit.id!=0:
		var d: Dictionary=game.match_mode.fortress.weapon_data(id,1)
		game._damage(hit.id,id,d.damage*randi_range(1,d.dice),d.name,false,hit.position,(line[1]-line[0]).normalized())
	elif hit.has("building"):
		game.match_mode.fortress.damage_building(hit.building,id,game.W.DATA[1].damage*randi_range(1,game.W.DATA[1].dice))
	elif hit.hit:
		var wall:=space.intersect_ray(PhysicsRayQueryParameters3D.create(line[0],line[1],1))
		feedback(game,id,hit.position,wall.get("normal",(line[0]-line[1]).normalized()))
