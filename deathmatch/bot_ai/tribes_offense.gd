extends RefCounted
## Flag exits, support fire and optional skill moves use ordinary equipment/input.
const Ballistics=preload("res://deathmatch/tribes/ballistics.gd")
var ai
var passes: Dictionary={}
var epoch:=-1
var stats: Dictionary={}
func tick():
	var game=ai.game
	if epoch!=game.map_epoch:epoch=game.map_epoch;passes.clear();stats.clear()
	for id in passes.keys():
		var row: Dictionary=passes[id]
		if game.match_mode.flags[1-row.team].carrier==id:count("flag_pass_catches");passes.erase(id)
		elif not ai.alive(id) or game.clock>row.until:count("flag_pass_misses");passes.erase(id)
func count(key: String):stats[key]=int(stats.get(key,0))+1
func travel_look(id: int,brain: Dictionary,point: Vector3):
	var actor=ai.game.fighters[id]
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
	# Look back periodically while escaping, as a player can while skiing.
	# This only rotates the view; ordinary FOV/LOS/reaction still acquires and
	# fires at a pursuer. Steering converts its world direction after this turn.
	if ai.tribes.carrier(id) and velocity.length()>3 and actor.position.distance_to(brain.goal)>30 and fmod(ai.game.clock,3.5)<1.2:
		point=ai.eye(id)-velocity.normalized()*30
	ai.aim(id,point,.08)
func screen_enemy(id: int,brain: Dictionary) -> bool:
	# A player covering the grab/escape takes precedence over optional base
	# damage. Only current perception can trigger this, never shared wall vision.
	var enemy: int=brain.enemy
	if enemy not in brain.visible or not ai.alive(enemy):return false
	var game=ai.game;var team: int=game.players[id].team
	if team not in [0,1]:return false
	var position: Vector3=game.fighters[id].position
	var threat: Vector3=game.fighters[enemy].position
	if position.distance_to(threat)>80:return false
	var carrier: int=game.match_mode.flags[1-team].carrier
	if ai.alive(carrier) and threat.distance_to(game.fighters[carrier].position)<65:return true
	if brain.role not in ["capper","escort","siege"]:return false
	var flag: Vector3=game.match_mode.bases[1-team]
	return position.distance_to(flag)<130 and threat.distance_to(flag)<55
func escort_priority(id: int,enemy: int) -> float:
	var game=ai.game;var team: int=game.players[id].team
	if team not in [0,1] or ai.tribes.assignments.get(id,"")!="escort":return 0
	var carrier: int=game.match_mode.flags[1-team].carrier
	if not ai.alive(carrier):return 0
	return maxf(0,35-game.fighters[enemy].position.distance_to(game.fighters[carrier].position)*.65)
func screen_goal(id: int,brain: Dictionary,rows: Array) -> bool:
	var game=ai.game;var team: int=game.players[id].team
	if game.match_mode.flags[1-team].carrier!=0:return false
	var flag: Vector3=game.match_mode.bases[1-team]
	var observed: Array=ai.teamplay.intel(id).map(func(row):return row.position)
	for enemy in brain.visible:
		if ai.alive(enemy):observed.append(game.fighters[enemy].position)
	observed=observed.filter(func(point):return point.distance_to(flag)<55)
	if observed.is_empty():return false
	if game.clock>=float(brain.get("screen_site_at",0)):
		brain.screen_site_at=game.clock+2;brain.erase("screen_site")
		ai.tribes.routes.build();var best:=INF
		for point in ai.tribes.routes.points:
			var distance: float=point.distance_to(flag)
			if distance<18 or distance>65:continue
			if not observed.any(func(threat):return ai.navigation.ray(point+Vector3.UP*1.6,threat+Vector3.UP).is_empty()):continue
			var cost: float=game.fighters[id].position.distance_to(point)+absf(distance-30)
			if cost<best:best=cost;brain.screen_site=point
	if not brain.has("screen_site"):return false
	ai.candidate(rows,"st:screen","objective",brain.screen_site,330);return true
