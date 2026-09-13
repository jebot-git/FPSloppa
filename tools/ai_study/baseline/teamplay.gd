extends RefCounted
## Shared, delayed observations rather than shared omniscient enemy state.
## Decisions stay in the normal planner; no damage, inventory or flag grants.
var ai
var pending: Array=[]
var reports: Dictionary={}
var report_at: Dictionary={}
var reservations: Dictionary={}
var yield_at: Dictionary={}
var next_tick:=0.0
var stats: Dictionary={}
var callout_at: Dictionary={}

func count(event: String) -> void:
	stats[event]=int(stats.get(event,0))+1
func say(id: int,message: String) -> void:
	if not enabled(id):return
	var game=ai.game;var team: int=game.players[id].team
	if game.clock<float(callout_at.get(team,0)):return
	for peer in game.players:
		if peer>0 and game.match_mode.same_team(id,peer):
			game._chat_for(id,message,true);callout_at[team]=game.clock+15;return
func active(id: int) -> bool:
	return ai.alive(id) and not ai.game.match_mode.special.blocked(id)
func enabled(id: int) -> bool:
	return ai.game.match_mode.team_game() and active(id) and ai.game.players[id].team in [0,1]
func valid(report: Dictionary) -> bool:
	var game=ai.game
	return report.until>game.clock and active(report.observer) and active(report.enemy) and game.players[report.observer].team==report.team and game.players[report.observer].serial==report.observer_serial and game.players[report.enemy].serial==report.serial and not game.match_mode.same_team(report.observer,report.enemy)
func tick() -> void:
	var game=ai.game
	if game.clock<next_tick:return
	next_tick=game.clock+.2
	for index in range(pending.size()-1,-1,-1):
		var report: Dictionary=pending[index]
		if not valid(report):pending.remove_at(index);continue
		if report.ready>game.clock:continue
		var key: String="%s:%s"%[report.team,report.enemy]
		if not reports.has(key) or reports[key].time<report.time:
			reports[key]=report;count("reports_delivered")
			var location: String="my position"
			if game.match_mode.kind in ["ctf","tf"] and game.match_mode.bases.size()==2:
				var team: int=0 if report.position.distance_to(game.match_mode.bases[0])<report.position.distance_to(game.match_mode.bases[1]) else 1
				location=game.match_mode.TEAMS[team]+" base"
			elif game.match_mode.kind=="koth" and report.position.distance_to(game.match_mode.hill)<15:location="the hill"
			elif game.match_mode.kind=="as" and game.match_mode.assault.stage<game.match_mode.assault.objectives.size():
				if report.position.distance_to(game.match_mode.assault.objectives[game.match_mode.assault.stage].position)<15:location="the active objective"
			say(report.observer,"Enemy spotted near "+location+".")
		pending.remove_at(index)
	for key in reports.keys():
		if not valid(reports[key]):reports.erase(key)
	for key in reservations.keys():
		if not reservation_valid(reservations[key]):reservations.erase(key)
	for id in report_at.keys():
		if not active(id):report_at.erase(id)
	for key in yield_at.keys():
		if yield_at[key]<=game.clock:yield_at.erase(key)

func observe(id: int,brain: Dictionary) -> void:
	var game=ai.game
	if not enabled(id) or brain.enemy==0 or game.clock<float(report_at.get(id,0)):return
	# Perception has already applied FOV, LOS, disguise and cloak checks.
	if not brain.enemy in brain.visible:return
	report_at[id]=game.clock+.9
	pending.append({"observer":id,"observer_serial":game.players[id].serial,"enemy":brain.enemy,"serial":game.players[brain.enemy].serial,"team":game.players[id].team,"position":brain.seen_position,"time":game.clock,"ready":game.clock+.35,"until":game.clock+3.5})
	count("reports_sent")

func intel(id: int) -> Array:
	var result: Array=[]
	if not enabled(id):return result
	for report in reports.values():
		if report.observer!=id and report.team==ai.game.players[id].team and valid(report):result.append(report)
	return result
func focus_bonus(id: int,enemy: int) -> float:
	for report in intel(id):
		if report.enemy==enemy:return 14.0
	return 0.0

func pickup_key(pickup: Dictionary) -> String:
	return "%s:%s:%s"%[pickup.kind,pickup.item,pickup.position]
