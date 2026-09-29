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
var avoidance=preload("res://deathmatch/bot_ai/tribes_avoidance.gd").new()
var travel=preload("res://deathmatch/bot_ai/tribes_travel.gd").new()
var capture=preload("res://deathmatch/bot_ai/tribes_capture.gd").new()
func setup(value):ai_ref=weakref(value);routes.ai=value;equipment.ai=value;tactics.ai=value;offense.ai=value;construction.ai=value;avoidance.ai=value;travel.ai=value;capture.ai=value

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
		# Optional construction/siege should not reclaim an attacker in the
		# middle of a fast descent. Base outages still request urgent repairs.
		if job in ["repairer","siege"] and assignments.get(id,"") in ["capper","escort","chaser"] and momentum(id) and not (job=="repairer" and equipment.essential_damage(s.team)):
			value+=25
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
	# With both flags away, spare attackers used to target the enemy flag's
	# position on their own carrier, accidentally becoming extra escorts.
	# Keep one protector; commit the rest to recovering the home flag.
	if ai.alive(enemy.carrier) and (own.dropped or ai.alive(own.carrier)):
		if pool.size()>=3:allocate(pool,game.fighters[enemy.carrier].position,"escort",result)
		if pool.size()>=4 and pads and not pads.powered(team):
			var repair_pool: Array=pool.filter(func(id):return equipment.service(team) or game.players[id].tribes_pack in ["none","repair"])
			if not repair_pool.is_empty():pool.erase(allocate(repair_pool,generator(team).position,"repairer",result))
		var point: Vector3=game.fighters[own.carrier].position if ai.alive(own.carrier) else own.position
		while not pool.is_empty():allocate(pool,point,"chaser",result)
		for id in group:
			if assignments.get(id,"")!=result[id] and ai.brains.has(id):ai.brains[id].plan_at=0
			assignments[id]=result[id]
		return
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
	# One nearby attacker clears the observed flag defender while the lead
	# runner completes the grab. Waiting until pickup to create escorts left
	# every approach unsupported during its most exposed few seconds.
	if pool.size()>=2 and own.carrier==0 and not own.dropped and enemy.carrier==0 and not enemy.dropped:
		var lead:=0;var nearest:=110.0
		for id in pool:
			if assignments.get(id,"")=="escort":continue
			var distance: float=game.fighters[id].position.distance_to(enemy.position)
			if distance<nearest:nearest=distance;lead=id
		if lead!=0:
			var defended: bool=ai.brains.get(lead,{}).get("visible",[]).any(func(id):return ai.alive(id) and game.fighters[id].position.distance_to(enemy.position)<55)
			if defended:
				var helpers: Array=pool.filter(func(id):return id!=lead and game.fighters[id].position.distance_to(game.fighters[lead].position)<90)
				if not helpers.is_empty():pool.erase(allocate(helpers,enemy.position,"escort",result))
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
	brain.capture_preparing=false
	if s.hp<rules.definition(id).hp*.7:rules.kit(id)
	# The carrier stays on the return job even with depleted ammo or low HP.
	if flag.carrier==id:
		offense.recharge_escape(id,brain)
		offense.pass_flag(id,brain)
		tactics.carrier_goal(id,brain,rows)
		return
	if offense.catch_goal(id,rows):return
	if job=="chaser":
		if own.dropped:ai.candidate(rows,"st:return","objective",own.position,560);return
		if ai.alive(own.carrier):ai.candidate(rows,"st:intercept","intercept",tactics.intercept_point(id,own.carrier),550);return
	if rules.commander.bot_goal(id,ai,rows):return
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
	# A roof spawn must first move away from the pad to enter the bunker.
	# Keep that initial refit trip for a bounded interval after leaving the
	# proximity radius, instead of abandoning it at the first doorway detour.
	var refit_committed: bool=s.tribes_pack=="none" and game.clock<float(brain.get("st_refit_until",0))
	var refit_needed: bool=offense.prepare(id,brain) or refit_committed or job!="capper" and s.tribes_pack=="none" and near_inventory or rules.can_refit(id) or job=="repairer" and (building or s.tribes_pack!="repair" and equipment.damaged(s.team))
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
		if best>=0:
			if purchase and s.tribes_pack=="none" and not brain.has("st_refit_until"):brain.st_refit_until=game.clock+45
			ai.candidate(rows,"tribes:inventory:%d"%best,"supply",pads.rows[best].position,500 if purchase else 320,true)
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
	if ai.alive(flag.carrier):
		if job=="escort":
			ai.candidate(rows,"st:escort","escort",tactics.escort_point(id,flag.carrier),350,true,flag.carrier);return
		# The friendly carrier already has that flag. Remaining support keeps
		# its useful goals or covers home instead of trying to pick it up again.
		if rows.is_empty():ai.candidate(rows,"st:defend","defend",mode.bases[s.team],260,true)
		return
	if job=="flag_defense":
		ai.candidate(rows,"st:defend","defend",mode.bases[s.team],260,true)
	elif job=="repairer":
		capture.goal(id,brain,rows)
	elif job=="chaser" and ai.objectives.members(id,false).size()>2:
		ai.candidate(rows,"st:chase-watch","defend",mode.bases[s.team]+Vector3(3,0,0),240,true)
	elif job=="escort" and offense.screen_goal(id,brain,rows):return
	elif job=="siege" and offense.bombard_goal(id,brain,rows):return
	elif job=="siege" and equipment.siege_goal(id,brain,rows):return
	elif job=="siege" and pads and pads.powered(1-s.team):
		var enemy:=generator(1-s.team)
		if not enemy.is_empty():ai.candidate(rows,"st:attack-generator","st_destroy",enemy.position+enemy.frame.basis.z*6,320,true,1-s.team)
	elif job=="capper" and not brain.get("refilling",false) and tactics.push_goal(id,rows):return
	else:capture.goal(id,brain,rows)

