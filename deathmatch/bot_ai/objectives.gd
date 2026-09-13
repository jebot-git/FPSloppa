extends RefCounted
## Roles use public objectives and friendly positions, never hidden opponents.
## Separate scoring, screening and recovery jobs instead of sharing one waypoint.
var ai
var leases: Dictionary={}
var positions: Dictionary={}
var pushes: Dictionary={}

func push_goal(id:int,slot:int,rows:Array)->bool:
	# Rendezvous on a real route using friendly positions only. The first
	# arrival waits at most three seconds, so a missing partner cannot deadlock.
	var game=ai.game;var mode=game.match_mode;var team:int=game.players[id].team
	if not pushes.has(team):
		var route:PackedVector3Array=ai.navigation.path(mode.bases[team],mode.bases[1-team])
		if route.size()<2:return false
		var length:=0.0
		for i in range(1,route.size()):length+=route[i-1].distance_to(route[i])
		var remaining:=length*.4;var anchor:Vector3=route[0]
		for i in range(1,route.size()):
			var segment:float=route[i-1].distance_to(route[i])
			if remaining<=segment:
				anchor=route[i-1].lerp(route[i],remaining/maxf(.001,segment));break
			remaining-=segment
		pushes[team]={"anchor":anchor,"arrival":-1.0,"released_until":0.0}
	var push:Dictionary=pushes[team];var origin:Vector3=game.fighters[id].position
	var enemy_base:Vector3=mode.bases[1-team]
	if game.clock<push.released_until or origin.distance_to(enemy_base)<push.anchor.distance_to(enemy_base)-4:return false
	var ready:=0
	for friend in members(id):
		if ai.team_rank(friend)==0:continue
		if game.fighters[friend].position.distance_to(push.anchor)<7:ready+=1
	if origin.distance_to(push.anchor)<5 and push.arrival<0:push.arrival=game.clock
	if ready>=2 or push.arrival>=0 and game.clock-push.arrival>=3:
		push.released_until=game.clock+18;push.arrival=-1.0;ai.teamplay.count("ctf_pushes");return false
	ai.candidate(rows,"push:%s"%slot,"objective",station(id,push.anchor,1.2,slot),140,true)
	return true

func carrier_screen(id:int,carrier:int)->Vector3:
	var game=ai.game;var team:int=game.players[id].team
	var anchor:Vector3=game.fighters[carrier].position
	var route:PackedVector3Array=ai.navigation.path(anchor,game.match_mode.bases[team])
	var remaining:=7.0;var point:Vector3=anchor
	for i in range(1,route.size()):
		var segment:float=route[i-1].distance_to(route[i])
		if remaining<=segment:return route[i-1].lerp(route[i],remaining/maxf(.001,segment))
		remaining-=segment;point=route[i]
	return point

func members(id: int,active_only: bool=true) -> Array:
	var result: Array=[]
	for other in ai.game.players:
		if not ai.controlled(other) or not ai.game.match_mode.same_team(id,other) or ai.game.players[other].spectator:continue
		if active_only and (not ai.alive(other) or ai.game.match_mode.special.blocked(other)):continue
		result.append(other)
	result.sort()
	return result

func nearest(id: int,point: Vector3,key: String,exclude: int=0) -> int:
	for expired in leases.keys():
		if leases[expired].until<=ai.game.clock:leases.erase(expired)
	var team: int=ai.game.players[id].team
	var token:=str(team)+":"+key
	var group:=members(id);group.erase(exclude)
	var old: Dictionary=leases.get(token,{})
	if not old.is_empty() and old.owner in group and old.until>ai.game.clock:return old.owner
	var best:=0;var cost:=INF
	for friend in group:
		var distance: float=ai.game.fighters[friend].position.distance_to(point)
		if distance<cost:cost=distance;best=friend
	leases[token]={"owner":best,"until":ai.game.clock+4.0}
	return best

