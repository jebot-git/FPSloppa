extends RefCounted
## ST flag flight stays on the authority; clients/replays use normal flag snapshots.
const RETURN_SECONDS:=45.0
const FADE_SECONDS:=2.5
var rules_ref: WeakRef
var rules:
	get:return rules_ref.get_ref()
var game:
	get:return rules.game
var flights: Dictionary={}
func setup(value):rules_ref=weakref(value)
func reset():flights.clear()
func carried(id: int) -> int:
	if rules.kind!="st":return -1
	for i in rules.flags.size():
		if rules.flags[i].carrier==id:return i
	return -1
func drop(id: int,origin:=Vector3.INF,impulse:=Vector3.ZERO) -> bool:
	var team:=carried(id)
	if team<0:return false
	if not game.fighters.has(id):rules.return_flag(team);return true
	var actor=game.fighters[id]
	var at: Vector3=actor.position+Vector3.UP*.8 if origin==Vector3.INF else origin
	var f: Dictionary=rules.flags[team]
	f.carrier=0;f.dropped=true;f.position=at;f.return_at=game.clock+RETURN_SECONDS+FADE_SECONDS
	flights[team]={"velocity":actor.velocity+impulse-Vector3.UP*.01,"dropper":id,"grace":game.clock+.6}
	game._announcement.rpc(rules.TEAMS[team]+" flag dropped")
	return true
func can_take(team: int,id: int) -> bool:
	if rules.tribes.vehicles.mounted(id) or rules.tribes.operating(id):return false
	var flight: Dictionary=flights.get(team,{})
	return flight.get("dropper",0)!=id or game.clock>=flight.get("grace",0.0)
func tick(delta: float):
	if rules.kind!="st":return
	for team in flights.keys():
		var f: Dictionary=rules.flags[team]
		if not f.dropped or f.carrier!=0:flights.erase(team);continue
		var motion: Dictionary=flights[team]
		# Sweep the entire step, including high inherited skiing speed.
		var remaining: float=delta
		while remaining>0:
			var dt:=minf(remaining,1.0/60);remaining-=dt
			if motion.velocity==Vector3.ZERO:break
			var end: Vector3=f.position+motion.velocity*dt-Vector3.UP*10*dt*dt
			motion.velocity.y-=20*dt
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(f.position,end,1))
			if hit.is_empty():f.position=end
			else:
				f.position=hit.position+hit.normal*.08
				motion.velocity=motion.velocity.bounce(hit.normal)*.35
				if hit.normal.y>.5 and motion.velocity.length()<2:motion.velocity=Vector3.ZERO
		if f.position.y<game.fall_limit or not f.position.is_finite():rules.return_flag(team)
func kill_bonus(victim: int,attacker: int):
	if rules.kind!="st" or attacker==victim or not game.players.has(attacker) or rules.same_team(victim,attacker):return
	var team: int=game.players[attacker].team
	if team not in [0,1]:return
	var own: Dictionary=rules.flags[team];var enemy: Dictionary=rules.flags[1-team]
	var defended: bool=own.carrier==0 and game.fighters[victim].position.distance_to(own.position)<80
	var escorted: bool=enemy.carrier!=0 and game.fighters.has(enemy.carrier) and game.fighters[attacker].position.distance_to(game.fighters[enemy.carrier].position)<80
	game.players[attacker].kills+=int(defended)+int(escorted)