func flag_run(id: int,brain: Dictionary) -> bool:
	# A flag is a swept touch, not a station to stop at. Cross the deck at
	# walking/skiing speed; the next physics tick immediately plans the exit.
	if brain.goal_key not in ["st:flag","st:capture"]:return false
	var game=ai.game;var s: Dictionary=game.players[id];var actor=game.fighters[id]
	var flag: Dictionary=game.match_mode.flags[1-s.team]
	if brain.goal_key=="st:flag" and (flag.carrier!=0 or flag.dropped):return false
	if brain.goal_key=="st:capture" and not ai.tribes.carrier(id):return false
	var offset: Vector3=brain.goal-actor.position
	var flat:=Vector3(offset.x,0,offset.z);var distance:=flat.length()
	# Torso LOS can be clear while the feet are still below the shelf edge.
	# Keep flight control until the feet can actually cross onto the deck.
	if distance>16 or offset.y>.15 or offset.y< -1.8:return false
	if not ai.navigation.ray(actor.position+Vector3.UP*.2,brain.goal+Vector3.UP*.2).is_empty():return false
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z);var speed:=velocity.length()
	var direction:=flat.normalized()
	if direction.is_zero_approx():direction=velocity.normalized()
	var profile: Dictionary=game.match_mode.tribes.definition(id)
	var cross_speed:=velocity.slide(direction).length()
	var aligned: bool=velocity.dot(direction)>0 and cross_speed*distance/maxf(1,speed)<.65
	var desired: Vector3=direction
	s.jump=false;s.jet_held=false;s.ski=aligned and speed>profile.walk
	if not actor.is_supported():
		desired=((direction*maxf(profile.walk,speed)-velocity)*.16).limit_length(.6)
		var eta:=clampf(distance/maxf(profile.walk,speed),.05,1.5)
		var landing: float=actor.position.y+actor.velocity.y*eta-10*eta*eta
		s.jet_held=actor.tribes_state.energy>3 and (not aligned and cross_speed>.6 or landing<brain.goal.y+.2)
		s.ski=true
	if brain.enemy==0 and game.clock>=float(brain.get("equipment_aim_until",0)):ai.aim(id,brain.goal+Vector3.UP,.08)
	s.move=ai.tribes.movement(id,desired);s.prone=false;s.crouch=false;s.swim=Vector3.ZERO
	brain.travel_phase="flag_run"
	return true
