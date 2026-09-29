extends RefCounted
## Prepare a useful escape before a contested grab. All acceleration, recharge
## and handoffs still use ordinary player inputs and the public flag rules.
var ai_ref: WeakRef
var ai:
	get:return ai_ref.get_ref()
	set(value):ai_ref=weakref(value)
var stats: Dictionary={}
func count(key: String):stats[key]=int(stats.get(key,0))+1

static func ready(speed: float,energy: float,capacity: float,heading: float) -> bool:
	return speed>=14 and energy>=capacity*.38 and heading>=-.15

static func forecast(start: Vector3,goal: Vector3,speed: float,vertical: float,energy: float,profile: Dictionary,pack: String) -> Dictionary:
	# Estimate the existing pulsed shelf controller, including the horizontal
	# share of thrust. This is a conservative admission estimate, not physics.
	var height:=start.y;var distance:=Vector2(goal.x-start.x,goal.z-start.z).length();var travelled:=0.0
	var elapsed:=0.0;var recharge:=11.0 if pack=="energy" else 8.0
	while travelled<distance and elapsed<8:
		var dt:=1.0/60;elapsed+=dt
		var held: bool=vertical<clampf((goal.y+.55-height)*1.5,-4,10) and energy>3
		var stick:=.22 if goal.y-height<8 and energy>profile.energy*.4 else .08
		var side:=clampf(1-speed/profile.side_speed,0,.8)*stick
		energy=clampf(energy+(recharge-(profile.drain if held else 0))*dt,0,profile.energy)
		if held:speed+=profile.thrust*side*dt
		vertical+=((profile.thrust*(1-side)*.95 if held else 0)-20)*dt
		height+=vertical*dt;travelled+=speed*dt
	return {"energy":energy,"speed":speed,"height":height,"reachable":travelled>=distance and height>=goal.y-.2}

func receiver(id: int) -> int:
	var game=ai.game;var s: Dictionary=game.players[id];var actor=game.fighters[id]
	var home: Vector3=game.match_mode.bases[s.team]
	for friend in game.players:
		if friend==id or not ai.alive(friend) or game.players[friend].team!=s.team or game.players[friend].tribes_class!="light":continue
		var other=game.fighters[friend];var profile: Dictionary=game.match_mode.tribes.definition(friend)
		if game.players[friend].hp<profile.hp*.6 or other.tribes_state.energy<profile.energy*.3:continue
		var distance: float=other.position.distance_to(actor.position)
		if distance<3 or distance>24 or other.position.distance_to(home)>actor.position.distance_to(home)-4:continue
		var forward: Vector3=home-actor.position;forward.y=0;forward=forward.normalized()
		var own_speed: float=maxf(game.match_mode.tribes.definition(id).walk,actor.velocity.dot(forward))
		if maxf(profile.walk,other.velocity.dot(forward))<own_speed+2:continue
		if ai.navigation.ray(actor.position+Vector3.UP,other.position+Vector3.UP).is_empty():return friend
	return 0

func context(id: int,brain: Dictionary) -> Dictionary:
	var game=ai.game;var actor=game.fighters[id];var s: Dictionary=game.players[id]
	var flag: Vector3=game.match_mode.bases[1-s.team];var home: Vector3=game.match_mode.bases[s.team]
	var threats: Array=ai.teamplay.intel(id).map(func(row):return row.position)
	for enemy in brain.visible:
		if ai.alive(enemy):threats.append(game.fighters[enemy].position)
	var contested: bool=threats.any(func(point):return point.distance_to(flag)<90)
	var alone: bool=actor.position.distance_to(flag)<28 and not contested
	if alone:
		alone=not game.players.keys().any(func(friend):return friend!=id and ai.alive(friend) and game.players[friend].team==s.team and game.fighters[friend].position.distance_to(flag)<32)
	var relay: int=receiver(id) if s.tribes_class!="light" else 0
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
	var homeward:=Vector3(home.x-flag.x,0,home.z-flag.z).normalized()
	var profile: Dictionary=game.match_mode.tribes.definition(id)
	var prediction:=forecast(actor.position,flag,maxf(profile.walk,velocity.length()),actor.velocity.y+(profile.jump if actor.is_supported() else 0),actor.tribes_state.energy,profile,s.tribes_pack)
	var prepared: bool=ready(velocity.length(),prediction.energy,profile.energy,velocity.normalized().dot(homeward)) and prediction.reachable
	return {"alone":alone,"contested":contested,"receiver":relay,"allowed":s.tribes_class=="light" or alone or relay!=0,"ready":prepared,"prediction":prediction}