func reservation_valid(row: Dictionary) -> bool:
	var game=ai.game
	return row.until>game.clock and enabled(row.owner) and game.players[row.owner].team==row.team and game.players[row.owner].serial==row.serial and game.fighters[row.owner].position.distance_to(row.position)<8 and ai.item_value(row.owner,row.pickup)>0
func pickup_owner(id: int,pickup: Dictionary) -> int:
	if not enabled(id):return 0
	var key: String=str(ai.game.players[id].team)+":"+pickup_key(pickup)
	if not reservations.has(key):return 0
	var row: Dictionary=reservations[key]
	return int(row.owner) if row.team==ai.game.players[id].team and reservation_valid(row) else 0
func consider_pickup(id: int,pickup: Dictionary) -> bool:
	var game=ai.game
	if not enabled(id) or not pickup.available or game.fighters[id].position.distance_to(pickup.position)>12:return false
	var owner:=pickup_owner(id,pickup)
	if owner!=0:return owner!=id
	var key: String=str(game.players[id].team)+":"+pickup_key(pickup)
	# A human who ignores an offer must not reserve a pickup indefinitely.
	if game.clock<float(yield_at.get(key,0)):return false
	var own_need: float=ai.item_value(id,pickup)
	var best:=0;var value: float=own_need*1.35+10
	for friend in game.players:
		if friend==id or not active(friend) or not game.match_mode.same_team(id,friend):continue
		var distance: float=game.fighters[friend].position.distance_to(pickup.position)
		if distance>7 or not ai.visible(id,friend):continue
		var need: float=ai.item_value(friend,pickup)
		if need>value and ai.navigation.ray(ai.eye(friend),pickup.position+Vector3.UP*.5).is_empty():best=friend;value=need
	if best==0:return false
	reservations[key]={"owner":best,"team":game.players[id].team,"serial":game.players[best].serial,"position":pickup.position,"pickup":pickup.duplicate(),"until":game.clock+4}
	yield_at[key]=game.clock+10;count("pickups_offered")
	say(id,"Leaving "+str(pickup.kind)+" for "+game.players[best].name+".")
	return true
func leaving_pickup(id: int,pickup: Dictionary) -> bool:
	var owner:=pickup_owner(id,pickup)
	if owner==0 or owner==id:return false
	# An emergency overrides courtesy; never starve the more desperate bot.
	return ai.item_value(owner,pickup)>ai.item_value(id,pickup)*1.2

func escort_point(id: int,friend: int) -> Vector3:
	var game=ai.game
	var anchor: Vector3=game.fighters[friend].position
	var forward: Vector3=game.fighters[friend].velocity;forward.y=0
	if forward.length()<1:forward=Vector3.FORWARD.rotated(Vector3.UP,game.players[friend].yaw)
	forward=forward.normalized()
	var side:=forward.cross(Vector3.UP)*(1.0 if ai.team_rank(id)%2==0 else -1.0)
	var point: Vector3=ai.navigation.project_local(anchor-forward*2.5+side*2.5)
	if point.distance_to(anchor)>5 or ai.navigation.hazardous(point) or not ai.navigation.ray(point+Vector3.UP,anchor+Vector3.UP).is_empty():return ai.defense_point(id,anchor)
	return point

func firing_point(id: int,anchor: Vector3,threat: Vector3,ambush: bool=false) -> Dictionary:
	var nav=ai.navigation
	var best: Dictionary={};var value:=-INF
	var rank: int=ai.team_rank(id)
	for index in 8:
		var angle:=TAU*float(posmod(index+rank*3,8))/8
		var point: Vector3=nav.project_local(anchor+Vector3(cos(angle),0,sin(angle))*(5.0 if ambush else 3.5))
		if point.distance_to(anchor)>7 or point.distance_to(anchor)<2 or nav.hazardous(point):continue
		var floor_hit: Dictionary=nav.ray(point+Vector3.UP*.5,point-Vector3.UP*.8)
		if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
		if not nav.ray(point+Vector3.UP*1.5,threat+Vector3.UP).is_empty():continue
		var covered: bool=not nav.ray(point+Vector3.UP*.4,threat+Vector3.UP).is_empty()
		var lateral: Vector3=(threat-point).normalized().cross(Vector3.UP)
		covered=covered or not nav.ray(point+Vector3.UP+lateral*.9,threat+Vector3.UP).is_empty()
		if ambush and not covered:continue
		var score: float=(5 if covered else 0)-ai.game.fighters[id].position.distance_to(point)*.15
		for friend in ai.brains:
			if friend!=id and active(friend) and ai.game.match_mode.same_team(id,friend):score-=maxf(0,3-point.distance_to(ai.brains[friend].goal))*3
		if score>value:value=score;best={"position":point,"look":threat}
	return best