func exit_route(id: int,start: Vector3,home: Vector3,lane: int,avoid: Array) -> PackedVector3Array:
	var game=ai.game;var team: int=game.players[id].team;var routes=ai.tribes.routes
	if not ai.tribes.carrier(id) or start.distance_to(game.match_mode.bases[1-team])>32 or home.distance_to(game.match_mode.bases[team])>110:return PackedVector3Array()
	# Low reserves cannot reliably steer a new airborne exit. Keep the
	# ordinary terrain/portal route and its landing recovery in that case.
	if game.fighters[id].tribes_state.energy<game.match_mode.tribes.definition(id).energy*.25:return PackedVector3Array()
	# Leave the exposed flag deck through a clear descending corridor. Do not
	# brake to touch nearby terrain graph nodes or route back via the bunker.
	var forward:=home-start;forward.y=0;forward=forward.normalized()
	var velocity: Vector3=game.fighters[id].velocity;velocity.y=0
	var best:=PackedVector3Array();var cost:=INF
	var observed: Array=ai.teamplay.intel(id).map(func(row):return row.position)
	for enemy in ai.brains.get(id,{}).get("visible",[]):
		if ai.alive(enemy):observed.append(game.fighters[enemy].position)
	var exposed_missiles: Array=[];var pads=game.match_mode.tribes.stations()
	if pads:
		for key in pads.defences.rows.size():
			var fixture: Dictionary=pads.defences.rows[key]
			if fixture.team==team or fixture.kind!="missile" or not pads.defences.active(key):continue
			var eye: Vector3=pads.defences.eye(key)
			if game._trace(ai.eye(id),eye,id).get("fixed_turret",-1)==key:exposed_missiles.append(eye)
	for radius in [24,36,48]:
		for angle in [0.0,-.4,.4,-.8,.8,-1.2,1.2,-1.8,1.8,-2.4,2.4,PI]:
			var direction:=forward.rotated(Vector3.UP,angle);var probe: Vector3=start+direction*radius
			var hit: Dictionary=ai.navigation.ray(probe+Vector3.UP*6,probe-Vector3.UP*42)
			if hit.is_empty() or hit.normal.y<.6 or hit.position.y>start.y-3:continue
			var point: Vector3=hit.position+Vector3.UP*.06
			if not routes.clear(start,point):continue
			# The high rectangular graph corridor alone can clear a bunker
			# whose wall intersects the actual descending escape. Require a
			# clear descent and avoid landing on a roof mistaken for a valley.
			var below: Dictionary=ai.navigation.ray(point-Vector3.UP*.5,point-Vector3.UP*24)
			if not below.is_empty() and below.normal.y>.5 and point.y-below.position.y>3:continue
			var side:=direction.cross(Vector3.UP)*.48;var blocked:=false
			# Cross the stand before descending. A single diagonal ray from
			# its centre hit the stand's own floor and rejected every Stonehenge
			# exit, even though stepping off its edge is physically possible.
			var departure: Vector3=start+direction*minf(radius*.25,10)
			for shift in [Vector3.ZERO,side,-side]:
				if not ai.navigation.ray(start+Vector3.UP*.8+shift,departure+Vector3.UP*.8+shift).is_empty() or not ai.navigation.ray(departure+Vector3.UP*.8+shift,point+Vector3.UP*.8+shift).is_empty():blocked=true;break
			if blocked:continue
			var path: PackedVector3Array=routes.path(point,home,lane,avoid)
			if path.is_empty():continue
			var value: float=routes.route_length(path)+start.distance_to(point)
			# An observed missile battery can punish even a fast grab. Prefer
			# a descending lane behind terrain instead of repeatedly jetting
			# through its firing corridor. This is observation-based routing;
			# hidden fixtures and the turret's private target are not consulted.
			for eye in exposed_missiles:
				var previous: Vector3=start
				for waypoint in path:
					if start.distance_to(waypoint)>110:break
					if eye.distance_to(waypoint)<150 and ai.navigation.ray(eye,waypoint+Vector3.UP).is_empty():value+=previous.distance_to(waypoint)*2.5
					previous=waypoint
			# A shortest-distance reversal wastes the speed used to grab the
			# flag. Prefer a downhill exit that preserves incoming momentum.
			if velocity.length()>6:value+=(1-velocity.normalized().dot(direction))*velocity.length()*5
			# Include the carrier's own observations, not only teammates' radio
			# reports. Score exposure along the early route rather than just its
			# first waypoint, so cover behind a bunker can justify a longer exit.
			for threat in observed:
				var previous: Vector3=start
				for waypoint in path:
					if start.distance_to(waypoint)>110:break
					if threat.distance_to(waypoint)<140 and ai.navigation.ray(threat+Vector3.UP,waypoint+Vector3.UP).is_empty():value+=previous.distance_to(waypoint)*3
					previous=waypoint
			if value<cost:cost=value;best=path;best.insert(0,start)
	if not best.is_empty():count("flag_exit_routes")
	return best
func prepare(id: int,brain: Dictionary) -> bool:
	var game=ai.game;var s: Dictionary=game.players[id];var pads=game.match_mode.tribes.stations()
	if not brain.has("st_outfit_until"):brain.st_outfit_until=game.clock+12
	return s.tribes_pack=="none" and game.clock<brain.st_outfit_until and pads and pads.rows.any(func(row):return row.kind=="inventory" and row.team==s.team and pads.assets.active(row.asset) and game.fighters[id].position.distance_to(row.position)<40)
