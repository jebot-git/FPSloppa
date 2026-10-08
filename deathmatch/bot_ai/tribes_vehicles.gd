extends RefCounted
## Limited air support: walk to a powered terminal, buy, board and fly using
## ordinary inputs. Infantry keep flag duties; no free vehicles or teleporting.
var ai
var plans: Dictionary={}
var retry: Dictionary={}
var epoch:=-1
var recruit_at:=0.0
var stats: Dictionary={"purchases":0,"boards":0,"distance":0.0,"pilot_seconds":0.0,"shots":0,"events":[]}
func recruit():
	var game=ai.game;var fleet=game.match_mode.tribes.vehicles;var pads=game.match_mode.tribes.stations()
	if epoch!=game.map_epoch:
		epoch=game.map_epoch;plans.clear();retry.clear();recruit_at=0
		stats={"purchases":0,"boards":0,"distance":0.0,"pilot_seconds":0.0,"shots":0,"events":[]}
	if not fleet.active() or not pads:return
	for id in plans.keys():
		if not ai.alive(id) or game.players[id].serial!=plans[id].life or not fleet.mounted(id) and game.clock>plans[id].deadline:
			plans.erase(id);retry[id]=game.clock+30
	if game.clock<recruit_at:return
	recruit_at=game.clock+2
	for team in [0,1]:
		var members: Array=game.players.keys().filter(func(id):return id<0 and not game.players[id].spectator and game.players[id].team==team)
		var limit:=mini(2,members.size()/6)
		if plans.keys().filter(func(id):return game.players[id].team==team).size()>=limit:continue
		# Launch one craft at a time from a shared pad; a second hull must not
		# appear immediately below the first pilot during takeoff.
		if plans.keys().any(func(id):return game.players[id].team==team and (not fleet.piloting(id) or game.fighters[id].position.distance_to(pads.rows[plans[id].station].position)<60)):continue
		var best:=0;var terminal:=-1;var cost:=INF
		for i in pads.rows.size():
			var pad: Dictionary=pads.rows[i]
			if pad.kind!="vehicle" or pad.team not in [-1,team] or not pads.connected(pad) or not pads.assets.active(pad.asset):continue
			for id in members:
				if not ai.alive(id) or ai.delegated.has(id) or plans.has(id) or game.clock<float(retry.get(id,0)) or fleet.mounted(id) or ai.tribes.carrier(id) or game.players[id].tribes_class!="light" or game.match_mode.tribes.commander.orders.has(id):continue
				var distance: float=game.fighters[id].position.distance_squared_to(pad.position)
				if distance<cost:cost=distance;best=id;terminal=i
		if best!=0:
			plans[best]={"station":terminal,"life":game.players[best].serial,"deadline":game.clock+100,"key":0,"action_at":0.0,"route_at":0.0,"last_position":Vector3.INF,"next_fire":0.0,"patrol":0,"stuck_at":game.clock,"progress":game.fighters[best].position}
func event(kind: String,id: int,key: int):
	stats.events.append({"kind":kind,"id":id,"team":ai.game.players[id].team,"vehicle":key,"seconds":ai.game.clock})
	if stats.events.size()>128:stats.events.pop_front()
func tick(id: int,brain: Dictionary,delta: float) -> bool:
	var game=ai.game;var fleet=game.match_mode.tribes.vehicles
	if not fleet.active() or not plans.has(id):return false
	var plan: Dictionary=plans[id];var s: Dictionary=game.players[id];var pads=game.match_mode.tribes.stations()
	if ai.tribes.carrier(id) or s.tribes_class!="light":plans.erase(id);return false
	brain.role="pilot";brain.goal_key="st:vehicle";brain.goal_kind="objective"
	s.fire=false;s.alt_fire=false;s.melee=false;s.jump=false;s.ski=false;s.jet_held=false;s.move=Vector2.ZERO
	var key: int=fleet.vehicle_for(id)
	if key!=0:
		pilot(id,brain,plan,key,delta);return true
	if not pads or plan.station>=pads.rows.size():plans.erase(id);return false
	var pad: Dictionary=pads.rows[plan.station]
	if not pads.connected(pad) or not pads.assets.active(pad.asset):plans.erase(id);retry[id]=game.clock+15;return false
	key=int(plan.key)
	if not fleet.rows.has(key) or fleet.rows[key].pilot!=0:
		key=0
		for candidate in fleet.rows:
			var row: Dictionary=fleet.rows[candidate]
			if row.pilot==0 and row.team==s.team and row.kind in ["scout","shrike"] and row.position.distance_to(pad.position)<35 and not plans.keys().any(func(other):return other!=id and plans[other].key==candidate):key=candidate;break
		plan.key=key
	var target: Vector3=pad.position
	if key!=0:
		var row: Dictionary=fleet.rows[key]
		# Approach the cockpit from outside the hull, then use the real reach test.
		target=fleet.seat_position(row,0)+Basis(Vector3.UP,row.yaw)*Vector3(fleet.definition(row).half.x+.5,0,0)
		target.y=row.position.y-fleet.definition(row).half.y
		if game.clock>=plan.action_at and fleet.reachable(id,key,0):
			plan.action_at=game.clock+.5
			if ai.action("st_vehicle_board",[id,key]):
				stats.boards+=1;event("board",id,key);plan.last_position=row.position;plan.stuck_at=game.clock;plan.progress=row.position
				return true
	elif fleet.station(id)>=0 and game.clock>=plan.action_at:
		plan.action_at=game.clock+2
		var kind: String="shrike" if fleet.count(s.team,"scout")>0 else "scout"
		var before: int=fleet.next_id;var balance: int=game.match_mode.tribes.balance(id)
		if ai.action("st_vehicle_buy",[id,kind]):
			plan.key=before;stats.purchases+=1;event("purchase",id,before)
			stats.events[-1].merge({"vehicle_kind":kind,"balance_before":balance,"balance_after":game.match_mode.tribes.balance(id)})
		return true
	if brain.get("goal",Vector3.INF).distance_to(target)>2 or game.clock>=plan.route_at:
		brain.goal=target;brain.path=ai.tribes.path(game.fighters[id].position,target,id);brain.step=0;brain.route_at=game.clock+10;plan.route_at=game.clock+8
		brain.erase("tower");brain.erase("st_recovery")
	ai.aim(id,target+Vector3.UP,delta*4)
	ai.tribes.steer(id,brain)
	return true
