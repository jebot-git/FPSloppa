extends RefCounted
## Match-local experience and bounded attack coordination. All movement and
## interactions still pass through the ordinary player controller.
var ai_ref: WeakRef
var ai:
	get:return ai_ref.get_ref()
	set(value):ai_ref=weakref(value)
var memory: Dictionary={}
var waves: Dictionary={}
var next_tick:=0.0
var epoch:=-1
var stats: Dictionary={}
func count(key: String):stats[key]=int(stats.get(key,0))+1
func record(id: int) -> Dictionary:
	var game=ai.game;var team: int=game.players[id].team
	if not memory.has(id) or memory[id].team!=team:
		memory[id]={"team":team,"serial":game.players[id].serial,"dead":false,"lane":posmod(ai.team_rank(id),3),"failures":[],"stages":[],"watches":{},"recoveries":0}
	return memory[id]
func lane(id: int) -> int:return [1,-1,0][record(id).lane]
func detours(id: int) -> Array:return record(id).failures
func committed(id: int) -> bool:
	var team: int=ai.game.players[id].team;var wave: Dictionary=waves.get(team,{})
	return float(record(id).get("attempt_until",0))>ai.game.clock or not wave.is_empty() and id in wave.members and wave.until>ai.game.clock
func tick():
	var game=ai.game
	if epoch!=game.map_epoch or game.clock<next_tick-1:
		memory.clear();waves.clear();epoch=game.map_epoch;next_tick=0
	if game.clock<next_tick:return
	next_tick=game.clock+.5
	ai.tribes.offense.tick()
	for id in memory.keys():
		if not game.players.has(id):memory.erase(id)
	for id in ai.brains:
		if not game.players.has(id) or game.players[id].spectator:continue
		var m:=record(id);var s: Dictionary=game.players[id];var brain: Dictionary=ai.brains[id]
		m.failures=m.failures.filter(func(row):return row.until>game.clock)
		m.stages=m.stages.filter(func(row):return row.until>game.clock)
		if s.dead and not m.dead and brain.goal_key in ["st:flag","st:capture","st:attack-generator"]:
			m.lane=(int(m.lane)+1)%3;count("attack_lane_changes")
		m.dead=s.dead
		if m.serial!=s.serial:m.serial=s.serial;m.watches.clear();m.erase("attempt_until");m.erase("attempt_after")
		if ai.alive(id):watch(id,brain,m)
	for team in [0,1]:update_wave(team)
func reject_stage(id: int,goal: Vector3,point: Vector3):
	var m:=record(id)
	m.stages.append({"goal":goal,"point":point,"armour":ai.game.players[id].tribes_class,"until":ai.game.clock+180})
	if m.stages.size()>12:m.stages.pop_front()
	count("failed_launches")
func stage_cost(id: int,goal: Vector3,point: Vector3) -> float:
	var cost:=0.0
	for row in record(id).stages:
		if row.until>ai.game.clock and row.armour==ai.game.players[id].tribes_class and row.goal.distance_to(goal)<10 and row.point.distance_to(point)<18:cost+=100
	return cost
func watch(id: int,brain: Dictionary,m: Dictionary):
	var game=ai.game;var actor=game.fighters[id]
	var flag_distance: float=actor.position.distance_to(game.match_mode.bases[1-game.players[id].team])
	if flag_distance>140:m.erase("attempt_until")
	if brain.goal_key=="st:flag" and flag_distance<100 and not m.has("attempt_until") and game.clock>=float(m.get("attempt_after",0)):
		m.attempt_until=game.clock+55;count("approaches_committed")
	if brain.goal_key.is_empty() or brain.has("st_recovery"):return
	var target: Vector3=brain.goal;var key: String=brain.goal_key
	if brain.has("tower") and brain.tower.phase=="stage":target=brain.tower.stage;key+="/stage"
	var distance: float=actor.position.distance_to(target)
	if distance<maxf(3,ai.stop_radius(brain)+1) or brain.goal_kind in ["st_rally","st_hold"] and distance<7:return
	if game.players[id].fire and brain.goal_kind in ["st_repair","st_asset_repair","st_deploy_repair","st_fixed_repair","st_fixed_attack","st_base_attack","st_destroy"]:return
	var old: Dictionary=m.watches.get(key,{})
	if old.is_empty() or old.target.distance_to(target)>12 or distance<old.best-5:
		if m.watches.size()>=8:m.watches.erase(m.watches.keys()[0])
		m.watches[key]={"target":target,"best":distance,"at":game.clock};return
	var carrying: bool=ai.tribes.carrier(id)
	# Distinguish a stopped carrier from a useful route detour. Restarting
	# merely because home is not closer after eight seconds breaks run-ups.
	if not old.has("stall_at") or Vector2(actor.velocity.x,actor.velocity.z).length()>2 or actor.position.distance_to(old.get("stall_position",actor.position))>1.5:
		old.stall_at=game.clock;old.stall_position=actor.position
	var heavy: bool=game.players[id].tribes_class=="heavy"
	var stopped: bool=carrying and game.clock-old.stall_at>=(12 if heavy else 8)
	if not stopped and game.clock-old.at<(60 if heavy else 35):return
	old.at=game.clock;old.best=distance
	var next: Vector3=brain.path[brain.step] if brain.step<brain.path.size() else target
	m.failures.append({"point":next,"until":game.clock+120})
	if m.failures.size()>12:m.failures.pop_front()
	if brain.has("tower"):reject_stage(id,brain.goal,brain.tower.stage)
	m.lane=(int(m.lane)+1)%3;m.recoveries+=1;count("progress_recoveries")
	if stopped:count("stopped_carrier_recoveries")
	if brain.goal_kind=="st_fixed_repair":ai.tribes.equipment.defer_fixed(game.players[id].team,int(brain.support))
	m.erase("attempt_until");m.attempt_after=game.clock+20
	brain.erase("tower");brain.route_at=0;brain.plan_at=0
	var escape: Vector3=ai.tribes.routes.escape(actor.position,next)
	if escape.is_finite():brain.st_recovery={"point":escape,"until":game.clock+8}