func combat(id: int,brain: Dictionary,delta: float) -> bool:
	brain.travel_focus=false;brain.travel_defending=false
	if carrier(id) or brain.get("capture_preparing",false) and brain.goal_key=="st:flag" or momentum(id) and brain.goal_kind not in ["st_repair","st_asset_repair","st_deploy_repair","st_fixed_repair"]:
		brain.travel_focus=true
		brain.equipment_target=-1;brain.equipment_aim_until=0.0
		if offense.disc_jump(id,brain):return true
		brain.travel_defending=offense.travel_defence(id,brain)
		return not brain.travel_defending
	if offense.screen_enemy(id,brain):return false
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
		if carrier(id):return travel.path(id,start,goal,avoid)

	return routes.path(start,goal,lane,avoid)
static func ground_ski(normal: Vector3,direction: Vector3,velocity: Vector3,walk: float,_rise: float=0.0) -> bool:
	var speed:=velocity.length()
	# Slope preference only; slope_inputs applies route/collision safety after
	# every controller, so this cannot override a deliberate braking decision.
	if normal.dot(direction)>.035:return true
	if normal.dot(direction)<-.035:return false
	if direction.is_zero_approx() or speed>1 and velocity.normalized().dot(direction)<.65:return false
	return speed>walk*1.05
static func jet_wish(velocity: Vector3,direction: Vector3,profile: Dictionary,upward_thrust: float) -> Vector3:
	# Aim for the armour's ordinary horizontal jet range, not its present
	# speed. The old velocity error approached zero at walking speed, leaving
	# almost all thrust vertical even when the route had room to accelerate.
	var horizontal:=Vector3(velocity.x,0,velocity.z)
	var wish: Vector3=(direction*maxf(profile.side_speed*.95,horizontal.length())-horizontal)*.12
	if wish.is_zero_approx():return wish
	# The shared physics trades lift for horizontal thrust. Limit stick travel
	# by the lift needed for the approaching terrain; no extra force is added.
	var share:=clampf(1-horizontal.dot(wish.normalized())/profile.side_speed,0,.8)
	var available:=clampf(1-upward_thrust/profile.thrust,0,.8)
	return wish.limit_length(minf(1,available/share) if share>.001 else 1)
func steer(id: int,brain: Dictionary) -> void:
	steer_route(id,brain)
	avoidance.steer(id,brain)
	slope_inputs(id,brain)