func ray(key: int,origin: Vector3,end: Vector3) -> Dictionary:
	var fleet=ai.game.match_mode.tribes.vehicles
	return ai.game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1,[fleet.bodies[key].get_rid()]))
func pilot(id: int,brain: Dictionary,plan: Dictionary,key: int,delta: float):
	var game=ai.game;var fleet=game.match_mode.tribes.vehicles;var row: Dictionary=fleet.rows[key];var s: Dictionary=game.players[id];var d: Dictionary=fleet.definition(row)
	if row.pilot!=id:return
	stats.pilot_seconds+=delta
	if plan.last_position!=Vector3.INF:stats.distance+=row.position.distance_to(plan.last_position)
	plan.last_position=row.position
	if row.next_fire>plan.next_fire:stats.shots+=1;plan.next_fire=row.next_fire
	if row.position.distance_to(plan.progress)>5:plan.progress=row.position;plan.stuck_at=game.clock
	if game.clock-plan.stuck_at>15:
		if ai.action("st_vehicle_leave",[id]):plans.erase(id);retry[id]=game.clock+30;brain.plan_at=0
		return
	# Patrol public midfield / enemy approaches, never hidden enemy positions.
	var home: Vector3=game.match_mode.bases[s.team];var enemy: Vector3=game.match_mode.bases[1-s.team]
	var forward: Vector3=(enemy-home).normalized();var side:=forward.cross(Vector3.UP).normalized()
	var target: Vector3=home.lerp(enemy,.55 if plan.patrol%2==0 else .78)+side*(40 if plan.patrol%4<2 else -40)
	if Vector2(target.x-row.position.x,target.z-row.position.z).length()<25:plan.patrol+=1
	var floor_hit:=ray(key,row.position,row.position-Vector3.UP*500)
	var height: float=row.position.y-floor_hit.position.y if not floor_hit.is_empty() else d.altitude
	var desired_height: float=minf(20,d.altitude*.7)
	var roof:=ray(key,row.position,row.position+Vector3.UP*30)
	var covered: bool=not roof.is_empty()
	if covered:desired_height=minf(desired_height,maxf(2,(height+roof.position.y-row.position.y)*.45))
	var shooting:=false;var victim: int=brain.get("enemy",0)
	if ai.alive(victim) and victim in brain.get("visible",[]):
		var observed: Vector3=ai.target_position(victim)
		if row.position.distance_to(observed)<180 and ray(key,row.position,observed).is_empty():
			target=observed+game.fighters[victim].velocity*minf(.7,row.position.distance_to(observed)/fleet.Data.projectile(row.kind).speed);shooting=true
	var direction: Vector3=target-row.position
	s.yaw=atan2(-direction.x,-direction.z)
	var angle: float=absf(wrapf(s.yaw-row.yaw,-PI,PI))
	s.pitch=clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-.45,.45) if shooting else clampf((desired_height-height)*.04,-.25,.3)
	s.move=Vector2(0,-.55 if angle<.55 else -.15)
	s.jet_held=height<desired_height-3
	var nose: Vector3=Basis(Vector3.UP,row.yaw)*Vector3.FORWARD
	var obstacle:=ray(key,row.position,row.position+nose*maxf(15,row.velocity.length()*2))
	if not obstacle.is_empty() or covered:
		# Covered launch bays need a horizontal exit before VTOL. Probe actual
		# hull-width corridors, preferring the objective direction when clear.
		var best:=-INF;var heading: float=row.yaw
		for i in 16:
			var yaw: float=i*TAU/16;var ahead:=Basis(Vector3.UP,yaw)*Vector3.FORWARD
			var right:=Basis(Vector3.UP,yaw)*Vector3.RIGHT;var distance:=35.0
			for lateral in [-1,0,1]:
				var origin: Vector3=row.position+right*lateral*(d.half.x+.3)
				var hit:=ray(key,origin,origin+ahead*35)
				if not hit.is_empty():distance=minf(distance,origin.distance_to(hit.position))
			var score: float=distance+ahead.dot(direction.normalized())*5
			if score>best:best=score;heading=yaw
		s.yaw=heading;angle=absf(wrapf(s.yaw-row.yaw,-PI,PI))
		s.move=Vector2(0,-.22 if angle<.35 else 0)
		s.pitch=clampf((desired_height-height)*.06,-.3,.3)
		s.jet_held=not covered;shooting=false
	if height<3 and not covered:s.move=Vector2.ZERO;s.jet_held=true;shooting=false
	plan.telemetry={"height":height,"angle":angle,"obstacle":obstacle.get("position",Vector3.INF),"obstacle_name":str(obstacle.get("collider","")),"move":s.move,"jet":s.jet_held,"pitch":s.pitch,"velocity":row.velocity}
	s.fire=shooting and angle<.10 and absf(row.pitch-s.pitch)<.10 and not s.jet_held
	brain.goal=target;brain.travel_phase="vehicle_patrol"