func recover(id: int,brain: Dictionary) -> bool:
	if not brain.has("st_recovery"):return false
	var game=ai.game;var row: Dictionary=brain.st_recovery
	if game.clock>=row.until or game.fighters[id].position.distance_to(row.point)<2:
		brain.erase("st_recovery");brain.route_at=0;brain.plan_at=0;return false
	if not row.has("controller"):
		row.controller=brain.duplicate();row.controller.erase("st_recovery");row.controller.erase("tower");row.controller.staging=true
		row.controller.goal=row.point;row.controller.goal_kind="objective";row.controller.path=PackedVector3Array([row.point]);row.controller.step=0
	row.controller.enemy=brain.enemy;row.controller.equipment_aim_until=brain.get("equipment_aim_until",0)
	ai.tribes.steer(id,row.controller);brain.travel_phase="route_recovery";return true
func update_wave(team: int):
	var game=ai.game;var mode=game.match_mode
	if mode.flags.size()!=2:return
	var wave: Dictionary=waves.get(team,{})
	if mode.flags.any(func(flag):return flag.carrier!=0 or flag.dropped):
		if not wave.is_empty() and not wave.members.is_empty():count("pushes_interrupted")
		waves[team]={"members":[],"until":0.0,"next":game.clock+12};return
	if not wave.is_empty() and not wave.members.is_empty():
		wave.members=wave.members.filter(func(id):return ai.alive(id) and game.players[id].team==team and ai.tribes.assignments.get(id,"")=="capper")
		if game.clock>=wave.until or wave.members.is_empty():
			wave.members=[];wave.next=game.clock+15
		return
	if game.clock<float(wave.get("next",35)):return
	var group: Array=ai.brains.keys().filter(func(id):return ai.alive(id) and game.players[id].team==team and ai.tribes.assignments.get(id,"")=="capper" and game.players[id].hp>mode.tribes.definition(id).hp*.55)
	if group.size()<2:return
	var goal: Vector3=mode.bases[1-team]
	group.sort_custom(func(a,b):return game.fighters[a].position.distance_squared_to(goal)<game.fighters[b].position.distance_squared_to(goal))
	var lead: int=group[0];var origin: Vector3=game.fighters[lead].position
	# Never drag an attacker away from a nearly completed approach.
	if origin.distance_to(goal)<75 or origin.distance_to(goal)>230:return
	# Group runners with similar arrival times. Never replace a ski route with
	# a stationary rendezvous or make the leading capper reverse to collect help.
	var eta: float=arrival_seconds(lead,goal)
	group=group.filter(func(id):return absf(arrival_seconds(id,goal)-eta)<5 and game.fighters[id].position.distance_to(origin)<110)
	if group.size()<2:return
	group=group.slice(0,3)
	waves[team]={"members":group,"point":origin,"phase":"attack","until":game.clock+minf(45,eta+15),"next":0.0}
	count("pushes_formed");count("moving_pushes")
func arrival_seconds(id: int,goal: Vector3) -> float:
	var actor=ai.game.fighters[id];var toward: Vector3=goal-actor.position;toward.y=0
	var speed: float=maxf(12,Vector3(actor.velocity.x,0,actor.velocity.z).dot(toward.normalized()))
	return toward.length()/minf(speed,45)
func push_goal(_id: int,_rows: Array) -> bool:
	# Kept as the planner hook: a moving push commits roles, not stopping points.
	return false