func goals(id: int,brain: Dictionary,rows: Array) -> void:
	if not enabled(id):return
	var game=ai.game;var mode=game.match_mode
	var sightings:=intel(id)
	if brain.enemy==0:
		for report in sightings:
			# Investigation follows a frozen report position; it never acquires
			# a combat target until this bot sees the opponent itself.
			ai.candidate(rows,"relay:%s"%report.enemy,"assist",report.position,58)
	# Cover one vulnerable ally, carrier or teammate committed to an interaction.
	if game.players[id].hp>mode.fortress.max_health(id)*.55 and not mode.fortress.carrying(id):
		var best_friend:=0;var urgency:=0.0
		for friend in game.players:
			if friend==id or not active(friend) or not mode.same_team(id,friend):continue
			if game.fighters[id].position.distance_to(game.fighters[friend].position)>18:continue
			var need:=0.0
			if mode.fortress.carrying(friend):need=125
			elif game.players[friend].hp<mode.fortress.max_health(friend)*.4:need=100
			if ai.brains.has(friend) and ai.brains[friend].goal_kind in ["thaw","heal","repair","checkpoint","destroy"]:need=maxf(need,120)
			if need>urgency:urgency=need;best_friend=friend
		if best_friend!=0:
			var threat: Dictionary={}
			if brain.enemy!=0:threat={"position":brain.seen_position}
			else:
				for report in sightings:
					if report.position.distance_to(game.fighters[best_friend].position)<22:threat=report;break
			if not threat.is_empty():
				var point:=firing_point(id,game.fighters[best_friend].position,threat.position)
				if not point.is_empty():
					ai.candidate(rows,"guard:%s"%best_friend,"guard",point.position,urgency,true,best_friend);rows[-1].look=point.look
	# Ambushes belong to a minority defensive role and expire even if nobody
	# arrives. Never park the whole team outside a hill or abandon a carried flag.
	if brain.enemy!=0 or mode.fortress.carrying(id) or game.players[id].hp<45 or brain.role!="defend" or game.players[id].get("tf_class","")=="engineer":return
	if game.clock<brain.ambush_until:
		if brain.goal_kind=="ambush":ai.candidate(rows,brain.goal_key,"ambush",brain.goal,155,true);rows[-1].look=brain.watch
		return
	if game.clock<brain.ambush_at:return
	var anchor: Dictionary={}
	for row in rows:
		if row.kind=="defend":anchor=row;break
	if anchor.is_empty() and mode.kind=="tdm" and not sightings.is_empty():anchor=sightings[0]
	if anchor.is_empty():return
	var watch: Vector3=anchor.position
	if mode.kind in ["ctf","tf"] and mode.flags.size()==2:watch=mode.flags[game.players[id].team].position
	elif mode.kind=="as" and mode.assault.stage<mode.assault.objectives.size():watch=mode.assault.objectives[mode.assault.stage].position
	var spot:=firing_point(id,watch,watch,true)
	if not spot.is_empty():ai.candidate(rows,"ambush","ambush",spot.position,155,true);rows[-1].look=spot.look

func selected(id: int,brain: Dictionary,chosen: Dictionary) -> void:
	if chosen.kind=="ambush" and brain.goal_kind!="ambush":
		brain.ambush_until=ai.game.clock+7;brain.ambush_at=ai.game.clock+19;count("ambushes")
	if chosen.kind!=brain.goal_kind and chosen.kind in ["guard","assist","escort"]:count(chosen.kind+"_assignments")
	if chosen.kind=="guard" and brain.goal_kind!="guard" and active(chosen.support):say(id,"Covering "+ai.game.players[chosen.support].name+".")
	brain.watch=chosen.get("look",chosen.position)