func slope_inputs(id: int,brain: Dictionary) -> void:
	var game=ai.game;var actor=game.fighters[id];var s: Dictionary=game.players[id]
	if not actor.is_supported():return
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
	var desired:=Basis(Vector3.UP,s.yaw)*Vector3(s.move.x,0,s.move.y)
	var travel:=desired.normalized()
	var slope: float=actor.tribes_state.normal.dot(travel)
	if slope>.035:s.ski=avoidance.ski_clear(id,brain,desired)
	elif slope<-.035:
		var profile: Dictionary=game.match_mode.tribes.definition(id)
		# Spend a real jump/jet input before walking can clamp a fast upslope
		# entry. Low reserves use traction instead of skiing to a standstill.
		if brain.get("travel_phase","") in ["run_up","ski"] and not brain.get("staging",false) and velocity.length()>profile.walk*1.1 and desired.dot(velocity.normalized())>.4 and actor.position.distance_to(brain.goal)>12 and actor.tribes_state.energy>profile.energy*.25 and ai.navigation.ray(actor.position+Vector3.UP*1.8,actor.position+Vector3.UP*2.8).is_empty():
			s.jet_held=true;s.jump=not actor.jump_held
			# This late slope-triggered launch previously kept the full walking
			# stick input. At modest speed that diverts so much thrust sideways
			# that it cannot oppose gravity. Reserve lift as airborne steering does.
			s.move=movement(id,jet_wish(actor.velocity,travel,profile,maxf(20.5,profile.thrust*.85)))
		s.ski=false
	elif s.ski and not avoidance.ski_clear(id,brain,desired):s.ski=false
func momentum(id: int) -> bool:
	var actor=ai.game.fighters[id]
	return Vector2(actor.velocity.x,actor.velocity.z).length()>ai.game.match_mode.tribes.definition(id).walk*1.3
func steer_route(id: int,brain: Dictionary) -> void:
	var recharging: bool=offense.recharge_escape(id,brain)
	if offense.catch_steer(id,brain):return
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
	# A tall bunker roof can be many metres above the head. Check the full
	# climb to the destination before handing control to a tower launch; the
	# old one-metre headroom probe noticed it only after reaching the ceiling.
	if brain.goal.y>position.y+3:
		var cover: Dictionary=ai.navigation.ray(position+Vector3.UP*1.7,Vector3(position.x,brain.goal.y+1.7,position.z))
		if not cover.is_empty() and cover.normal.y<-.5:
			if brain.has("tower") and brain.tower.phase in ["run","flight"]:
				tactics.reject_stage(id,brain.goal,brain.tower.stage)
				if not brain.has("failed_stages"):brain.failed_stages=[]
				brain.failed_stages.append(brain.tower.stage)
			brain.erase("tower");brain.travel_phase="base_approach";precision_steer(id,brain);return
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
	if reroute_after_fall(id,brain):return
	if reroute_below_deck(id,brain):return
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
				# A fast skier can pass a sparse terrain sample several metres
				# to its side. Requiring a 3 m touch caused a brake/U-turn even
				# with a clear onward corridor. Keep precise indoor portals below.
				var corridor:=clampf(speed*.75,3,18)
				reached=reached or along>0 and sideways<corridor and routes.clear(actor.position,brain.path[brain.step+1])
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
	var obstacle: bool=not avoidance.wall(actor.position,actor.position+direct*2).is_empty()
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
		if offset.y>3:
			desired=(direct*.2-velocity*.035).limit_length(.22)
			# Recharging does not require crawling up a clear walkable slope.
			if grounded and not s.jet_held and actor.tribes_state.normal.y>.65 and actor.tribes_state.normal.dot(direct)<-.035:desired=direct
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
			# Starting a useful flight needs more than one tick's fuel. Keep
			# gravity/traction and recharge instead of repeated empty-pack hops.
			s.jet_held=launch and not ceiling and energy>profile.energy*.25
			s.jump=s.jet_held and not actor.jump_held
			brain.travel_phase="ski" if s.ski else "run_up"
		else:
			var lift: float=20+2*(rise+.8-actor.velocity.y*eta)/(eta*eta)
			desired=jet_wish(actor.velocity,direct,profile,lift) if aligned else desired.limit_length(.3 if climb else .65)
			# Reserve lift for the coming terrain, or use surplus energy to
			# accelerate through a clear descent. Never brake just for a high node.
			s.ski=true # Keep ski held through landing; grounded steering decides when to walk.
			# Airborne stick input has no force without jets. A descending
			# carrier changing corridor must burn to turn; otherwise it keeps
			# its old heading and can hit the bunker beside a clear exit route.
			var turn: bool=speed>3 and (velocity.dot(direct)<speed*.7 or velocity.slide(direct).length()*minf(distance/maxf(speed,profile.walk),2)>6)
			var accelerate: bool=not recharging and aligned and velocity.dot(direct)<profile.side_speed*.85 and energy>profile.energy*.45 and rise< -2
			s.jet_held=not ceiling and energy>3 and (climb and rise+1>ballistic_height or turn or accelerate)
			brain.travel_phase="climb" if s.jet_held else "coast"
		if s.jet_held and grounded:desired=desired.limit_length(.3)
	if final and actor.position.distance_to(brain.goal)<ai.stop_radius(brain):desired=-velocity.limit_length(1);s.ski=false;s.jet_held=false;s.jump=false;brain.travel_phase="arrive"
	if route_look(id,brain) and brain.goal_kind not in ["st_repair","st_destroy"] and ai.game.clock>=float(brain.get("equipment_aim_until",0)) and horizontal.length()>.5:offense.travel_look(id,brain,target+Vector3.UP)
	s.move=movement(id,desired)
	s.prone=false;s.crouch=false;s.swim=Vector3.ZERO

