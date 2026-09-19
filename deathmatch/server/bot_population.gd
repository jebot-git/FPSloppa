extends RefCounted
## Bots use ordinary player lifecycle and inputs, but consume no ENet peers.
var game
var target:=0
# -1 uses the configured total-population fill; RCON can request a bot count.
var count_target:=-1
var next_id:=-1000
const CLASSES=["scout","soldier","demoman","medic","heavy","engineer","sniper","pyro","spy"]
func _init(arena) -> void:game=arena
func human_slots() -> int:
	# Accepted downloads reserve seats. A transport connection alone does not.
	var seats: Dictionary={}
	for id in game.players:
		if id>0:seats[id]=true
	for id in game.pending_names:
		if id>0:seats[id]=true
	return seats.size()
func candidate() -> int:
	var chosen:=0
	var best:=-INF
	var teams: Array=[0,0]
	for s in game.players.values():
		if s.team in [0,1]:teams[s.team]+=1
	for id in game.players:
		if id>=0:continue
		var s: Dictionary=game.players[id]
		# Preserve a pilot when another bot can yield its place.
		var score: float=(100 if not game.match_mode.fortress.walkers.mounted(id) else 0)+(10 if s.dead else 0)
		if s.team in [0,1]:score+=teams[s.team]
		if score>best:chosen=id;best=score
	return chosen
func make_room(incoming: int) -> bool:
	if human_slots()>game.max_clients:return false
	while game.players.size()>=game.max_clients:
		var id:=candidate()
		if id==0:return false
		if not game.pending_spectators.get(incoming,false) and not game.pending_teams.has(incoming):
			game.pending_teams[incoming]=game.players[id].team
		game.server_log.record("bot_replaced",{"bot":id,"incoming":incoming})
		game._peer_left(id)
	return true
func refresh_navigation() -> void:
	if is_instance_valid(game.district_gateway):return
	if not (game.dedicated and (target>0 or count_target>0)) and not is_instance_valid(game.bots):return
	if is_instance_valid(game.bots):game.bots.free()
	game.bots=preload("res://deathmatch/bots.gd").new()
	game.add_child(game.bots);game.bots.setup(game)
func maintain() -> void:
	if not game.dedicated or not game.active or not game.multiplayer.is_server() or game.map_loading:return
	var humans: int=game.players.keys().filter(func(id):return id>0).size()
	var desired:=clampi(humans+count_target if count_target>=0 else target,0,game.max_clients)
	while game.players.size()>desired:
		var id:=candidate()
		if id==0:break
		game._peer_left(id)
	if desired==0:return
	if not is_instance_valid(game.bots):refresh_navigation()
	while game.players.size()<desired:
		var role: String="soldier"
		if game.match_mode.fortress.enabled():
			var team: int=game.match_mode.assign_team(false)
			var counts: Dictionary={}
			for s in game.players.values():
				if s.team==team:counts[s.tf_next]=int(counts.get(s.tf_next,0))+1
			var least:=10000
			for name in CLASSES:
				if int(counts.get(name,0))<least:least=int(counts.get(name,0));role=name
		var id:=next_id;next_id-=1
		game._add_player(id,"Bot "+str(-id-999),false,role)
		game.server_log.record("bot_added",{"bot":id,"team":game.players[id].team,"class":role})
