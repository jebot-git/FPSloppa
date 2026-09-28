extends RefCounted
## Hash-bound lane knowledge and public-objective jobs, never enemy positions.
const Maps=preload("res://deathmatch/modes/defusal_maps.gd")
var bank: Dictionary={}
var assigned:=0
var assignment_until:=0.0
var assignment_round:=-1
var assignment_role:=-1
var assignment_bomb:=Vector3.INF
func profile(de) -> Dictionary:
	if bank.is_empty():
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/defusal_tactics.json"))
		if data is Dictionary:bank=data
	for row in bank.values():
		if row.sha256==de.game.map_sha:return row
	return {}
func bomb_floor(de) -> Vector3:
	var target: Vector3=de.bomb_position
	var hit: Dictionary=de.ray_surface(target+Vector3.UP*.1,target-Vector3.UP*5)
	return hit.position+Vector3.UP*.05 if not hit.is_empty() else target
func worker(de,ai,role: int=1) -> int:
	if role==1 and de.alive(de.defuser):return de.defuser
	if assignment_role==role and assignment_round==de.round_id and assignment_bomb==de.bomb_position and de.game.clock<assignment_until and de.alive(assigned) and de.role(assigned)==role:return assigned
	assigned=0;assignment_round=de.round_id;assignment_bomb=de.bomb_position;assignment_until=de.game.clock+.8;assignment_role=role
	var best:=INF
	var target:=bomb_floor(de)
	for friend in ai.brains:
		if not de.alive(friend) or de.role(friend)!=role:continue
		var origin: Vector3=de.game.fighters[friend].position
		var route: PackedVector3Array=ai.navigation.path(origin,target)
		var distance: float=ai.navigation.cost(origin,target,route)
		if not is_finite(distance):continue
		# The project uses wire/key interactions, so this is a kit preference,
		# not a claim to reproduce retail CS's five/ten second timers.
		var score: float=distance/4.0+(0.0 if role==0 or de.account(friend).kit else 2.0)
		if score<best or is_equal_approx(score,best) and friend<assigned:best=score;assigned=friend
	return assigned
func approach(de,ai,id: int,site: int,data: Dictionary) -> Vector3:
	var target: Vector3=de.sites[site]
	if data.is_empty():return target
	var brain: Dictionary=ai.brains[id]
	var lanes: Array=data.attacks[site]
	var signature: String="%s:%s:%s"%[de.round_id,de.game.players[id].serial,site]
	if brain.get("de_route_life","")!=signature:
		brain.de_route_life=signature;brain.de_route_step=0;brain.de_route_at=de.game.clock
		brain.de_route_lane=posmod(ai.team_rank(id)+de.round_id,lanes.size())
	var points: Array=lanes[brain.de_route_lane].points
	var origin: Vector3=de.game.fighters[id].position
	# Recovery should not send a new carrier back through its opening route.
	if id==de.carrier and int(brain.get("de_recovery_round",-1))==de.round_id:brain.de_route_step=points.size()
	while brain.de_route_step<points.size():
		var next: Vector3=Maps.vector(points[brain.de_route_step])
		if origin.distance_to(next)<1.5:
			brain.de_route_step+=1;brain.de_route_at=de.game.clock;continue
		# Combat/dynamic obstructions cannot trap a team at a stale lane forever.
		if de.game.clock-float(brain.de_route_at)>18:
			brain.de_route_step=points.size();break
		return next
	return target
func guard(de,ai,id: int,site: int,data: Dictionary,postplant: bool) -> Vector3:
	var anchor: Vector3=bomb_floor(de) if postplant else de.sites[site]
	var brain: Dictionary=ai.brains[id]
	brain.de_watch=de.bomb_position if postplant else anchor
	if data.is_empty():return ai.defense_point(id,anchor)
	var holds: Array=data.holds[site]
	var rank: int=ai.team_rank(id)
	for offset in holds.size():
		var row: Dictionary=holds[posmod(floori(rank/2.0)+offset,holds.size())]
		var point: Vector3=Maps.vector(row.position)
		if ai.navigation.ready() and NavigationServer3D.map_get_closest_point(ai.region.get_navigation_map(),point).distance_to(point)>.5:continue
		if postplant and (absf(point.y-anchor.y)>2 or not ai.navigation.ray(point+Vector3.UP*1.2,de.bomb_position+Vector3.UP*.1).is_empty()):continue
		var occupied:=false
		for friend in ai.brains:
			if friend!=id and de.alive(friend) and de.mode.same_team(id,friend) and ai.brains[friend].goal.distance_to(point)<1.2:occupied=true;break
		if occupied:continue
		brain.de_watch=de.bomb_position if postplant else Maps.vector(row.watch)
		return point
	return ai.defense_point(id,anchor)
func goals(de,ai,id: int,rows: Array):
	var data:=profile(de)
	var site: int=de.round_id%2
	var brain: Dictionary=ai.brains[id]
	if de.planted:
		site=clampi(de.planted_site,0,1)
		if de.role(id)==1 and worker(de,ai)==id:
			var target:=bomb_floor(de)
			ai.candidate(rows,"de:defuse","objective",target,600,true)
		else:ai.candidate(rows,"de:guard:%s"%id,"defend",guard(de,ai,id,site,data,true),260,true)
	elif de.role(id)==0:
		if de.carrier==0:
			brain.de_recovery_round=de.round_id
			if worker(de,ai,0)==id:ai.candidate(rows,"de:recover","objective",de.bomb_position,480,true)
			else:
				brain.de_watch=de.bomb_position
				ai.candidate(rows,"de:cover-bomb:%s"%id,"defend",ai.defense_point(id,de.bomb_position),260,true)
		else:
			var target:=approach(de,ai,id,site,data)
			ai.candidate(rows,"de:plant" if de.carrier==id else "de:escort","objective",target,550 if de.carrier==id else 300,true)
	else:
		site=ai.team_rank(id)%2
		ai.candidate(rows,"de:site:%s"%id,"defend",guard(de,ai,id,site,data,false),230,true)