func precision_steer(id: int,brain: Dictionary) -> void:
	var game=ai.game;var s: Dictionary=game.players[id];var actor=game.fighters[id]
	if reroute_below_deck(id,brain):return
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
	var obstacle: bool=not avoidance.wall(actor.position,actor.position+direct*2).is_empty()
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
		if rise and offset.y>3 and s.jet_held:desired=-velocity.limit_length(1)
		elif rise and not s.jet_held and actor.tribes_state.normal.y>.65 and actor.tribes_state.normal.dot(direct)<-.035:desired=direct
	else:
		# Sustained partial directional input preserves vertical lift. Full
		# strafing thrust spends most lift and caused the old cliff oscillation.
		desired=desired*.28
		if offset.y>3:desired=(-velocity*.3).limit_length(.12)
		s.jet_held=not ceiling and not brain.get("jet_recharge",false) and offset.y+1-actor.velocity.y*.35>0
		s.jump=false
	s.ski=velocity.length()>8 and offset.y<.6 and not obstacle and distance>7 and ground_ski(actor.tribes_state.normal,direct,velocity,game.match_mode.tribes.definition(id).walk,offset.y)
	if brain.step>=brain.path.size()-1 and actor.position.distance_to(brain.goal)<ai.stop_radius(brain):desired=-velocity.limit_length(1);s.ski=false;s.jet_held=false
	# Navigation-facing while idle makes distant approaches enter perception.
	if route_look(id,brain) and brain.goal_kind not in ["st_repair","st_destroy"] and ai.game.clock>=float(brain.get("equipment_aim_until",0)) and horizontal.length()>.5:offense.travel_look(id,brain,target+Vector3.UP)
	s.move=movement(id,desired)
	s.prone=false;s.crouch=false;s.swim=Vector3.ZERO

func reroute_after_fall(id: int,brain: Dictionary) -> bool:
	if brain.step<1 or brain.step>=brain.path.size():return false
	var game=ai.game;var actor=game.fighters[id]
	if not actor.is_supported() or game.clock<float(brain.get("fall_replan_at",0)):return false
	var point: Vector3=brain.path[brain.step]
	# A missed elevated corridor is no longer the route we planned. Rejoin
	# from the actual landing instead of recharging below the same roof edge.
	if point.y-actor.position.y<14 or brain.path[brain.step-1].y-actor.position.y<14:return false
	brain.fall_replan_at=game.clock+4
	var avoid: Array=tactics.detours(id).duplicate();avoid.append({"point":point,"until":game.clock+20})
	var path:=routes.path(actor.position,brain.goal,0,avoid)
	if path.is_empty():return false
	brain.path=path;brain.step=0;brain.route_at=game.clock+12;brain.jet_recharge=false
	game.players[id].jet_held=false;game.players[id].jump=false
	tactics.count("fallen_corridor_replans");return true

