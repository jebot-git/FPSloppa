extends RefCounted
## Outdoor jet/ski routes supplement the walking mesh, using ordinary inputs.
var ai_ref: WeakRef
var ai:
	get:return ai_ref.get_ref()
var routes=preload("res://deathmatch/bot_ai/tribes_routes.gd").new()
var equipment=preload("res://deathmatch/bot_ai/tribes_equipment.gd").new()
var construction=preload("res://deathmatch/bot_ai/tribes_construction.gd").new()
var offense=preload("res://deathmatch/bot_ai/tribes_offense.gd").new()
var tactics=preload("res://deathmatch/bot_ai/tribes_tactics.gd").new()
func setup(value):ai_ref=weakref(value);routes.ai=value;equipment.ai=value;tactics.ai=value;offense.ai=value;construction.ai=value

var assignments: Dictionary={}
var assignment_state: Dictionary={}
func role(id: int) -> String:
	if not ai.game.players.has(id):return "capper"
	var team: int=ai.game.players[id].team
	if team not in [0,1] or ai.game.match_mode.flags.size()!=2:return "capper"
	assign_roles(team,id)
	return assignments.get(id,"capper")
func allocate(pool: Array,point: Vector3,job: String,result: Dictionary) -> int:
	var best:=0;var cost:=INF;var game=ai.game
	for id in pool:
		var s: Dictionary=game.players[id];var actor=game.fighters[id]
		var value: float=actor.position.distance_to(point)/maxf(8,game.match_mode.tribes.definition(id).walk)
		value-=2 if assignments.get(id,"")==job else 0 # hysteresis, not a fixed role
		if job not in ["chaser","escort"] and tactics.committed(id):value+=20
		if job=="repairer":
			var pads=game.match_mode.tribes.stations()
			var working: bool=s.tribes_pack=="repair" or game.match_mode.tribes.deployables.Data.is_pack(s.tribes_pack) and pads and not equipment.essential_damage(s.team)
			value+=(-12 if working else 0 if s.tribes_pack=="none" else 200)
			if not equipment.essential_damage(s.team) and construction.plans.has(id) and construction.plans[id].until>game.clock:value-=60
		if job=="flag_defense" and s.tribes_class=="heavy":value-=5
		if job=="siege" and s.tribes_class=="heavy" and 7 in s.owned:value-=15
		if job=="flag_defense" and s.tribes_pack in ["repair","turret"]:value+=12
		if job in ["chaser","escort"]:value+=(1-actor.tribes_state.energy/game.match_mode.tribes.definition(id).energy)*4
		if value<cost:best=id;cost=value
	if best!=0:result[best]=job;pool.erase(best)
	return best
