extends RefCounted
## Observe physical equipment through LOS; never acquire players through a sensor.
var ai
var deferred: Dictionary={}
var epoch:=-1
func clean():
	if epoch!=ai.game.map_epoch:deferred.clear();epoch=ai.game.map_epoch
	for key in deferred.keys():
		if deferred[key]<=ai.game.clock:deferred.erase(key)
func defer_fixed(team: int,key: int):
	clean();deferred[Vector2i(team,key)]=ai.game.clock+120
func fixed_due(team: int,key: int) -> bool:
	clean();return not deferred.has(Vector2i(team,key))
func essential_damage(team: int) -> bool:
	var pads=ai.game.match_mode.tribes.stations()
	return pads and (pads.generators.any(func(row):return row.team==team and pads.source_hp(row)<row.maximum) or pads.assets.rows.any(func(row):return row.team==team and row.hp<pads.assets.maximum(row)))
func damaged(team: int) -> bool:
	var pads=ai.game.match_mode.tribes.stations()
	if essential_damage(team):return true
	if pads:
		for key in pads.defences.rows.size():
			var row: Dictionary=pads.defences.rows[key]
			if row.team==team and row.hp<pads.defences.Data.hp(row.kind) and fixed_due(team,key):return true
	var deploy=ai.game.match_mode.tribes.deployables
	return deploy.rows.values().any(func(row):return row.team==team and row.hp<deploy.Data.hp(row.kind))
func service(team: int) -> bool:
	var pads=ai.game.match_mode.tribes.stations()
	return pads and pads.rows.any(func(row):return row.kind=="inventory" and row.team==team and pads.assets.active(row.asset))
func repair_goal(id: int,rows: Array) -> bool:
	var game=ai.game;var s: Dictionary=game.players[id];var pads=game.match_mode.tribes.stations()
	if not pads or pads.generators.any(func(row):return row.team==s.team and pads.source_hp(row)<row.maximum):return false
	var best: Dictionary={};var cost:=INF
	for key in pads.assets.rows.size():
		var row: Dictionary=pads.assets.rows[key]
		if row.team!=s.team or row.hp>=pads.assets.maximum(row):continue
		var distance: float=game.fighters[id].position.distance_to(row.approach)+(50 if row.kind=="pulse" else 0)
		if distance<cost:cost=distance;best={"key":key,"point":row.approach,"kind":"st_asset_repair"}
	for key in pads.defences.rows.size():
		var row: Dictionary=pads.defences.rows[key]
		if row.team!=s.team or row.hp>=pads.defences.Data.hp(row.kind) or not fixed_due(s.team,key):continue
		var point: Vector3=row.position+Vector3(3.6,.06,0)
		var distance: float=game.fighters[id].position.distance_to(point)+35
		if distance<cost:cost=distance;best={"key":key,"point":point,"kind":"st_fixed_repair"}
	var deploy=game.match_mode.tribes.deployables
	for key in deploy.rows:
		var row: Dictionary=deploy.rows[key]
		if row.team!=s.team or row.hp>=deploy.Data.hp(row.kind):continue
		var distance: float=game.fighters[id].position.distance_to(row.position)+25
		if distance>=cost:continue
		var away: Vector3=(game.fighters[id].position-row.position);away.y=0
		if away.length()<.1:away=Vector3.FORWARD
		var point: Vector3=row.position+away.normalized()*2.5
		var hit: Dictionary=ai.navigation.ray(point+Vector3.UP*3,point-Vector3.UP*4)
		if hit.is_empty():continue
		cost=distance;best={"key":key,"point":hit.position+Vector3.UP*.06,"kind":"st_deploy_repair"}
	if best.is_empty():return false
	ai.candidate(rows,"%s:%d"%[best.kind,best.key],best.kind,best.point,490,true,best.key)
	return true