func station(id: int,anchor: Vector3,radius: float,slot: int) -> Vector3:
	var key: String="%s:%s:%s"%[anchor,radius,slot]
	if positions.has(key):return positions[key]
	# Prefer a designated sector, not the nearest point on a shared ring.
	# Validate actual floor and sightline so a slot cannot sit inside a wall.
	var preferred: float=TAU*posmod(slot*3,8)/8.0
	for offset in [0,1,-1,2,-2,3,-3,4]:
		var angle: float=preferred+float(offset)*TAU/8
		var point: Vector3=anchor+Vector3(cos(angle),0,sin(angle))*radius
		point=ai.navigation.project_local(point)
		if Vector2(point.x-anchor.x,point.z-anchor.z).length()>radius+1 or absf(point.y-anchor.y)>1.4:continue
		var floor_hit: Dictionary=ai.navigation.ray(point+Vector3.UP*.5,point-Vector3.UP*1.2)
		if floor_hit.is_empty() or floor_hit.normal.y<.7 or ai.navigation.hazardous(point):continue
		if not ai.navigation.ray(point+Vector3.UP,anchor+Vector3.UP).is_empty():continue
		if positions.size()>=128:positions.erase(positions.keys()[0])
		positions[key]=point;return point
	return anchor

func thaw_goals(id: int,rows: Array) -> void:
	var mode=ai.game.match_mode
	for friend in mode.special.frozen:
		if not mode.same_team(id,friend) or not ai.game.fighters.has(friend):continue
		var point: Vector3=ai.game.fighters[friend].position
		var rescuer:=nearest(id,point,"thaw:%s"%friend)
		if rescuer==id:ai.candidate(rows,"thaw:%s"%friend,"thaw",point,135,true,friend)
		elif nearest(id,point,"thaw-cover:%s"%friend,rescuer)==id:
			ai.candidate(rows,"thaw-cover:%s"%friend,"guard",station(id,point,4,ai.team_rank(id)),85,true,friend);rows[-1].look=point

func goals(id: int,brain: Dictionary,rows: Array) -> bool:
	var game=ai.game;var mode=game.match_mode;var s: Dictionary=game.players[id]
	if s.team not in [0,1]:return false
	var roster:=members(id,false);var slot:=maxi(0,roster.find(id))
	if mode.kind=="koth":
		var holder:=nearest(id,mode.hill,"hill")
		var secured: bool=mode.hill_owner==s.team and ai.alive(holder) and mode.nearby(holder,mode.hill,2.5)
		brain.role="hold" if holder==id else "screen"
		if holder==id or not secured:
			# One holder plus separate approaches during a retake. Every approach
			# stays inside the real 3m scoring radius, including the stop margin.
			ai.candidate(rows,"hill:%s"%slot,"objective",mode.hill if holder==id else station(id,mode.hill,1.7,slot),145,true)
		else:
			ai.candidate(rows,"hill:screen:%s"%slot,"guard",station(id,mode.hill,4.8,slot),105,true)
			rows[-1].look=mode.hill
		return true
	if mode.kind!="ctf" or mode.flags.size()!=2:return false
	var own: Dictionary=mode.flags[s.team];var flag: Dictionary=mode.flags[1-s.team]
	brain.role="defend" if slot==0 and roster.size()>1 else "support" if slot==1 and roster.size()>2 else "attack"
	if flag.carrier==id:
		ai.candidate(rows,"capture","capture",mode.bases[s.team],260,true)
	elif ai.alive(flag.carrier) and mode.same_team(id,flag.carrier):
		var escort:=nearest(id,game.fighters[flag.carrier].position,"escort",flag.carrier)
		if id==escort:ai.candidate(rows,"escort:%s"%flag.carrier,"escort",ai.teamplay.escort_point(id,flag.carrier),150,true,flag.carrier)
		elif brain.role!="defend":
			# The second attacker clears the return route instead of abandoning
			# a newly acquired carrier to run all the way home immediately.
			ai.candidate(rows,"carrier:screen:%s"%slot,"guard",carrier_screen(id,flag.carrier),200,true,flag.carrier);rows[-1].look=flag.position
		else:
			ai.candidate(rows,"home:screen:%s"%slot,"guard",station(id,mode.bases[s.team],5,slot),105,true);rows[-1].look=mode.bases[1-s.team]
	elif brain.role=="defend":
		ai.candidate(rows,"base:%s"%slot,"defend",station(id,mode.bases[s.team],4,slot),105,true)
	else:
		if flag.dropped or not push_goal(id,slot,rows):ai.candidate(rows,"flag","objective",flag.position,135 if brain.role=="attack" else 115)
	if own.dropped:
		if nearest(id,own.position,"return")==id:ai.candidate(rows,"return","objective",own.position,230)
	elif ai.alive(own.carrier):
		# Public carrier position: intercept remains an emergency for everyone
		# except our carrier. It is useful concentration, unlike idle clustering.
		if flag.carrier!=id:ai.candidate(rows,"intercept","intercept",game.fighters[own.carrier].position,210)
	return true