func assign_roles(team: int,member: int):
	var game=ai.game;var mode=game.match_mode;var pads=mode.tribes.stations();var group: Array=ai.objectives.members(member)
	var own: Dictionary=mode.flags[team];var enemy: Dictionary=mode.flags[1-team]
	var signature: String=str(group)+str([own.carrier,own.dropped,enemy.carrier,enemy.dropped,0 if not pads or not pads.powered(team) else 1 if pads.generators.any(func(row):return row.team==team and pads.source_hp(row)<row.maximum) else 2,equipment.damaged(team)])
	var state: Dictionary=assignment_state.get(team,{})
	if state.get("signature","")==signature and game.clock<float(state.get("until",-1)):return
	assignment_state[team]={"signature":signature,"until":game.clock+1}
	var pool:=group.duplicate();var result: Dictionary={}
	if enemy.carrier in pool:result[enemy.carrier]="capper";pool.erase(enemy.carrier)
	# Public flag emergencies interrupt any former job, including defence.
	if own.dropped or own.carrier!=0:
		var point: Vector3=game.fighters[own.carrier].position if ai.alive(own.carrier) else own.position
		for i in mini(2 if group.size()>=4 else 1,pool.size()):allocate(pool,point,"chaser",result)
	if pads and equipment.damaged(team):
		var base:=generator(team)
		var repair_pool: Array=pool.filter(func(id):return equipment.service(team) or game.players[id].tribes_pack in ["none","repair"])
		for i in mini(2 if not pads.powered(team) and pool.size()>=4 else 1,repair_pool.size()):
			var selected:=allocate(repair_pool,base.position,"repairer",result);pool.erase(selected)
	if ai.alive(enemy.carrier):
		for i in mini(2 if pool.size()>=4 else 1,pool.size()):allocate(pool,game.fighters[enemy.carrier].position,"escort",result)
	# Keep one home cover when numbers allow; observed base pressure can
	# request a second defender. No hidden enemy positions drive assignments.
	var threats: Dictionary={}
	for id in group:
		var observed: Array=ai.brains.get(id,{}).get("visible",[]).duplicate()
		observed.append_array(mode.tribes.deployables.contacts[team])
		for opponent in observed:
			if ai.alive(opponent) and game.fighters[opponent].position.distance_to(mode.bases[team])<70:threats[opponent]=true
	# Use available mortar armour for offence while home is quiet. Otherwise
	# every purchased Heavy was immediately reclaimed by the home-guard bias.
	if pool.size()>=3 and group.size()>=4 and threats.size()<2 and own.carrier==0 and not own.dropped and enemy.carrier==0:
		var artillery: Array=pool.filter(func(id):return not tactics.committed(id) and game.players[id].tribes_class=="heavy" and 7 in game.players[id].owned)
		if artillery.is_empty():artillery=pool.filter(func(id):return not tactics.committed(id) and game.players[id].tribes_pack=="none" and pads and pads.rows.any(func(row):return row.kind=="inventory" and row.team==team and game.fighters[id].position.distance_to(row.position)<25))
		if not artillery.is_empty():pool.erase(allocate(artillery,mode.bases[1-team],"siege",result))
	if pool.size()>=2:
		allocate(pool,mode.bases[team],"flag_defense",result)
		if threats.size()>=2 and pool.size()>=3:allocate(pool,mode.bases[team],"flag_defense",result)
	if pool.size()>=3 and pads and pads.powered(team) and not result.values().has("repairer"):
		var available: Array=pool.filter(func(id):return not tactics.committed(id))
		if not available.is_empty():pool.erase(allocate(available,mode.bases[team],"repairer",result))
	if pool.size()>=3 and pads and pads.powered(1-team) and not result.values().has("siege"):
		var available: Array=pool.filter(func(id):return not tactics.committed(id))
		if not available.is_empty():pool.erase(allocate(available,mode.bases[1-team],"siege",result))
	for id in pool:result[id]="capper"
	for id in group:
		var job: String=result.get(id,"capper")
		if assignments.get(id,"")!=job and ai.brains.has(id):ai.brains[id].plan_at=0
		assignments[id]=job
func outfit(job: String) -> Dictionary:
	match job:
		"repairer":return {"armour":"medium","guns":[3,2,1,4],"pack":"repair"}
		"flag_defense","siege":return {"armour":"heavy","guns":[3,2,1,4,7],"pack":"energy"}
	return {"armour":"light","guns":[3,2,4],"pack":"energy"}
func generator(team: int) -> Dictionary:
	var pads=ai.game.match_mode.tribes.stations()
	if pads:
		var sources: Array=pads.generators.filter(func(row):return row.team==team)
		sources.sort_custom(func(a,b):return pads.source_hp(a)/a.maximum<pads.source_hp(b)/b.maximum)
		if not sources.is_empty():return sources[0]
	return {}
func carrier(id: int) -> bool:return ai.game.match_mode.st.carried(id)>=0
func flag_changed(id: int,brain: Dictionary) -> bool:
	var mode=ai.game.match_mode
	if mode.flags.size()!=2:return false
	var signature: Array=[]
	for flag in mode.flags:signature.append_array([flag.carrier,flag.dropped])
	var changed: bool=brain.has("st_flags") and brain.st_flags!=signature
	brain.st_flags=signature
	if changed:
		brain.plan_at=0
		if carrier(id):
			# A touch is already public. Do not spend another planning interval
			# braking on the enemy flag or backing toward a stale launch point.
			brain.erase("tower");brain.erase("st_recovery");brain.route_at=0
	return changed