func combat(id: int,brain: Dictionary,delta: float) -> bool:
	var game=ai.game;var rules=game.match_mode.tribes;var deploy=rules.deployables;var s: Dictionary=game.players[id]
	var repairing: bool=brain.goal_kind in ["st_asset_repair","st_deploy_repair","st_fixed_repair"]
	var point:=Vector3.ZERO;var tag:="deployable";var key:=-1
	if repairing:
		if ai.alive(brain.enemy) and ai.eye(id).distance_to(ai.target_position(brain.enemy))<8:return false
		key=int(brain.support)
		if s.tribes_pack!="repair":return false
		if brain.goal_kind=="st_fixed_repair":
			var pads=rules.stations()
			if not pads or key<0 or key>=pads.defences.rows.size() or pads.defences.rows[key].team!=s.team:return false
			point=pads.defences.eye(key);tag="fixed_turret"
		elif brain.goal_kind=="st_asset_repair":
			var pads=rules.stations()
			if not pads or key<0 or key>=pads.assets.rows.size() or pads.assets.rows[key].team!=s.team:return false
			point=pads.assets.rows[key].point;tag="base_asset"
		else:
			if not deploy.rows.has(key) or deploy.rows[key].team!=s.team:return false
			point=deploy.Data.frame(deploy.rows[key])*Vector3(0,deploy.Data.KINDS[deploy.rows[key].kind].size.y*.5,0)
		if ai.eye(id).distance_to(point)>4.8:return false
		s.weapon=8
	else:
		if ai.alive(brain.enemy) and ai.eye(id).distance_to(ai.target_position(brain.enemy))<18:return false
		# Bounded 5 Hz observation. Only an exposed fixture can be targeted;
		# cappers clear turrets on their route without abandoning the flag job.
		if game.clock>=float(brain.get("equipment_scan_at",0)):
			brain.equipment_scan_at=game.clock+.2;brain.equipment_target=-1
			var nearest:=100.0
			for candidate in targets(id,brain.role=="siege"):
				var offset: Vector3=candidate.point-ai.eye(id);var distance:=offset.length()
				var horizontal:=Vector3(offset.x,0,offset.z)
				if distance>=nearest or distance>12 and horizontal.length()>.1 and (-Basis(Vector3.UP,s.yaw).z).dot(horizontal.normalized())<cos(deg_to_rad(55)):continue
				if game._trace(ai.eye(id),candidate.point,id).get(candidate.tag,-1)!=candidate.key:continue
				nearest=distance;brain.equipment_target=candidate.key;brain.equipment_tag=candidate.tag
		key=int(brain.get("equipment_target",-1));tag=brain.get("equipment_tag","deployable")
		var candidates: Array=targets(id,true).filter(func(row):return row.tag==tag and row.key==key)
		if candidates.is_empty():return false
		point=candidates[0].point
		var distance: float=ai.eye(id).distance_to(point)
		if distance>100:return false
		var selected:=-1;var previous: int=s.weapon
		for weapon in ([1,3,2,0] if distance<35 else [3,2,0,1]):
			if not rules.usable(id,weapon):continue
			s.weapon=weapon
			if not ai.safe_shot(id,point,weapon in [1,3]):continue
			selected=weapon;break
		if selected<0:s.weapon=previous;return false
		s.weapon=selected
	if game._trace(ai.eye(id),point+(point-ai.eye(id)).normalized()*.08,id).get(tag,-1)!=key:return false
	var data: Dictionary=rules.Arsenal.table()[s.weapon]
	var aim: Vector3=point
	if data.speed>0:aim-=game.fighters[id].velocity*float(data.inherit)*ai.eye(id).distance_to(point)/data.speed
	brain.equipment_aim_until=game.clock+.2
	s.fire=ai.aim(id,aim,1-exp(-10*delta)) and ai.safe_shot(id,point,data.splash>0)
	return true

func targets(id: int,all_equipment: bool) -> Array:
	var game=ai.game;var rules=game.match_mode.tribes;var pads=rules.stations();var team: int=game.players[id].team;var result: Array=[]
	for key in rules.deployables.rows:
		var row: Dictionary=rules.deployables.rows[key]
		if row.team!=team and (row.kind=="turret" or all_equipment):result.append({"key":key,"tag":"deployable","point":rules.deployables.Data.frame(row)*Vector3(0,rules.deployables.Data.KINDS[row.kind].size.y*.5,0)})
	if pads:
		for key in pads.defences.rows.size():
			var row: Dictionary=pads.defences.rows[key]
			if row.team!=team and row.hp>0:result.append({"key":key,"tag":"fixed_turret","point":pads.defences.eye(key)})
		if all_equipment:
			for key in pads.assets.rows.size():
				var row: Dictionary=pads.assets.rows[key]
				if row.team!=team and row.hp>0:result.append({"key":key,"tag":"base_asset","point":row.point})
	return result
func siege_goal(id: int,brain: Dictionary,rows: Array) -> bool:
	var game=ai.game;var pads=game.match_mode.tribes.stations()
	if not pads:return false
	if game.clock>=float(brain.get("siege_site_at",0)):
		brain.siege_site_at=game.clock+5;brain.erase("siege_site")
		var options: Array=targets(id,true).filter(func(row):return row.tag!="deployable")
		options.sort_custom(func(a,b):return a.tag=="fixed_turret" and b.tag!="fixed_turret")
		ai.tribes.routes.build()
		for target in options:
			var heavy: bool=game.players[id].tribes_class=="heavy" and 7 in game.players[id].owned
			var best:=Vector3.INF;var cost:=INF
			for point in ai.tribes.routes.points:
				var distance: float=point.distance_to(target.point)
				if distance<(100 if heavy else 20) or distance>(180 if heavy else 65):continue
				if not ai.navigation.ray(point+Vector3.UP*1.6,target.point).is_empty():continue
				var value: float=game.fighters[id].position.distance_to(point)+absf(distance-(130 if heavy else 45))
				if value<cost:cost=value;best=point
			if best.is_finite():brain.siege_site={"point":best,"tag":target.tag,"key":target.key};break
	if not brain.has("siege_site"):return false
	var site: Dictionary=brain.siege_site
	if not targets(id,true).any(func(row):return row.tag==site.tag and row.key==site.key):brain.siege_site_at=0;return false
	var kind: String="st_fixed_attack" if site.tag=="fixed_turret" else "st_base_attack"
	ai.candidate(rows,kind+":%d"%site.key,kind,site.point,340,true,site.key);return true

func recovery_goal(id: int,goals: Array):
	var game=ai.game;var rules=game.match_mode.tribes;var s: Dictionary=game.players[id]
	if s.hp>rules.definition(id).hp*.65 and s.tribes_pack!="none" and not ai.brains.get(id,{}).get("refilling",false):return
	var best:=-1;var distance:=22.0
	for key in rules.recovery.rows:
		var row: Dictionary=rules.recovery.rows[key];var cost: float=game.fighters[id].position.distance_to(row.position)
		if cost>=distance or not rules.recovery.useful(id,row.payload) or not rules.deployables.ray(ai.eye(id),row.position).is_empty():continue
		distance=cost;best=key
	if best>=0:ai.candidate(goals,"st:recovery:%d"%best,"supply",rules.recovery.rows[best].position,420,true)