func pass_flag(id: int,brain: Dictionary) -> bool:
	var game=ai.game;var s: Dictionary=game.players[id];var actor=game.fighters[id]
	if not ai.tribes.carrier(id) or s.hp>40 or s.tribes_kit or game.clock<float(brain.get("pass_at",0)):return false
	brain.pass_at=game.clock+2
	var home: Vector3=game.match_mode.bases[s.team];var origin: Vector3=actor.position+Vector3.UP*.8
	for friend in game.players:
		if friend==id or not ai.alive(friend) or game.players[friend].team!=s.team or game.players[friend].hp<s.hp+30:continue
		var other=game.fighters[friend];var distance: float=other.position.distance_to(actor.position)
		if distance<3 or distance>18 or other.position.distance_to(home)>actor.position.distance_to(home)-4:continue
		var flight:=clampf(distance/16,.3,1.2);var target: Vector3=other.position+other.velocity*flight+Vector3.UP*.6
		var impulse: Vector3=(target-origin)/flight+Vector3.UP*10*flight-actor.velocity
		if impulse.length()>20:continue
		var unsafe: bool=ai.teamplay.intel(id).any(func(row):return row.position.distance_to(target)<16)
		if unsafe or not Ballistics.clear(game.get_world_3d().direct_space_state,origin,{"velocity":actor.velocity+impulse,"time":flight},20):continue
		if game.match_mode.st.drop(id,origin,impulse):
			passes[friend]={"until":game.clock+2,"arrival":game.clock+flight,"point":target-Vector3.UP*.6,"team":s.team,"epoch":game.map_epoch}
			if ai.brains.has(friend):ai.brains[friend].plan_at=0
			brain.plan_at=0;count("flag_passes");return true
	return false
func catch_goal(id: int,rows: Array) -> bool:
	if not passes.has(id):return false
	var game=ai.game;var row: Dictionary=passes[id];var s: Dictionary=game.players[id]
	if game.clock>=row.until or row.team!=s.team or row.epoch!=game.map_epoch or not game.match_mode.flags[1-s.team].dropped:passes.erase(id);return false
	ai.candidate(rows,"st:catch","objective",row.point if game.clock<row.arrival else game.match_mode.flags[1-s.team].position,680);return true
func catch_steer(id: int,brain: Dictionary) -> bool:
	if not passes.has(id) or brain.goal_key!="st:catch":return false
	var game=ai.game;var row: Dictionary=passes[id]
	if game.clock>row.arrival+.15 or not game.match_mode.flags[1-row.team].dropped:return false
	var actor=game.fighters[id];var s: Dictionary=game.players[id]
	# Meet the planned throw in time. Chasing its current position turns the
	# receiver back toward the passer; ordinary final-waypoint braking also
	# stops a moving receiver short of the point used to lead the throw.
	var offset: Vector3=row.point-actor.position;offset.y=0
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
	var wanted:=offset/maxf(.08,row.arrival-game.clock)
	var profile: Dictionary=game.match_mode.tribes.definition(id)
	var desired: Vector3=wanted/profile.walk
	s.jump=false;s.jet_held=false;s.ski=false
	if not actor.is_supported():
		desired=((wanted-velocity)*.12).limit_length(.65)
		s.ski=true;s.jet_held=(wanted-velocity).length()>2 and actor.tribes_state.energy>3 and ai.navigation.ray(ai.eye(id),ai.eye(id)+Vector3.UP).is_empty()
	elif velocity.length()>profile.walk*1.05 and velocity.normalized().dot(wanted.normalized())>.9:s.ski=true
	s.move=ai.tribes.movement(id,desired);s.prone=false;s.crouch=false;s.swim=Vector3.ZERO
	brain.travel_phase="flag_catch";return true