func goals(id: int,brain: Dictionary,rows: Array) -> void:
	var game=ai.game;var rules=game.match_mode.tribes;var mode=game.match_mode;var s: Dictionary=game.players[id]
	if s.team not in [0,1] or mode.flags.size()!=2:return
	var pads=rules.stations();var job:=role(id);brain.role=job
	var own: Dictionary=mode.flags[s.team];var flag: Dictionary=mode.flags[1-s.team]
	if s.hp<rules.definition(id).hp*.7:rules.kit(id)
	# The carrier stays on the return job even with depleted ammo or low HP.
	if flag.carrier==id:
		offense.pass_flag(id,brain)
		tactics.carrier_goal(id,brain,rows)
		return
	if offense.catch_goal(id,rows):return
	equipment.recovery_goal(id,rows)
	if rules.can_refit(id) and job in ["capper","escort"]:rules.targeting.buy(id)
	var loadout:=outfit(job)
	var deploy=rules.deployables
	# Keep generator/station repairs urgent, but do not let an unreachable
	# elevated turret indefinitely prevent rebuilding the team's field network.
	var build_plan: Dictionary=construction.plan(id) if job=="repairer" and pads and not equipment.essential_damage(s.team) and not own.dropped and own.carrier==0 and not ai.alive(flag.carrier) else {}
	var building: bool=not build_plan.is_empty()
	if building:loadout={"armour":"medium","guns":[3,2,4,1],"pack":build_plan.kind}
	var needs: bool=s.tribes_pack=="none" or s.tribes_class!=loadout.armour or s.tribes_pack!=loadout.pack
	# Changing the job should change the objective immediately, not send an
	# equipped attacker all the way home just to exchange armour/backpacks.
	var near_inventory: bool=pads and pads.rows.any(func(row):return row.kind=="inventory" and row.team==s.team and game.fighters[id].position.distance_to(row.position)<25)
	var refit_needed: bool=job=="capper" and offense.prepare(id,brain) or job!="capper" and s.tribes_pack=="none" and near_inventory or rules.can_refit(id) or job=="repairer" and (building or s.tribes_pack!="repair" and equipment.damaged(s.team))
	var purchase: bool=needs and refit_needed and rules.balance(id)>=rules.refit_cost(id,loadout.armour,loadout.guns,loadout.pack)
	var emergency: bool=own.dropped or own.carrier!=0 or job in ["escort","chaser"]
	if purchase and rules.can_refit(id) and not emergency:
		rules.select_equipment(id,loadout.armour,loadout.guns,loadout.pack,true);purchase=false
	var empty: bool=rules.amount(id,3)==0 and rules.amount(id,2)<10
	if empty or s.hp<rules.definition(id).hp*.55:brain.refilling=true
	if s.hp>=rules.definition(id).hp*.85 and rules.amount(id,3)>=5 and rules.amount(id,2)>=20:brain.refilling=false
	if pads and not emergency and (purchase or brain.get("refilling",false)):
		var best:=-1;var distance:=INF
		for i in pads.rows.size():
			var row: Dictionary=pads.rows[i]
			if row.team!=s.team or row.kind not in (["inventory"] if purchase or s.hp<rules.definition(id).hp*.85 else ["inventory","ammo"]) or not pads.assets.active(row.asset):continue
			var cost: float=game.fighters[id].position.distance_to(row.position)
			for friend in ai.brains:
				if friend!=id and ai.alive(friend) and ai.brains[friend].goal_key=="tribes:inventory:%d"%i:cost+=8
			if cost<distance:distance=cost;best=i
		if best>=0:ai.candidate(rows,"tribes:inventory:%d"%best,"supply",pads.rows[best].position,500 if purchase else 320,true)
	if brain.get("refilling",false):construction.remote_supply(id,rows,s.hp<rules.definition(id).hp*.85)
	if building and s.tribes_pack==build_plan.kind:
		construction.goal(id,rows,build_plan);return
	# One repair specialist preserves base service. The free rack lets a
	# respawned specialist recover when the powered stations are unavailable.
	var base:=generator(s.team)
	if job=="repairer" and pads and not base.is_empty() and equipment.damaged(s.team):
		if s.tribes_pack=="repair":
			if pads.source_hp(base)<base.maximum:ai.candidate(rows,"st:repair","st_repair",base.position+base.frame.basis.z*3.8,540,true,s.team)
			else:equipment.repair_goal(id,rows)
		elif s.tribes_pack=="none":ai.candidate(rows,"st:repair-pack","supply",base.repair_position,550,true)
	if own.dropped:
		if job=="chaser":
			ai.candidate(rows,"st:return","objective",own.position,520);return
	elif ai.alive(own.carrier) and job=="chaser":
		# Public flag position permits pursuit; it does not bypass LOS for fire.
		ai.candidate(rows,"st:intercept","intercept",game.fighters[own.carrier].position,510);return
	if ai.alive(flag.carrier):
		if job=="escort":
			ai.candidate(rows,"st:escort","escort",tactics.escort_point(id,flag.carrier),350,true,flag.carrier);return
	if job=="flag_defense":
		ai.candidate(rows,"st:defend","defend",mode.bases[s.team],260,true)
	elif job=="repairer":
		ai.candidate(rows,"st:flag","objective",flag.position,300)
	elif job=="chaser" and ai.objectives.members(id,false).size()>2:
		ai.candidate(rows,"st:chase-watch","defend",mode.bases[s.team]+Vector3(3,0,0),240,true)
	elif job=="siege" and offense.bombard_goal(id,brain,rows):return
	elif job=="siege" and equipment.siege_goal(id,brain,rows):return
	elif job=="siege" and pads and pads.powered(1-s.team):
		var enemy:=generator(1-s.team)
		if not enemy.is_empty():ai.candidate(rows,"st:attack-generator","st_destroy",enemy.position+enemy.frame.basis.z*6,320,true,1-s.team)
	elif job=="capper" and not brain.get("refilling",false) and tactics.push_goal(id,rows):return
	else:ai.candidate(rows,"st:flag","objective",flag.position,300)

