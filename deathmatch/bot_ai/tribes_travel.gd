extends RefCounted
## Carrier route ranking in estimated seconds. This is a planning estimate;
## movement still uses the ordinary armour physics, jets and energy reserve.
var ai_ref: WeakRef
var ai:
	get:return ai_ref.get_ref()
	set(value):ai_ref=weakref(value)
func context(id: int) -> Dictionary:
	var game=ai.game;var profile: Dictionary=game.match_mode.tribes.definition(id)
	return {"walk":profile.walk,"speed":maxf(profile.walk*1.3,Vector2(game.fighters[id].velocity.x,game.fighters[id].velocity.z).length()),"reserve":game.fighters[id].tribes_state.energy/profile.energy}
func seconds(id: int,path: PackedVector3Array) -> float:
	if path.size()<2:return INF
	var game=ai.game;var profile: Dictionary=game.match_mode.tribes.definition(id);var routes=ai.tribes.routes
	var velocity: Vector3=game.fighters[id].velocity;velocity.y=0
	var speed: float=maxf(profile.walk,velocity.length());var heading:=velocity.normalized()
	var reserve: float=game.fighters[id].tribes_state.energy/profile.energy
	var total:=0.0;var index:=0
	while index<path.size()-1:
		# Match the steering controller's clear-corridor lookahead instead of
		# charging for every small zigzag of the terrain sampling grid.
		var next:=index+1
		for candidate in range(index+2,mini(path.size(),index+5)):
			if path[index].distance_to(path[candidate])>45 or not routes.clear(path[index],path[candidate]):break
			next=candidate
		var offset:=path[next]-path[index];var distance:=offset.length();var flat:=Vector3(offset.x,0,offset.z);var direction:=flat.normalized()
		if distance<.1:index=next;continue
		var turn:=acos(clampf(heading.dot(direction),-1,1)) if not heading.is_zero_approx() and not direction.is_zero_approx() else 0.0
		# A reversal spends time braking and rebuilding speed; a shallow bend
		# can be flown with a smaller directional-jet correction.
		total+=2*speed*sin(turn*.5)/maxf(4,profile.thrust*.5)
		var entry: float=maxf(profile.walk,speed*maxf(0,cos(turn)))
		var exit_speed:=entry
		var indoors: bool=routes.covered(path[index]) or routes.covered(path[next]) or routes.covered(path[index].lerp(path[next],.5))
		if indoors:entry=minf(entry,profile.walk*.7);exit_speed=entry;total+=.4
		elif offset.y < -.5:exit_speed=minf(maxf(profile.side_speed*1.6,speed),sqrt(entry*entry+40*absf(offset.y)))
		elif offset.y>1:
			exit_speed=maxf(profile.walk,entry*(.7+.3*reserve))
			total+=offset.y*(.12+.35*(1-reserve))
		else:exit_speed=maxf(entry,profile.walk*1.15)
		total+=distance/maxf(1,(entry+exit_speed)*.5)
		speed=exit_speed;heading=direction;index=next
	return total
func path(id: int,start: Vector3,goal: Vector3,avoid: Array,retain: bool=true) -> PackedVector3Array:
	var routes=ai.tribes.routes;var travel:=context(id)
	var best:=PackedVector3Array();var cost:=INF
	# Include the ordinary route so a time estimate never removes an existing
	# physical option. The other searches price climbs and covered passages.
	var options: Array=[routes.path(start,goal,0,avoid)]
	for lane in ([0,1,-1] if start.distance_to(goal)>220 else [0]):options.append(routes.path(start,goal,lane,avoid,travel))
	for candidate in options:
		var estimate:=seconds(id,candidate)
		if estimate<cost:cost=estimate;best=candidate
	# Keep a still-clear route unless another saves at least 15% and 1.5 s.
	# Recent failed-corridor memory disables retention until recovery succeeds.
	var brain: Dictionary=ai.brains.get(id,{})
	if retain and avoid.is_empty() and brain.get("goal",Vector3.INF).distance_to(goal)<2 and brain.get("step",0)<brain.get("path",PackedVector3Array()).size():
		var old:=PackedVector3Array([start]);old.append_array(brain.path.slice(brain.step))
		if old.size()>1 and routes.clear(start,old[1]) and old[-1].distance_to(goal)<2:
			var old_cost:=seconds(id,old)
			if cost>old_cost*.85 or old_cost-cost<1.5:return old
	return best