func bombard(id: int,brain: Dictionary,delta: float) -> bool:
	var game=ai.game;var s: Dictionary=game.players[id];var rules=game.match_mode.tribes
	if s.tribes_class!="heavy" or 7 not in s.owned or rules.amount(id,7)==0 or brain.role not in ["siege","escort"]:return false
	if ai.alive(brain.enemy) and ai.eye(id).distance_to(ai.target_position(brain.enemy))<40:return false
	if game.clock>=float(brain.get("bombard_at",0)):
		brain.bombard_at=game.clock+.5;brain.erase("bombard_solution")
		var contacts: Array=rules.targeting.targets(s.team).map(func(row):return {"position":row.position,"fixture":true,"designated":true})+ai.teamplay.intel(id).duplicate()
		if brain.goal_kind in ["st_fixed_attack","st_base_attack"]:
			var pads=rules.stations();var key: int=brain.support
			if brain.goal_kind=="st_fixed_attack" and key>=0 and key<pads.defences.rows.size() and pads.defences.rows[key].hp>0:contacts.push_front({"position":pads.defences.eye(key),"fixture":true})
			if brain.goal_kind=="st_base_attack" and key>=0 and key<pads.assets.rows.size() and pads.assets.rows[key].hp>0:contacts.push_front({"position":pads.assets.rows[key].point,"fixture":true})
		if brain.goal_kind=="st_bombard":
			# A push-support job has no single fixture in brain.support. Acquire
			# exposed defences here too; otherwise a Heavy can reach its firing
			# hill and wait for a laser that escorts only provide after a grab.
			for target in ai.tribes.equipment.targets(id,false):
				if ai.eye(id).distance_to(target.point)>230:continue
				if game._trace(ai.eye(id),target.point,id).get(target.tag,-1)==target.key:contacts.push_front({"position":target.point,"fixture":true})
		for contact in contacts:
			var target: Vector3=contact.position
			if not contact.get("fixture",false) and target.distance_to(game.match_mode.bases[1-s.team])>65:continue
			var distance: float=ai.eye(id).distance_to(target)
			if distance<50 or distance>230:continue
			var d: Dictionary=rules.Arsenal.table()[7]
			var solution: Dictionary=rules.targeting.solution(id,target,7) if contact.get("designated",false) else Ballistics.solve(ai.eye(id),target+Vector3.UP*.6,d.speed,20,game.fighters[id].velocity*.5)
			if not solution.is_empty() and Ballistics.clear(game.get_world_3d().direct_space_state,ai.eye(id),solution,20,.4):brain.bombard_solution={"target":target,"solution":solution};break
	if not brain.has("bombard_solution"):return false
	var row: Dictionary=brain.bombard_solution
	s.weapon=7
	if not ai.safe_shot(id,row.target,true):return false
	brain.equipment_aim_until=game.clock+.2
	ai.aim(id,ai.eye(id)+row.solution.direction*100,1-exp(-10*delta))
	# The generic 0.12-radian close-combat tolerance can launch a mortar tens
	# of metres short. Let the normal aim converge before releasing the shell.
	s.fire=(-game._weapon_transform(id).basis.z).dot(row.solution.direction)>cos(.012)
	if s.fire and s.cooldown<=0:count("bombard_shots")
	return true
func disc_jump(id: int,brain: Dictionary) -> bool:
	var game=ai.game;var s: Dictionary=game.players[id];var actor=game.fighters[id]
	var carrying: bool=ai.tribes.carrier(id)
	if brain.role!="capper" or s.hp<(90 if carrying else 95) or not carrying and not s.tribes_kit or s.cooldown>0 or game.clock<float(brain.get("disc_jump_at",0)):return false
	if not actor.is_supported() or 3 not in s.owned or game.match_mode.tribes.amount(id,3)<3 or actor.tribes_state.energy<(10 if carrying else 25):return false
	var forward: Vector3=brain.goal-actor.position;forward.y=0;forward=forward.normalized()
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
	if actor.position.distance_to(brain.goal)<100 or velocity.dot(forward)<9 or velocity.slide(forward).length()>4:return false
	var ahead: Dictionary=ai.navigation.ray(actor.position+forward*18+Vector3.UP*20,actor.position+forward*18-Vector3.UP*10)
	if ahead.is_empty() or not carrying and ahead.position.y<actor.position.y+3 or not ai.tribes.routes.clear(actor.position,ahead.position):return false
	var floor_hit: Dictionary=ai.navigation.ray(actor.position-forward*3+Vector3.UP,actor.position-forward*3-Vector3.UP*3)
	if floor_hit.is_empty() or not ai.navigation.ray(ai.eye(id),ai.eye(id)+Vector3.UP*8).is_empty():return false
	for friend in game.players:
		if friend!=id and ai.alive(friend) and game.players[friend].team==s.team and game.fighters[friend].position.distance_to(floor_hit.position)<9:return false
	brain.disc_jump_at=game.clock+14;brain.disc_launch_until=game.clock+.15;brain.disc_direction=forward
	if carrying:count("carrier_disc_jump_attempts")
	s.weapon=3;ai.aim(id,floor_hit.position,1);s.fire=true;count("disc_jump_attempts");return true