func combat(id: int,brain: Dictionary,delta: float) -> bool:
	if offense.designate(id,brain,delta) or offense.disc_jump(id,brain) or offense.bombard(id,brain,delta):return true
	offense.beacon(id,brain)
	if equipment.combat(id,brain,delta):return true
	if construction.build(id,brain):return false
	if brain.goal_kind not in ["st_repair","st_destroy"]:return false
	var game=ai.game;var s: Dictionary=game.players[id];var row:=generator(int(brain.support))
	if row.is_empty():return false
	var point: Vector3=row.frame*Vector3(0,0,1.05)
	var distance: float=ai.eye(id).distance_to(point)
	if ai.alive(brain.enemy) and ai.eye(id).distance_to(ai.target_position(brain.enemy))<8:return false
	var hit: Dictionary=game._trace(ai.eye(id),point-row.frame.basis.z*.3,id)
	if hit.get("generator",-1)!=row.team:return false
	if brain.goal_kind=="st_repair":
		if s.tribes_pack!="repair" or distance>4.8:return false
		s.weapon=8
	else:
		if distance>38:return false
		# Flat direct projectiles work inside the bunker; mortar arcs do not.
		for w in [1,3,2,0]:
			if game.match_mode.tribes.usable(id,w):s.weapon=w;break
	var data: Dictionary=game.match_mode.tribes.Arsenal.table()[s.weapon]
	if data.speed>0:point-=game.fighters[id].velocity*float(data.inherit)*distance/data.speed
	s.fire=ai.aim(id,point,1-exp(-10*delta)) and ai.safe_shot(id,point,data.splash>0)
	return true

func path(start: Vector3,goal: Vector3,id: int=0) -> PackedVector3Array:
	var lane:=0
	if id!=0:lane=tactics.lane(id) if role(id) in ["capper","escort"] else 0
	var avoid: Array=tactics.detours(id) if id!=0 else []
	if id!=0:
		var exit: PackedVector3Array=offense.exit_route(id,start,goal,lane,avoid)
		if not exit.is_empty():return exit
	return routes.path(start,goal,lane,avoid)
static func ground_ski(normal: Vector3,direction: Vector3,velocity: Vector3,walk: float,rise: float=0.0) -> bool:
	var speed:=velocity.length()
	if direction.is_zero_approx() or speed>1 and velocity.normalized().dot(direction)<.65:return false
	var slope:=normal.dot(direction)
	if slope>.035:return true
	if slope<-.035:
		# Keep a fast valley crossing, but release ski before an upslope eats
		# the useful momentum. Walking supplies traction; ski has no thrust.
		var climb:=maxf(rise,-slope/maxf(.2,normal.y)*8)
		return speed>walk*1.3 and (speed*speed-walk*walk)/40>climb+1
	return speed>walk*1.05
