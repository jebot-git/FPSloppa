extends RefCounted
## One bounded specialist plan per team; purchases and placement use player rules.
var ai
var plans: Dictionary={}
var retry: Dictionary={}
var epoch:=-1
const ORDER=["turret","motion","ammo_station","pulse","remote_jammer","camera","inventory","turret"]
func plan(id: int) -> Dictionary:
	var game=ai.game;var rules=game.match_mode.tribes;var s: Dictionary=game.players[id];var deploy=rules.deployables
	if epoch!=game.map_epoch:plans.clear();retry.clear();epoch=game.map_epoch
	for peer in plans.keys():
		if not ai.alive(peer) or game.players[peer].team!=plans[peer].team or game.clock>plans[peer].until:plans.erase(peer)
	if plans.has(id):return plans[id]
	if plans.values().any(func(row):return row.team==s.team) or game.clock<float(retry.get(id,0)):return {}
	retry[id]=game.clock+5
	var kind: String=s.tribes_pack if deploy.Data.is_pack(s.tribes_pack) else ""
	if kind.is_empty():
		var quotas: Dictionary={}
		for key in ORDER:
			quotas[key]=int(quotas.get(key,0))+1
			if deploy.count(s.team,key)>=quotas[key]:continue
			if rules.balance(id)<maxi(1000,rules.refit_cost(id,"medium",[3,2,4,1],key)+700):continue
			kind=key;break
	if kind.is_empty():return {}
	var site:=choose_site(id,kind)
	if site.is_empty():return {}
	site.merge({"kind":kind,"team":s.team,"until":game.clock+150,"attempts":0});plans[id]=site
	return site
func choose_site(id: int,kind: String) -> Dictionary:
	var game=ai.game;var team: int=game.players[id].team;var deploy=game.match_mode.tribes.deployables;var routes=ai.tribes.routes
	var home: Vector3=game.match_mode.bases[team];var enemy: Vector3=game.match_mode.bases[1-team]
	var direction:=enemy-home;direction.y=0;direction=direction.normalized();var side:=direction.cross(Vector3.UP)
	var forward: bool=kind in ["ammo_station","inventory","remote_jammer"]
	var anchor: Vector3=home.lerp(enemy,.57)+side*(45 if team==0 else -45) if forward else home+direction*30
	if kind=="turret":anchor=home+side*(6 if deploy.count(team,kind)==0 else -6)
	if kind=="camera":anchor=home+direction*55+side*30
	var yaw:=atan2(-direction.x,-direction.z)
	for radius in ([0,3,7] if kind=="turret" else [0,8,16,24]):
		for i in (1 if radius==0 else 8):
			var probe: Vector3=anchor+Vector3(cos(i*TAU/8),0,sin(i*TAU/8))*radius
			# Flag defence belongs on the accessible deck, not the roof above
			# it. A ray from 35 m overhead selected Stonehenge's upper canopy.
			var hit: Dictionary=ai.navigation.ray(probe+Vector3.UP*(1.8 if kind=="turret" else 35),probe-Vector3.UP*70)
			if hit.is_empty() or hit.normal.y<.85:continue
			var point: Vector3=hit.position+hit.normal*.03
			if not game.match_mode.tribes.stations().playable_bounds.has_point(point):continue
			if deploy.rows.values().any(func(row):return row.position.distance_to(point)<(8 if kind=="turret" else 4)):continue
			var shape:=BoxShape3D.new();shape.size=deploy.Data.KINDS[kind].size
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
			query.transform=deploy.Data.frame({"position":point,"normal":hit.normal,"yaw":yaw})*Transform3D(Basis.IDENTITY,Vector3.UP*(shape.size.y*.5+.025))
			if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
			var stand: Vector3=point-direction*1.8
			var floor_hit: Dictionary=ai.navigation.ray(stand+Vector3.UP*1,stand-Vector3.UP*2)
			if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
			stand=floor_hit.position+Vector3.UP*.06
			if not ai.navigation.ray(stand+Vector3.UP*1.6,point+Vector3.UP*.08).is_empty():continue
			if routes.path(game.fighters[id].position,stand).is_empty():continue
			return {"point":point,"stand":stand,"yaw":yaw}
	return {}
func goal(id: int,rows: Array,plan_row: Dictionary):
	if plan_row.is_empty():return
	ai.candidate(rows,"st:build:"+plan_row.kind,"st_build",plan_row.stand,530,true)
func build(id: int,brain: Dictionary) -> bool:
	if brain.goal_kind!="st_build" or not plans.has(id):return false
	var game=ai.game;var row: Dictionary=plans[id]
	if game.fighters[id].position.distance_to(row.stand)>.8:return true
	if game.clock<float(row.get("try_at",0)):return true
	row.try_at=game.clock+1;row.attempts+=1;game.players[id].yaw=row.yaw
	if ai.action("st_deploy",[id,ai.eye(id),(row.point-ai.eye(id)).normalized()]):
		ai.tribes.offense.count("built_"+row.kind);plans.erase(id);retry[id]=game.clock+5;brain.plan_at=0
	elif row.attempts>=4:plans.erase(id);retry[id]=game.clock+12;brain.plan_at=0
	return true
func remote_supply(id: int,rows: Array,health_needed: bool):
	if health_needed:return # Remote stations do not repair armour.
	var game=ai.game;var deploy=game.match_mode.tribes.deployables
	for key in deploy.rows:
		var row: Dictionary=deploy.rows[key]
		if row.team!=game.players[id].team or row.kind not in ["inventory","ammo_station"] or row.energy<10 or game.clock<row.ready:continue
		var point: Vector3=deploy.Data.frame(row)*Vector3(0,0,-1.25)
		ai.candidate(rows,"st:remote-supply:%d"%key,"supply",point,420,true)