func defer(id: int,brain: Dictionary,reason: String):
	if ai.game.clock>=float(brain.get("capture_defer_until",0)):count(reason)
	brain.capture_defer_until=ai.game.clock+24
	brain.erase("capture_prepare_at");brain.erase("tower");brain.erase("st_recovery")
	brain.capture_preparing=false;brain.capture_decision=reason;brain.plan_at=0;brain.route_at=0

func support_goal(id: int,brain: Dictionary,rows: Array):
	# Stay useful while the pack recovers, rather than orbiting the flag or
	# restarting the same failed run-up at every planning interval.
	brain.capture_preparing=false
	if ai.tribes.offense.screen_goal(id,brain,rows):return
	if ai.tribes.equipment.siege_goal(id,brain,rows):return
	ai.candidate(rows,"st:capture-cover","defend",ai.game.match_mode.bases[ai.game.players[id].team],250,true)

func goal(id: int,brain: Dictionary,rows: Array):
	var game=ai.game;var s: Dictionary=game.players[id];var flag: Dictionary=game.match_mode.flags[1-s.team]
	brain.capture_preparing=false
	# A dropped flag is an expiring recovery opportunity, not a planned stand grab.
	if flag.dropped:
		brain.capture_decision="recover_drop";ai.candidate(rows,"st:flag","objective",flag.position,340);return
	var info:=context(id,brain);brain.capture_readiness=info
	if not info.allowed:
		brain.capture_decision="armour_support";support_goal(id,brain,rows);return
	if game.clock<float(brain.get("capture_defer_until",0)) and not info.alone and info.receiver==0:
		support_goal(id,brain,rows);return
	var distance: float=game.fighters[id].position.distance_to(flag.position)
	if info.alone or info.receiver!=0:
		brain.capture_decision="opportunity" if info.alone else "relay"
	elif distance>135:
		brain.capture_decision="approach";brain.erase("capture_prepare_at")
	else:
		if not brain.has("capture_prepare_at"):brain.capture_prepare_at=game.clock;count("preparations")
		var flight: bool=brain.get("tower",{}).get("phase","")=="flight"
		# Never reverse an airborne committed crossing when fuel falls during
		# its burn. A failed/landed attempt must prepare again or change jobs.
		if not flight and game.clock-brain.capture_prepare_at>45:
			defer(id,brain,"preparation_timeouts");support_goal(id,brain,rows);return
		brain.capture_preparing=true
		brain.capture_decision="committed" if flight else "ready" if info.ready else "prepare"
	ai.candidate(rows,"st:flag","objective",flag.position,360 if info.ready else 300)

func stage_cost(id: int,brain: Dictionary,point: Vector3,goal: Vector3) -> float:
	if not brain.get("capture_preparing",false) or brain.goal_key!="st:flag":return 0
	var game=ai.game;var profile: Dictionary=game.match_mode.tribes.definition(id)
	var prediction:=forecast(point,goal,profile.walk,profile.jump,profile.energy*.94,profile,game.players[id].tribes_pack)
	return maxf(0,profile.energy*.38-prediction.energy)*5+maxf(0,14-prediction.speed)*15+(120 if not prediction.reachable else 0)

func launch_allowed(id: int,brain: Dictionary,rolling: bool=false) -> bool:
	if not brain.get("capture_preparing",false) or brain.goal_key!="st:flag":return true
	var game=ai.game;var actor=game.fighters[id];var s: Dictionary=game.players[id]
	var profile: Dictionary=game.match_mode.tribes.definition(id)
	var velocity:=Vector3(actor.velocity.x,0,actor.velocity.z)
	var prediction:=forecast(actor.position,brain.goal,maxf(profile.walk,velocity.length()),actor.velocity.y+(profile.jump if actor.is_supported() else 0),actor.tribes_state.energy,profile,s.tribes_pack)
	var toward:=Vector3(brain.goal.x-actor.position.x,0,brain.goal.z-actor.position.z).normalized()
	var homeward: Vector3=game.match_mode.bases[s.team]-brain.goal;homeward.y=0
	var heading: float=(velocity.normalized() if rolling else toward).dot(homeward.normalized())
	return prediction.reachable and ready(prediction.speed,prediction.energy,profile.energy,heading)