func steer(id: int,brain: Dictionary) -> void:
	if ai.game.clock<float(brain.get("disc_launch_until",0)):
		ai.game.players[id].jump=not ai.game.fighters[id].jump_held;ai.game.players[id].ski=true;ai.game.players[id].jet_held=false
		ai.game.players[id].move=movement(id,brain.get("disc_direction",Vector3.ZERO));return
	if not brain.get("staging",false) and tactics.recover(id,brain):return
	# Retain a useful route while advancing. A periodic unconditional rebuild
	# could select a node behind an airborne bot and turn it back every 12 s.
	var position: Vector3=ai.game.fighters[id].position
	var next: Vector3=brain.path[brain.step] if brain.step<brain.path.size() else brain.goal
	var remaining:=position.distance_to(next)
	if brain.get("route_target",Vector3.INF)!=next or remaining<float(brain.get("route_best",INF))-2:
		brain.route_target=next;brain.route_best=remaining;brain.route_at=ai.game.clock+10
	if not brain.get("staging",false) and tower_approach(id,brain):return
	if not brain.get("staging",false) and offense.flag_run(id,brain):return
	# Only covered interiors need the portal controller. Proximity to a flag
	# alone also includes open launch hills and must not force vertical hovering.
	var pads=ai.game.match_mode.tribes.stations()
	var interior_goal: bool=not brain.get("staging",false) and pads and (pads.rows.any(func(row):return row.position.distance_to(brain.goal)<3) or pads.generators.any(func(row):return row.position.distance_to(brain.goal)<12))
	if not ai.navigation.ray(position+Vector3.UP*1.8,position+Vector3.UP*2.8).is_empty() or interior_goal and position.distance_to(brain.goal)<55:
		brain.travel_phase="base_approach";precision_steer(id,brain);return
	var game=ai.game;var s: Dictionary=game.players[id];var actor=game.fighters[id]
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z);var speed:=velocity.length()
	var profile: Dictionary=game.match_mode.tribes.definition(id)
	var grounded: bool=actor.is_supported()
	var target: Vector3=brain.goal
	if brain.step<brain.path.size():
		while brain.step<brain.path.size()-1:
			var waypoint: Vector3=brain.path[brain.step];var offset: Vector3=waypoint-actor.position
			var flat:=Vector3(offset.x,0,offset.z)
			var reached: bool=flat.length()<2.3 and offset.y<2.8
			# Cross a waypoint plane at speed; do not turn back to touch every
			# terrain sample. Interior portals still require vertical clearance.
			if brain.step>0 and Vector2(waypoint.x-brain.path[brain.step-1].x,waypoint.z-brain.path[brain.step-1].z).length()>.01:
				var segment: Vector3=waypoint-brain.path[brain.step-1];segment.y=0
				var along: float=-flat.dot(segment.normalized())
				var sideways: float=flat.slide(segment.normalized()).length()
				reached=reached or along>0 and sideways<3 and offset.y<2.8
			if offset.y < -3 and not ai.navigation.ray(waypoint+Vector3.UP*.3,Vector3(waypoint.x,actor.position.y+.3,waypoint.z)).is_empty():reached=false
			if brain.step>0 and not reached:break
			brain.step+=1
		# Pursue a point ahead on a clear outdoor corridor, smoothing the 16 m
		# sampling grid. Short node-by-node corrections would destroy ski speed.
		for ahead_index in range(brain.step+1,mini(brain.path.size(),brain.step+5)):
			var candidate: Vector3=brain.path[ahead_index]
			if candidate.distance_to(actor.position)>clampf(speed*1.6,24,55):break
			if not routes.clear(actor.position,candidate):break
			brain.step=ahead_index
		target=brain.path[brain.step]
	var offset: Vector3=target-actor.position
	var horizontal:=Vector3(offset.x,0,offset.z);var distance:=horizontal.length();var direct:=horizontal.normalized()
	if grounded and offset.y < -3 and distance<9 and not ai.navigation.ray(target+Vector3.UP*.3,Vector3(target.x,actor.position.y+.3,target.z)).is_empty():
		var recovery:=routes.path(actor.position,brain.goal,0,tactics.detours(id))
		if not recovery.is_empty():brain.path=recovery;brain.step=0;brain.route_at=game.clock+12;return
	var ceiling: bool=not ai.navigation.ray(actor.position+Vector3.UP*1.8,actor.position+Vector3.UP*2.8).is_empty()
	var obstacle: bool=not ai.navigation.ray(actor.position+Vector3.UP,actor.position+Vector3.UP+direct*2).is_empty()
	var final: bool=brain.step>=brain.path.size()-1
	var brake_distance: float=maxf(12,speed*speed/(profile.thrust)+3)
	var precision: bool=ceiling or final and distance<brake_distance or offset.y>3 and offset.y>distance*.6
	var energy: float=actor.tribes_state.energy
	var desired: Vector3
	s.jump=false;s.jet_held=false;s.ski=false
	if precision or obstacle and speed<profile.walk*.5:
		# Doorways, station pads and recovery from a stopped cliff approach.
		desired=(horizontal*.65-velocity*.7).limit_length(1)
		if grounded and energy<profile.energy*.85 and (offset.y>3 or brain.get("jet_recharge",false)):brain.jet_recharge=true
		if energy>=profile.energy*.94:brain.jet_recharge=false
		if energy<2:brain.jet_recharge=true
		if grounded:
			s.jet_held=(offset.y>1 or obstacle) and not ceiling and not brain.get("jet_recharge",false)
			s.jump=s.jet_held and not actor.jump_held
		else:
			# Turning the stick alone provides no air steering in Tribes. Burn
			# directional jets to brake before overshooting a small landing pad.
			var braking: bool=final and offset.y<2 and speed>3 and (distance<.01 or velocity.dot(direct)>maxf(2,distance*.7) or velocity.slide(direct).length()>3)
			desired*=.75 if braking else .28
			s.jet_held=not ceiling and not brain.get("jet_recharge",false) and (braking or offset.y+1-actor.velocity.y*.35>0)
		if offset.y>3:desired=(direct*.2-velocity*.035).limit_length(.22)
		brain.travel_phase="precision"
	else:
		# Follow the corridor continuously, looking ahead to the next upslope.
		# A downhill run is useful from rest: gravity supplies acceleration
		# while jets recharge, and skiing preserves it across the valley floor.
		var normal: Vector3=actor.tribes_state.normal
		var aligned: bool=speed<1 or velocity.normalized().dot(direct)>.65
		var look_distance:=clampf(speed*.8,7,24)
		var probe: Vector3=actor.position+direct*look_distance
		var floor_hit: Dictionary=ai.navigation.ray(probe+Vector3.UP*24,probe-Vector3.UP*48)
		var rise:=offset.y;var ahead:=distance
		if not floor_hit.is_empty():rise=floor_hit.position.y-actor.position.y;ahead=look_distance
		var eta:=clampf(ahead/maxf(speed,profile.walk),.25,1.25)
		var ballistic_height: float=actor.velocity.y*eta-10*eta*eta
		var climb: bool=rise>1 or obstacle
		var launch: bool=climb and rise>ballistic_height+.7 and (speed>profile.walk*.75 or obstacle)
		# Steer towards a velocity corridor, retaining forward momentum. At
		# speed, forward thrust already points mostly up in the shared physics.
		desired=(direct*maxf(profile.walk*1.15,speed)-velocity)*.12
		if grounded:
			desired=direct
			s.ski=ground_ski(normal,direct,velocity,profile.walk,rise)
			s.jet_held=launch and not ceiling and energy>3
			s.jump=s.jet_held and not actor.jump_held
			brain.travel_phase="ski" if s.ski else "run_up"
		else:
			desired=desired.limit_length(.3 if climb else .65)
			# Coast downhill; burn only when the predicted arc falls below the
			# coming terrain. No horizontal braking simply because a node is high.
			s.ski=aligned
			s.jet_held=not ceiling and energy>3 and climb and rise+1>ballistic_height
			brain.travel_phase="climb" if s.jet_held else "coast"
		if s.jet_held and grounded:desired=desired.limit_length(.3)
	if offset.length()<ai.stop_radius(brain):desired=-velocity.limit_length(1);s.ski=false;s.jet_held=false;s.jump=false;brain.travel_phase="arrive"
	if brain.enemy==0 and brain.goal_kind not in ["st_repair","st_destroy"] and ai.game.clock>=float(brain.get("equipment_aim_until",0)) and horizontal.length()>.5:ai.aim(id,target+Vector3.UP,.08)
	s.move=movement(id,desired)
	s.prone=false;s.crouch=false;s.swim=Vector3.ZERO

