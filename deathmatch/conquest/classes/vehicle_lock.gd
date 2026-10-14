extends RefCounted
const Attribution=preload("res://deathmatch/server/attribution.gd")
## Stinger-style acquisition: a fresh weapon aim, enemy hull, clear LOS and continuous dwell.
const RANGE:=200.0
const DWELL:=1.5
const CONE:=6.0
var locks:Dictionary={}
func targets(game) -> Dictionary:
	var result:Dictionary={}
	for vehicle in game.get_tree().get_nodes_in_group("cq_repairable_vehicles"):
		if vehicle.hp>0:result["v:"+str(vehicle.get_path())]={"position":vehicle.global_position,"team":vehicle.team,"node":vehicle}
	var walkers=game.match_mode.fortress.walkers
	for key in walkers.robots:
		var row:Dictionary=walkers.robots[key]
		if row.pilot!=0 and game.players.has(row.pilot) and not game.players[row.pilot].dead:result["w:"+str(key)]={"position":row.position+Vector3.UP*3.0,"team":row.team,"node":walkers.bodies.get(key)}
	return result
func clear_line(game,origin:Vector3,target:Dictionary) -> bool:
	var hit:Dictionary=Attribution.ray(game.get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(origin,target.position,1),"query.vehicle_lock.clear_line.ray")
	if hit.is_empty():return true
	var node=target.node
	return is_instance_valid(node) and (node.owns_collider(hit.collider) if node.has_method("owns_collider") else hit.collider==node)
func tick(game,delta:float) -> void:
	var candidates:=targets(game)
	for id in locks.keys():
		if not game.players.has(id):locks.erase(id)
	for id in game.players:
		var s:Dictionary=game.players[id]
		if not game.classes.alive(id) or s.weapon!=11 or s.get("input_blocked",false) or game.clock-s.last_input>.35:locks.erase(id);continue
		var shot:Dictionary=game._shot_solution(id)
		if shot.blocked:locks.erase(id);continue
		var forward:Vector3=-game._weapon_transform(id).basis.z
		var best:="";var score:=cos(deg_to_rad(CONE))
		for key in candidates:
			var target:Dictionary=candidates[key]
			if target.team==s.team or target.team not in [0,1] or shot.origin.distance_to(target.position)>RANGE:continue
			var alignment:float=forward.dot((target.position-shot.origin).normalized())
			if alignment>score and clear_line(game,shot.origin,target):best=key;score=alignment
		if best.is_empty():locks.erase(id);continue
		var row:Dictionary=locks.get(id,{})
		var elapsed:float=row.get("elapsed",0.0) if row.get("target","")==best and row.get("life",-1)==s.serial else 0.0
		elapsed=minf(DWELL,elapsed+delta)
		locks[id]={"target":best,"position":candidates[best].position,"elapsed":elapsed,"ready":elapsed>=DWELL,"life":s.serial}
func guide(game,delta:float) -> void:
	var candidates:=targets(game)
	for p in game.projectiles.values():
		if p.weapon!=11 or not p.has("velocity"):continue
		var target:Dictionary=candidates.get(p.extra.get("vehicle_target",""),{})
		if target.is_empty() or target.team==p.extra.get("guided_team",-1):continue
		var desired:Vector3=(target.position-p.position).normalized();var direction:Vector3=p.velocity.normalized()
		var angle:float=direction.angle_to(desired)
		if angle>.0001:p.velocity=direction.slerp(desired,minf(1.0,deg_to_rad(120.0)*delta/angle)).normalized()*p.velocity.length()