func bombard_goal(id: int,brain: Dictionary,rows: Array) -> bool:
	var game=ai.game;var s: Dictionary=game.players[id]
	if s.tribes_class!="heavy" or 7 not in s.owned or game.match_mode.tribes.amount(id,7)==0:return false
	var flag: Vector3=game.match_mode.bases[1-s.team]
	var push: bool=ai.brains.keys().any(func(friend):return friend!=id and ai.alive(friend) and game.players[friend].team==s.team and ai.tribes.assignments.get(friend,"")=="capper" and game.fighters[friend].position.distance_to(flag)<150)
	if not push:return false
	if game.clock>=float(brain.get("bombard_site_at",0)):
		brain.bombard_site_at=game.clock+5;brain.erase("bombard_site")
		ai.tribes.routes.build();var best:=INF
		for point in ai.tribes.routes.points:
			var distance: float=point.distance_to(flag)
			if distance<95 or distance>175 or not ai.navigation.ray(point+Vector3.UP*1.6,flag+Vector3.UP).is_empty():continue
			var cost: float=game.fighters[id].position.distance_to(point)+absf(distance-130)
			if cost<best:best=cost;brain.bombard_site=point
	if not brain.has("bombard_site"):return false
	ai.candidate(rows,"st:bombard","st_bombard",brain.bombard_site,350,true);return true

func designate(id: int,brain: Dictionary,delta: float) -> bool:
	var game=ai.game;var s: Dictionary=game.players[id];var rules=game.match_mode.tribes
	if ai.tribes.carrier(id) or brain.role not in ["escort","chaser"] or ai.alive(brain.enemy) and ai.eye(id).distance_to(ai.target_position(brain.enemy))<45:return false
	if game.clock>=float(brain.get("designate_at",0)):
		brain.designate_at=game.clock+6;brain.erase("designation")
		if not game.players.keys().any(func(friend):return friend!=id and ai.alive(friend) and game.players[friend].team==s.team and 7 in game.players[friend].owned and rules.amount(friend,7)>0 and game.fighters[friend].position.distance_to(game.fighters[id].position)<180):return false
		for target in ai.tribes.equipment.targets(id,true):
			if ai.eye(id).distance_to(target.point)>200 or game._trace(ai.eye(id),target.point,id).get(target.tag,-1)!=target.key:continue
			brain.designation=target.point;brain.designate_until=game.clock+.8;break
	if not brain.has("designation") or game.clock>=float(brain.get("designate_until",0)):return false
	s.weapon=11;brain.equipment_aim_until=game.clock+.2
	s.fire=ai.aim(id,brain.designation,1-exp(-12*delta));return true
func beacon(id: int,brain: Dictionary):
	var game=ai.game;var s: Dictionary=game.players[id];var rules=game.match_mode.tribes
	if s.get("tribes_beacons",0)<=0 or ai.tribes.carrier(id) or brain.role not in ["capper","escort"] or game.clock<float(brain.get("beacon_at",0)) or ai.alive(brain.enemy):return
	brain.beacon_at=game.clock+8
	var actor=game.fighters[id]
	if actor.position.distance_to(game.match_mode.bases[1-s.team])>45 or not actor.is_supported():return
	if rules.targeting.beacons.values().any(func(row):return row.team==s.team and row.position.distance_to(actor.position)<30):return
	if rules.targeting.place(id,actor.position+Vector3.UP*.7-Basis(Vector3.UP,s.yaw).z*1.1,Vector3.DOWN):count("target_beacons")