func precision_steer(id: int,brain: Dictionary) -> void:
	var game=ai.game;var s: Dictionary=game.players[id];var actor=game.fighters[id]
	var target: Vector3=brain.goal
	if brain.step<brain.path.size():
		while brain.step<brain.path.size()-1:
			var offset: Vector3=brain.path[brain.step]-actor.position
			if brain.step>0 and (Vector2(offset.x,offset.z).length()>2.3 or absf(offset.y)>2.8):break
			brain.step+=1
		target=brain.path[brain.step]
	var offset: Vector3=target-actor.position
	var horizontal:=Vector3(offset.x,0,offset.z);var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
	var distance:=horizontal.length();var direct:=horizontal.normalized();var grounded: bool=actor.is_supported()
	if grounded and offset.y < -3 and distance<5 and not ai.navigation.ray(target+Vector3.UP*.3,Vector3(target.x,actor.position.y+.3,target.z)).is_empty():
		# A missed doorway can land a jetting bot on the roof above its indoor
		# waypoint. Rejoin through an outside portal instead of pressing down.
		var recovery:=routes.path(actor.position,brain.goal,0,tactics.detours(id))
		if not recovery.is_empty():brain.path=recovery;brain.step=0;brain.route_at=game.clock+12;return
	var obstacle: bool=not ai.navigation.ray(actor.position+Vector3.UP,actor.position+Vector3.UP+direct*2).is_empty()
	var ceiling: bool=not ai.navigation.ray(actor.position+Vector3.UP*1.8,actor.position+Vector3.UP*2.8).is_empty()
	var energy: float=actor.tribes_state.energy;var capacity: float=game.match_mode.tribes.definition(id).energy
	if grounded and energy<capacity*.85 and (offset.y>3 or brain.get("jet_recharge",false)):brain.jet_recharge=true
	if energy>=capacity*.94:brain.jet_recharge=false
	if energy<2:brain.jet_recharge=true
	var desired: Vector3=(horizontal*.65-velocity*.7).limit_length(1)
	var rise: bool=offset.y>1.0 or obstacle
	if grounded:
		s.jet_held=rise and not ceiling and not brain.get("jet_recharge",false)
		s.jump=s.jet_held and not actor.jump_held
		if rise and offset.y>3:desired=-velocity.limit_length(1)
	else:
		# Sustained partial directional input preserves vertical lift. Full
		# strafing thrust spends most lift and caused the old cliff oscillation.
		desired=desired*.28
		if offset.y>3:desired=(-velocity*.3).limit_length(.12)
		s.jet_held=not ceiling and not brain.get("jet_recharge",false) and offset.y+1-actor.velocity.y*.35>0
		s.jump=false
	s.ski=velocity.length()>8 and offset.y<.6 and not obstacle and distance>7 and ground_ski(actor.tribes_state.normal,direct,velocity,game.match_mode.tribes.definition(id).walk,offset.y)
	if offset.length()<ai.stop_radius(brain):desired=-velocity.limit_length(1);s.ski=false;s.jet_held=false
	# Navigation-facing while idle makes distant approaches enter perception.
	if brain.enemy==0 and brain.goal_kind not in ["st_repair","st_destroy"] and ai.game.clock>=float(brain.get("equipment_aim_until",0)) and horizontal.length()>.5:ai.aim(id,target+Vector3.UP, .08)
	s.move=movement(id,desired)
	s.prone=false;s.crouch=false;s.swim=Vector3.ZERO