func reroute_below_deck(id: int,brain: Dictionary) -> bool:
	if brain.step>=brain.path.size():return false
	var game=ai.game;var actor=game.fighters[id];var point: Vector3=brain.path[brain.step]
	if point.y-actor.position.y<3 or Vector2(point.x-actor.position.x,point.z-actor.position.z).length()>9 or game.clock<float(brain.get("underpass_at",0)):return false
	var hit: Dictionary=ai.navigation.ray(actor.position+Vector3.UP*1.7,Vector3(actor.position.x,point.y+1.7,actor.position.z))
	if hit.is_empty() or hit.normal.y>-.5:return false
	brain.underpass_at=game.clock+2
	var avoid: Array=tactics.detours(id).duplicate();avoid.append({"point":point,"until":game.clock+20})
	var path:=routes.path(actor.position,brain.goal,0,avoid)
	if path.is_empty():return false
	brain.path=path;brain.step=0;brain.route_at=game.clock+12
	game.players[id].jet_held=false;game.players[id].jump=false
	tactics.count("underpass_replans");return true

static func rolling_height(height: float,vertical: float,goal: float,seconds: float,energy: float,profile: Dictionary,pack: String) -> float:
	# Predict the existing pulsed shelf controller using the real remaining
	# reserve and recharge. Requiring enough fuel for a continuous full burn
	# rejected useful ski approaches that need only a short lift and coast.
	var recharge:=11.0 if pack=="energy" else 8.0
	var remaining:=seconds
	while remaining>0:
		var dt:=minf(1.0/60,remaining);remaining-=dt
		var held: bool=vertical<clampf((goal+.55-height)*1.5,-4,10) and energy>3
		energy=clampf(energy+(recharge-(profile.drain if held else 0))*dt,0,profile.energy)
		vertical+=((profile.thrust*.9 if held else 0)-20)*dt
		height+=vertical*dt
	return height

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
	if not tower or actor.position.distance_to(goal)>(240 if brain.goal_kind=="st_fixed_repair" else 160 if brain.has("tower") else 100):brain.erase("tower");return false
	var flat:=Vector3(goal.x-actor.position.x,0,goal.z-actor.position.z)
	# Matching the shelf's height in mid-air is not a landing. Keep the
	# flight controller until supported; otherwise the next falling frame
	# discards the approach and sends the capper back to a launch hill.
	var on_deck: bool=actor.is_supported() and flat.length()<16 and actor.position.y>=goal.y-.15 and actor.position.y<goal.y+1.8 and ai.navigation.ray(actor.position+Vector3.UP*.2,goal+Vector3.UP*.2).is_empty()
	if actor.position.distance_to(goal)<1.0 or on_deck:
		brain.erase("tower");brain.path=PackedVector3Array([brain.goal]);brain.step=0;brain.route_at=game.clock+12;return false
	if brain.get("stage_goal",Vector3.INF).distance_to(goal)>1:brain.failed_stages=[];brain.stage_goal=goal
	if not brain.has("tower") or brain.tower.goal.distance_to(goal)>1 or brain.tower.phase=="stage":
		var incoming:=Vector3(actor.velocity.x,0,actor.velocity.z)
		var profile: Dictionary=game.match_mode.tribes.definition(id)
		var direction:=flat.normalized();var eta: float=flat.length()/maxf(1,incoming.dot(direction))
		var homeward: Vector3=game.match_mode.bases[s.team]-goal;homeward.y=0
		# A fast grab straight away from home demands a full reversal beside
		# the defender. Keep lateral/homeward fly-throughs; otherwise use the
		# approach hill that already accounts for the intended exit direction.
		var through_run: bool=brain.goal_key!="st:flag" or incoming.normalized().dot(homeward.normalized())>-.25
		var jump: float=profile.jump if actor.is_supported() else 0.0
		# We start considering a tower at 100 m. Committing to a stopping
		# stage there made the <75 m rolling-launch test unreachable. Keep an
		# aligned fast approach until the launch window, and reconsider while
		# travelling to a stage instead of unconditionally stopping at it.
		if through_run and flat.length()>=75 and incoming.dot(direction)>profile.walk*1.1 and incoming.slide(direction).length()<incoming.length()*.25:
			if ai.navigation.ray(goal-direction*18+Vector3.UP*.8,goal+Vector3.UP*.8).is_empty():
				brain.erase("tower");return false
		# A capper already carrying enough speed and energy should keep its
		# approach, rather than brake at an arbitrary 48-metre refuelling point.
		# Keep lateral correction within roughly one second at 15% thrust.
		# Larger turns spend the lift assumed by the moving-height forecast;
		# retain the established staged approach for those entries.
		if through_run and flat.length()>24 and flat.length()<75 and incoming.dot(direction)>profile.walk*1.1 and incoming.slide(direction).length()<minf(incoming.length()*.25,profile.thrust*.15) and eta<3 and actor.tribes_state.energy>profile.energy*.25 and rolling_height(actor.position.y,actor.velocity.y+jump,goal.y,eta,actor.tribes_state.energy,profile,s.tribes_pack)>goal.y+.2 and capture.launch_allowed(id,brain,true):
			if ai.navigation.ray(goal-direction*18+Vector3.UP*.8,goal+Vector3.UP*.8).is_empty() and ai.navigation.ray(actor.position+Vector3.UP*1.7,actor.position+direction*10+Vector3.UP*1.7).is_empty():
				brain.tower={"goal":goal,"stage":actor.position,"phase":"flight","at":game.clock,"path":PackedVector3Array(),"step":0,"launch":jump>0}
				tactics.count("rolling_launches")
	if not brain.has("tower") or brain.tower.goal.distance_to(goal)>1:
		var away: Vector3=(actor.position-goal);away.y=0;away=away.normalized()
		if away.length()<.1:away=Vector3.RIGHT
		var stage:=Vector3.INF;var best:=INF
		var pads=game.match_mode.tribes.stations()
		var fast_grab: bool=brain.goal_key=="st:flag" and s.tribes_class=="light"
		for radius in ([48,72,104,144,184] if brain.goal_kind=="st_fixed_repair" else [48,72,104] if fast_grab else [48,72] if s.tribes_class=="heavy" else [48]):
			for i in 24:
				var direction: Vector3=away.rotated(Vector3.UP,TAU*i/24)
				var point: Vector3=goal+direction*radius
				# Covered shelves are not open on every side. Reject approaches
				# through a shaft/support before spending a full flight on them.
				if not ai.navigation.ray(goal+direction*18+Vector3.UP*.8,goal+Vector3.UP*.8).is_empty():continue
				# Heavy armour needs a higher launch hill and more run-up. Its
				# small thrust surplus cannot rescue a low, slow tower approach.
				if pads.generators.any(func(row):return Vector2(point.x-row.position.x,point.z-row.position.z).length()<34):continue
				var hit: Dictionary=ai.navigation.ray(point+Vector3.UP*50,point-Vector3.UP*90)
				if hit.is_empty() or hit.normal.y<.7 or goal.y-hit.position.y>33:continue
				# A downhill run-up follows gravity while skiing. A nearby hill
				# whose fall line points across the launch corridor sends the bot
				# sideways into a bunker before its aligned-launch gate can open.
				var fall_line:=Vector3.DOWN.slide(hit.normal);fall_line.y=0
				if hit.normal.dot(-direction)>.035 and fall_line.length()>.08 and fall_line.normalized().dot(-direction)<.7:continue
				# Roof edges can sit outside the generator's exclusion radius.
				# They look like launch hills from above, but reaching them sends
				# a grounded skier into the bunker wall. Prefer solid terrain;
				# a second floor below identifies a bridge or hollow building.
				var below: Dictionary=ai.navigation.ray(hit.position-Vector3.UP*.5,hit.position-Vector3.UP*24)
				if not below.is_empty() and below.normal.y>.5 and hit.position.y-below.position.y>3:continue
				if s.tribes_class!="heavy" and not fast_grab and goal.y-hit.position.y<4:continue
				if fast_grab and hit.position.y>goal.y+12:continue
				var cost: float=actor.position.distance_to(hit.position)+maxf(0,goal.y-hit.position.y)*(2 if s.tribes_class=="heavy" else 0)
				if fast_grab:cost+=maxf(0,goal.y-hit.position.y)*3
				if brain.goal_key=="st:flag":
					# Plan the escape before the grab. The nearest launch hill
					# often points away from home and forces a vulnerable U-turn
					# beside the defender. A clear lateral pass keeps useful speed.
					var homeward: Vector3=game.match_mode.bases[s.team]-goal;homeward.y=0
					cost+=(1+direction.dot(homeward.normalized()))*160
				cost+=tactics.stage_cost(id,goal,hit.position)
				cost+=capture.stage_cost(id,brain,hit.position+Vector3.UP*.06,goal)
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
			elif not capture.launch_allowed(id,brain):
				if not brain.has("failed_stages"):brain.failed_stages=[]
				brain.failed_stages.append(run.stage);brain.erase("tower");capture.count("unready_launches_rejected")
				if brain.failed_stages.size()>=2:capture.defer(id,brain,"unsuitable_runups")
			else:
				run.phase="run";run.at=game.clock
				if brain.get("capture_preparing",false):capture.count("prepared_launches")
		return true
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z);var speed:=velocity.length();var direction:=flat.normalized()
	var desired: Vector3=direction;s.jet_held=false;s.jump=run.get("launch",false) and not actor.jump_held;s.ski=false;run.erase("launch")
	if run.phase=="run":
		# The same slope rule used in open travel must also allow a downhill
		# start. Requiring above-walk speed here made that acceleration
		# unreachable: walking capped the run-up before skiing could begin.
		s.ski=ground_ski(actor.tribes_state.normal,direction,velocity,profile.walk)
		# Skiing follows the fall line; stick input cannot remove sideways
		# drift. Start a real directional jet correction before that drift
		# accelerates into the bunker below the launch hill.
		var heading_correction: bool=s.tribes_class!="heavy" and s.ski and speed>profile.walk*.4 and velocity.slide(direction).length()>maxf(1.5,speed*.2)
		if heading_correction or flat.length()<48 and velocity.dot(direction)>profile.walk*.75 and (s.tribes_class!="heavy" or velocity.slide(direction).length()<profile.walk*.3) or not actor.is_supported():
			run.phase="flight";run.at=game.clock;s.jump=actor.tribes_state.airtime<.25 and not actor.jump_held
		brain.travel_phase="tower_runup"
	if run.phase=="flight":
		# Reach the shelf's entry height with a bounded vertical speed. The old
		# ballistic switch alternated long burns and freefalls: it could land on
		# a covered shelf's roof, or arrive below its lip at -20 m/s.
		var vertical_target:=clampf((goal.y+.55-actor.position.y)*1.5,-4,10)
		s.jet_held=actor.velocity.y<vertical_target and actor.tribes_state.energy>3
		if s.tribes_class=="heavy":
			# Heavy armour has little thrust left after opposing gravity. Build
			# height early; the Light shelf controller spends its reserve holding
			# a low ceiling and cannot recover the remaining climb on arrival.
			var eta:=clampf(maxf(1,flat.length()-11)/maxf(speed,2),.1,6.0)
			var projected: float=actor.position.y+actor.velocity.y*eta-10*eta*eta
			s.jet_held=projected<goal.y+.7 and actor.tribes_state.energy>3
		# Heavy retains its ballistic launch: its much smaller lift surplus
		# cannot afford this Light/Medium heading burn from a slow takeoff.
		var correcting: bool=s.tribes_class!="heavy" and flat.length()>18 and velocity.slide(direction).length()>maxf(2,speed*.2) and goal.y-actor.position.y<8 and actor.velocity.y> -2
		# A prepared entry needs forward acceleration as well as lift. A target
		# equal to current speed only requested .08 stick and contradicted the
		# readiness forecast's .22 thrust share, arriving at walking speed.
		var entry_speed: float=profile.side_speed*.85 if brain.goal_key=="st:flag" and brain.get("capture_preparing",false) and goal.y-actor.position.y<8 and actor.tribes_state.energy>profile.energy*.4 else profile.walk
		desired=((direction*maxf(speed,entry_speed)-velocity)*.09+direction*.08).limit_length(.55 if correcting else .22)
		if correcting and actor.tribes_state.energy>3:s.jet_held=true
		s.ski=true;brain.travel_phase="tower_flight"
		if game.clock-run.at>1 and actor.is_supported() and actor.position.y<goal.y-2 or game.clock-run.at>12:
			tactics.reject_stage(id,goal,run.stage)
			if not brain.has("failed_stages"):brain.failed_stages=[]
			brain.failed_stages.append(run.stage);brain.erase("tower");s.jet_held=false;s.jump=false
	elif game.clock-run.at>8:brain.erase("tower")
	if route_look(id,brain) and game.clock>=float(brain.get("equipment_aim_until",0)):ai.aim(id,goal+Vector3.UP,.08)
	s.move=movement(id,desired);s.prone=false;s.crouch=false;s.swim=Vector3.ZERO
	return true
func route_look(id: int,brain: Dictionary) -> bool:
	return brain.enemy==0 or brain.get("travel_focus",false) and not brain.get("travel_defending",false)
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