func intercept_point(id: int,carrier: int) -> Vector3:
	var game=ai.game;var target=game.fighters[carrier];var chaser=game.fighters[id]
	var velocity: Vector3=target.velocity;velocity.y=0
	if velocity.length()<4:return target.position
	# Flag position/motion are public. No enemy route, aim or hidden target is
	# consulted. Bound prediction so turns can be corrected on the next plan.
	var seconds: float=clampf(chaser.position.distance_to(target.position)/maxf(15,Vector2(chaser.velocity.x,chaser.velocity.z).length()+10),.5,2.5)
	for fraction in [1.0,.5]:
		var probe: Vector3=target.position+(velocity*seconds*fraction).limit_length(80)
		var hit: Dictionary=ai.navigation.ray(probe+Vector3.UP*24,probe-Vector3.UP*60)
		if hit.is_empty() or hit.normal.y<.6 or ai.navigation.hazardous(hit.position):continue
		var point: Vector3=hit.position+Vector3.UP*.06
		if ai.tribes.routes.attach(point,true)>=0:return point
	return target.position

func carrier_goal(id: int,brain: Dictionary,rows: Array):
	var game=ai.game;var team: int=game.players[id].team;var own: Dictionary=game.match_mode.flags[team]
	if own.carrier==0 and not own.dropped or game.fighters[id].position.distance_to(game.match_mode.bases[team])>100:
		ai.candidate(rows,"st:capture","capture",game.match_mode.bases[team],600,true);return
	if own.dropped and game.fighters[id].position.distance_to(own.position)<60:
		ai.candidate(rows,"st:carrier-return","objective",own.position,650);return
	# Hold behind real bunker cover until a teammate returns our flag. Cache
	# the choice so an approaching threat does not cause constant pad switching.
	if not brain.has("st_hold") or brain.st_hold.until<game.clock:
		var point: Vector3=game.match_mode.bases[team];var cost:=INF
		var threats: Array=ai.teamplay.intel(id).map(func(row):return row.position)
		if ai.alive(brain.enemy):threats.append(brain.seen_position)
		for row in game.match_mode.tribes.stations().rows:
			if row.team!=team:continue
			for side in [-1,1]:
				var candidate: Vector3=row.frame*Vector3(side*3.6,0,0)
				var floor_hit: Dictionary=ai.navigation.ray(candidate+Vector3.UP*.5,candidate-Vector3.UP*1.5)
				if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
				candidate=floor_hit.position+Vector3.UP*.06
				var score: float=game.fighters[id].position.distance_to(candidate)*.2
				for threat in threats:
					if ai.navigation.ray(threat+Vector3.UP,candidate+Vector3.UP).is_empty():score+=80
				if score<cost:cost=score;point=candidate
		brain.st_hold={"point":point,"until":game.clock+12};count("carrier_holds")
	ai.candidate(rows,"st:hold","st_hold",brain.st_hold.point,600,true)
func escort_point(id: int,carrier: int) -> Vector3:
	var game=ai.game;var actor=game.fighters[carrier];var anchor: Vector3=actor.position
	var direction: Vector3=game.match_mode.bases[game.players[id].team]-anchor;direction.y=0;direction=direction.normalized()
	var escorts: Array=ai.tribes.assignments.keys().filter(func(friend):return ai.alive(friend) and game.players[friend].team==game.players[id].team and ai.tribes.assignments[friend]=="escort")
	escorts.sort();var front: bool=escorts.find(id)==0
	var brain: Dictionary=ai.brains.get(carrier,{})
	var lead_distance: float=clampf(Vector2(actor.velocity.x,actor.velocity.z).length()*1.5,12,65)
	if front and not brain.is_empty():
		var path: PackedVector3Array=brain.path
		for i in range(brain.step,path.size()):
			if anchor.distance_to(path[i])>=lead_distance and anchor.distance_to(path[i])<lead_distance+27:
				anchor=path[i];break
	var side:=direction.cross(Vector3.UP)*(1 if front else -1)
	var point: Vector3=anchor+direction*(5 if front else -8)+side*6
	# A single projection can land on a cliff face. Search the same flank
	# for a walkable surface instead of falling back beside an airborne carrier.
	for offset in [Vector3.ZERO,side*6,direction*6,-direction*6,side*12,direction*12,-direction*12]:
		var probe: Vector3=point+offset
		var hit: Dictionary=ai.navigation.ray(probe+Vector3.UP*24,probe-Vector3.UP*48)
		if not hit.is_empty() and hit.normal.y>.6 and hit.position.distance_to(actor.position)>4 and not ai.navigation.hazardous(hit.position):return hit.position+Vector3.UP*.06
	return ai.teamplay.escort_point(id,carrier)