func tower_approach(id: int,brain: Dictionary) -> bool:
	var game=ai.game;var actor=game.fighters[id];var s: Dictionary=game.players[id]
	var goal: Vector3=brain.goal
	var tower: bool=game.match_mode.bases.any(func(base):return Vector2(base.x-goal.x,base.z-goal.z).length()<9 and absf(base.y-goal.y)<1)
	# Land in the clear centre before walking to a construction point beside
	# the flag. A side target can put the launch line through the deck support.
	if tower and brain.goal_kind=="st_build":
		for base in game.match_mode.bases:
			if base.distance_to(goal)<9:goal=base;break
	var fixtures=game.match_mode.tribes.stations()
	if fixtures and brain.goal_kind=="st_fixed_repair":tower=fixtures.defences.rows.any(func(row):return row.position.distance_to(goal)<6)
	if not tower or actor.position.distance_to(goal)>(240 if brain.goal_kind=="st_fixed_repair" else 100):brain.erase("tower");return false
	var flat:=Vector3(goal.x-actor.position.x,0,goal.z-actor.position.z)
	var on_deck: bool=flat.length()<20 and absf(actor.position.y-goal.y)<1.8 and ai.navigation.ray(actor.position+Vector3.UP*.8,goal+Vector3.UP*.8).is_empty()
	if actor.position.distance_to(goal)<1.4 or flat.length()<3 and absf(actor.position.y-goal.y)<2 or on_deck:
		brain.erase("tower");brain.path=PackedVector3Array([brain.goal]);brain.step=0;brain.route_at=game.clock+12;return false
	if brain.get("stage_goal",Vector3.INF).distance_to(goal)>1:brain.failed_stages=[];brain.stage_goal=goal
	if not brain.has("tower") or brain.tower.goal.distance_to(goal)>1:
		var away: Vector3=(actor.position-goal);away.y=0;away=away.normalized()
		if away.length()<.1:away=Vector3.RIGHT
		var stage:=Vector3.INF;var best:=INF
		var pads=game.match_mode.tribes.stations()
		for radius in ([48,72,104,144,184] if brain.goal_kind=="st_fixed_repair" else [48,72] if s.tribes_class=="heavy" else [48]):
			for i in 24:
				var direction: Vector3=away.rotated(Vector3.UP,TAU*i/24)
				var point: Vector3=goal+direction*radius
				# Heavy armour needs a higher launch hill and more run-up. Its
				# small thrust surplus cannot rescue a low, slow tower approach.
				if pads.generators.any(func(row):return Vector2(point.x-row.position.x,point.z-row.position.z).length()<34):continue
				var hit: Dictionary=ai.navigation.ray(point+Vector3.UP*50,point-Vector3.UP*90)
				if hit.is_empty() or hit.normal.y<.7 or goal.y-hit.position.y>33:continue
				if s.tribes_class!="heavy" and goal.y-hit.position.y<4:continue
				var cost: float=actor.position.distance_to(hit.position)+maxf(0,goal.y-hit.position.y)*(2 if s.tribes_class=="heavy" else 0)
				cost+=tactics.stage_cost(id,goal,hit.position)
				if brain.get("failed_stages",[]).any(func(old):return old.distance_to(hit.position)<18):continue
				if cost<best:best=cost;stage=hit.position+Vector3.UP*.06
		if not stage.is_finite():brain.failed_stages=[];return false
		var route:=routes.path(actor.position,stage,0,tactics.detours(id))
		if route.is_empty():return false
		brain.tower={"goal":goal,"stage":stage,"phase":"stage","at":game.clock,"path":route,"step":0}
	var run: Dictionary=brain.tower;var profile: Dictionary=game.match_mode.tribes.definition(id)
	if run.phase=="stage":
		if not run.has("controller"):
			run.controller=brain.duplicate();run.controller.erase("tower");run.controller.staging=true
		var navigation: Dictionary=run.controller
		navigation.enemy=brain.enemy;navigation.equipment_aim_until=brain.get("equipment_aim_until",0)
		navigation.goal=run.stage;navigation.goal_kind="supply";navigation.path=run.path;navigation.step=run.step
		if game.clock>navigation.route_at and actor.position.distance_to(run.stage)>3:
			var recovery:=routes.path(actor.position,run.stage,0,tactics.detours(id))
			if not recovery.is_empty():navigation.path=recovery;navigation.step=0;navigation.route_at=game.clock+10
		steer(id,navigation);run.path=navigation.path;run.step=navigation.step;brain.travel_phase="tower_runup"
		if game.clock-run.at>(70 if s.tribes_class=="heavy" else 45):
			tactics.reject_stage(id,goal,run.stage)
			if not brain.has("failed_stages"):brain.failed_stages=[]
			brain.failed_stages.append(run.stage);brain.erase("tower");return true
		if actor.position.distance_to(run.stage)<3:
			if actor.tribes_state.energy<profile.energy*.9 or not actor.is_supported():s.move=Vector2.ZERO;s.jet_held=false;s.jump=false;s.ski=false
			else:run.phase="run";run.at=game.clock
		return true
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z);var speed:=velocity.length();var direction:=flat.normalized()
	var desired: Vector3=direction;s.jet_held=false;s.jump=false;s.ski=false
	if run.phase=="run":
		s.ski=velocity.dot(direction)>profile.walk*1.1 and ground_ski(actor.tribes_state.normal,direction,velocity,profile.walk)
		if flat.length()<48 and velocity.dot(direction)>profile.walk*.75 and velocity.slide(direction).length()<profile.walk*.3 or not actor.is_supported():
			run.phase="flight";run.at=game.clock;s.jump=actor.tribes_state.airtime<.25 and not actor.jump_held
		brain.travel_phase="tower_runup"
	if run.phase=="flight":
		var eta:=clampf(maxf(1,flat.length()-11)/maxf(speed,2),.1,6.0 if s.tribes_class!="light" else 3.0)
		var projected: float=actor.position.y+actor.velocity.y*eta-10*eta*eta
		# Loft while still far away, then descend into the covered flag deck.
		# A fixed +3 m height cap cut thrust tens of metres before the tower,
		# so even launches from high hills fell underneath the deck on arrival.
		var ceiling_height: float=goal.y+clampf(flat.length()*.4,3,20)
		s.jet_held=projected<goal.y+.7 and (s.tribes_class!="light" or actor.position.y<ceiling_height) and actor.tribes_state.energy>3
		desired=((direction*maxf(speed,profile.walk)-velocity)*.09+direction*.08).limit_length(.22)
		s.ski=true;brain.travel_phase="tower_flight"
		if game.clock-run.at>1 and actor.is_supported() and actor.position.y<goal.y-2 or game.clock-run.at>12:
			tactics.reject_stage(id,goal,run.stage)
			if not brain.has("failed_stages"):brain.failed_stages=[]
			brain.failed_stages.append(run.stage);brain.erase("tower");s.jet_held=false;s.jump=false
	elif game.clock-run.at>8:brain.erase("tower")
	if brain.enemy==0 and game.clock>=float(brain.get("equipment_aim_until",0)):ai.aim(id,goal+Vector3.UP,.08)
	s.move=movement(id,desired);s.prone=false;s.crouch=false;s.swim=Vector3.ZERO
	return true
func movement(id: int,desired: Vector3) -> Vector2:
	var game=ai.game;var actor=game.fighters[id]
	# Share narrow launch hills without steering airborne or fast skiers out
	# of their momentum corridor. Check world clearance before sidestepping.
	if actor.is_supported() and actor.velocity.length()<12 and desired.length()>.1:
		for friend in ai.brains:
			if friend==id or not ai.alive(friend) or not game.match_mode.same_team(id,friend):continue
			var offset: Vector3=game.fighters[friend].position-actor.position
			if absf(offset.y)>1.5:continue
			offset.y=0
			if offset.length()>2 or offset.dot(desired)<0:continue
			var side: Vector3=desired.normalized().cross(Vector3.UP)*(1 if id<friend else -1)
			if ai.navigation.ray(actor.position+Vector3.UP,actor.position+Vector3.UP+side*1.2).is_empty():desired=(desired+side*.6).limit_length(1)
	var local:=Basis(Vector3.UP,-game.players[id].yaw)*desired
	return Vector2(local.x,local.z)
