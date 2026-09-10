extends RefCounted
## Server-owned state. Clients only use the replicated freeze timers for presentation.
const THAW_SECONDS:=3.0
const THAW_RADIUS:=1.5
const DRAIN_PER_SECOND:=3.0
var mode_ref: WeakRef
var mode:
	get: return mode_ref.get_ref()
var frozen: Dictionary={}
var drain: Dictionary={}
var reset_at:=0.0
func setup(value) -> void: mode_ref=weakref(value)
func reset() -> void:
	frozen.clear();drain.clear();reset_at=0.0
func blocked(id: int) -> bool: return frozen.has(id) or reset_at>0.0
func spawn(id: int) -> void:
	frozen.erase(id);drain.erase(id)
	var s: Dictionary=mode.game.players[id]
	if mode.kind in ["ig","cc"]:
		s.weapon=9 if mode.kind=="ig" else 1;s.owned=[s.weapon];s.ammo=[0,0,0,0]
func freeze(id: int,attacker: int) -> void:
	var g=mode.game;var s: Dictionary=g.players[id]
	frozen[id]=0.0;s.fire=false;s.offhand_fire=false;s.melee=false;s.charge=0.0;s.move=Vector2.ZERO;s.room=Vector3.ZERO
	g.fighters[id].velocity=Vector3.ZERO;g.fighters[id].blast_velocity=Vector2.ZERO
	s.deaths+=1
	if g.players.has(attacker):g.players[attacker].kills+=-1 if attacker==id or mode.same_team(id,attacker) else 1
	g._announcement.rpc(s.name+" is frozen · teammates stay nearby for 3 seconds to thaw")
func tick(delta: float) -> void:
	var g=mode.game
	for id in frozen.keys():
		if not g.players.has(id) or g.players[id].spectator:frozen.erase(id)
	if mode.kind=="cc":
		for id in g.players:
			var s: Dictionary=g.players[id]
			if s.dead or s.spectator or s.invulnerable>g.clock:continue
			drain[id]=drain.get(id,0.0)+delta*DRAIN_PER_SECOND
			var amount:=int(drain[id]);drain[id]-=amount
			if amount>0:g._damage(id,id,amount,"CIRCUS HUNGER",true)
	elif mode.kind=="ft":
		if reset_at>0.0:
			if g.clock>=reset_at:
				reset_at=0.0;frozen.clear()
				for shot in g.projectiles.values():
					if is_instance_valid(shot.node):shot.node.queue_free()
				g.projectiles.clear()
				for id in g.players:g._spawn(id)
			return
		var total: Array=[0,0];var live: Array=[0,0]
		for id in g.players:
			var s: Dictionary=g.players[id]
			if s.spectator or s.team<0:continue
			total[s.team]+=1
			if not frozen.has(id):live[s.team]+=1
		if (total[0]==0 or total[1]==0) and not frozen.is_empty():
			for id in frozen.keys():g._spawn(id)
			return
		# Check the wipe before thawing; an empty team never awards free points.
		if total[0]>0 and total[1]>0 and (live[0]==0 or live[1]==0):
			if live[0]!=live[1]:
				var winner:=0 if live[0]>0 else 1
				mode.scores[winner]+=1;g._announcement.rpc(mode.TEAMS[winner]+" wins the freeze round");mode.check_limit()
			reset_at=g.clock+3.0
			return
		for id in frozen.keys():
			var helping:=false
			for other in g.players:
				if other==id or frozen.has(other) or g.players[other].dead or g.players[other].spectator:continue
				if mode.same_team(id,other) and mode.nearby(other,g.fighters[id].position,THAW_RADIUS):helping=true;break
			frozen[id]=float(frozen[id])+delta if helping else 0.0
			if frozen[id]>=THAW_SECONDS:
				# Respawn safely in place: no teleport, fresh pistol, no retained charge.
				var pos: Vector3=g.fighters[id].position;var yaw: float=g.players[id].yaw
				g._spawn(id);g.fighters[id].position=pos;g.players[id].yaw=yaw
				g._announcement.rpc(g.players[id].name+" thawed")
func heal(attacker: int,victim: int,actual: int,weapon: String) -> void:
	var g=mode.game
	if mode.kind!="cc" or weapon!="CHAINSAW" or attacker==victim or not g.players.has(attacker):return
	var s: Dictionary=g.players[attacker]
	if not s.dead and not s.spectator:s.hp=mini(100,s.hp+actual)
