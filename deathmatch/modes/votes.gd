extends Node
## The electorate is fixed at proposal time; spectators and late joins cannot vote.
var game
var enabled:=true
var ballot: Dictionary={}
var cooldown:=0.0
var team_cooldowns: Dictionary={}
var allowed_maps: Array=[]
var allowed_matches: Array=[]
var allowed_modes: Array=["dm"]
var view: Dictionary={}
func setup(arena: Node) -> void:game=arena
func eligible(id: int) -> bool:return id>0 and game.players.has(id) and not game.players[id].spectator
func choices() -> Array:
	var result: Array=[]
	for row in game.map_catalog:
		if game.match_mode.kind=="as" and not game.Maps.supports_assault(row.path):continue
		if FileAccess.file_exists(row.path) and (game.mode_maplists.is_empty() or row.id in game.map_rotation):result.append({"id":row.id,"title":row.title})
	return result
func match_choices() -> Array:
	var result: Array=[]
	for mode in allowed_modes:
		var maplist: Array=game.mode_maplists.get(mode,game.map_rotation)
		for row in game.map_catalog:
			if mode=="as" and not game.Maps.supports_assault(row.path):continue
			if FileAccess.file_exists(row.path) and (maplist.is_empty() or row.id in maplist):result.append({"mode":mode,"map":row.id,"title":row.title})
	return result
func offer(id: int) -> void:policy.rpc_id(id,enabled,choices(),allowed_modes,match_choices())
@rpc("authority","call_remote","reliable",0)
func policy(allowed: bool,maps: Array,modes: Array=["dm"],matches: Array=[]) -> void:enabled=allowed;allowed_maps=maps;allowed_modes=modes;allowed_matches=matches
func propose(kind: String,value: String="") -> void:
	if multiplayer.is_server():start(multiplayer.get_unique_id(),kind,value)
	else:request.rpc_id(1,kind,value)
@rpc("any_peer","call_remote","reliable",0)
func request(kind: String,value: String) -> void:
	if multiplayer.is_server():start(multiplayer.get_remote_sender_id(),kind,value)
func start(id: int,kind: String,value: String) -> bool:
	if game.lobby.active() or not enabled or not game.active or game.practice or game.map_loading or game.intermission>0 or not eligible(id) or not ballot.is_empty() or game.clock<cooldown:return false
	if kind=="balance":
		if not game.match_mode.team_game():return false
	elif kind=="mode":
		if allowed_modes.size()<2 or not allowed_modes.has(value) or value==game.match_mode.kind:return false
		if value=="as" and not match_choices().any(func(row):return row.mode=="as"):return false
	elif kind=="match":
		var pair:=value.split("|")
		if pair.size()!=2 or not match_choices().any(func(row):return row.mode==pair[0] and row.map==pair[1]):return false
		if pair[0]==game.match_mode.kind and pair[1]==game.current_map:return false
	elif kind=="map":
		if value==game.current_map or not choices().any(func(row):return row.id==value):return false
	else:return false
	var electorate: Array=game.players.keys().filter(eligible)
	ballot={"kind":kind,"value":value,"eligible":electorate,"votes":{id:true},"needed":electorate.size()/2+1,"until":game.clock+25.0}
	cooldown=game.clock+60.0
	game._announcement.rpc(game.players[id].name+" called vote: "+("balance teams" if kind=="balance" else "change mode to "+value if kind=="mode" else "change match to "+value.replace("|"," / ") if kind=="match" else "change map to "+value))
	evaluate();return true
func vote(yes: bool) -> void:
	if multiplayer.is_server():cast(multiplayer.get_unique_id(),yes)
	else:cast_request.rpc_id(1,yes)
@rpc("any_peer","call_remote","reliable",0)
func cast_request(yes: bool) -> void:
	if multiplayer.is_server():cast(multiplayer.get_remote_sender_id(),yes)
func cast(id: int,yes: bool) -> bool:
	if ballot.is_empty() or not eligible(id) or not ballot.eligible.has(id) or ballot.votes.has(id):return false
	game.server_log.record("vote_cast",{"peer":id,"yes":yes,"kind":ballot.kind},2)
	ballot.votes[id]=yes;evaluate();return true
func evaluate() -> void:
	if ballot.is_empty():return
	var yes: int=ballot.votes.values().count(true);var no: int=ballot.votes.values().count(false)
	if yes>=ballot.needed:
		var kind: String=ballot.kind;var value: String=ballot.value;ballot.clear()
		game._announcement.rpc("Vote passed: "+("balance teams" if kind=="balance" else "change mode to "+value if kind=="mode" else "change match to "+value.replace("|"," / ") if kind=="match" else "change map to "+value))
		if kind=="balance":balance()
		elif kind=="mode":change_mode.call_deferred(value)
		elif kind=="match":change_match.call_deferred(value)
		else:change_map.call_deferred(value)
	elif no>ballot.eligible.size()-ballot.needed or game.clock>=ballot.until:
		ballot.clear();game._announcement.rpc("Vote failed")
func tick() -> void:
	if game.intermission>0 or game.map_loading:ballot.clear()
	else:evaluate()
func snapshot() -> Dictionary:
	if ballot.is_empty():return {}
	return {"title":"BALANCE TEAMS" if ballot.kind=="balance" else "MODE: "+ballot.value.to_upper() if ballot.kind=="mode" else "MATCH: "+ballot.value.replace("|"," / ") if ballot.kind=="match" else "MAP: "+ballot.value,"yes":ballot.votes.values().count(true),"no":ballot.votes.values().count(false),"needed":ballot.needed,"seconds":maxi(0,ceili(ballot.until-game.clock)),"voted":ballot.votes.keys()}
func switch_team(team: int) -> void:
	if multiplayer.is_server():change_team(multiplayer.get_unique_id(),team)
	else:team_request.rpc_id(1,team)
@rpc("any_peer","call_remote","reliable",0)
func team_request(team: int) -> void:
	if multiplayer.is_server():change_team(multiplayer.get_remote_sender_id(),team)
func change_team(id: int,team: int,force: bool=false) -> bool:
	if game.match_mode.special.blocked(id):return false
	if not game.active or not game.match_mode.team_game() or not eligible(id) or not team in [0,1] or game.players[id].team==team or game.intermission>0 or game.map_loading:return false
	if not force:
		if game.clock<team_cooldowns.get(id,0):return false
		var count: Array=[0,0]
		for s in game.players.values():
			if s.team>=0 and not s.spectator:count[s.team]+=1
		# A voluntary switch must improve numerical balance; votes can reshuffle equal teams.
		if count[team]>=count[1-team]:return false
	game.match_mode.fortress.departed(id)
	game.match_mode.drop(id);game.players[id].team=team;team_cooldowns[id]=game.clock+30
	game._spawn(id);game.players[id].invulnerable=0
	game._broadcast_roster();game._announcement.rpc(game.players[id].name+" joined "+game.match_mode.TEAMS[team]);return true
func balance() -> void:
	var ids: Array=game.players.keys().filter(eligible)
	ids.sort_custom(func(a,b):return game.players[a].kills>game.players[b].kills if game.players[a].kills!=game.players[b].kills else a<b)
	# Snake ordering spreads the strongest fraggers while keeping sizes within one.
	for i in range(ids.size()):change_team(ids[i],0 if i%4 in [0,3] else 1,true)
func change_map(value: String) -> void:
	if not game.active or not multiplayer.is_server():return
	if value==game.current_map:game._restart_round()
	elif game._rotate_map(value):
		var index: int=game.map_rotation.find(value)
		if index>=0:game.rotation_index=index
func reset() -> void:ballot.clear();view.clear();team_cooldowns.clear()

func change_mode(value: String) -> void:
	if not game.active or not multiplayer.is_server() or not allowed_modes.has(value):return
	var target: String=game.current_map
	if value=="as":
		var compatible: Array=match_choices().filter(func(row):return row.mode=="as")
		if compatible.is_empty():return
		target=compatible[0].map
	game.match_mode.kind=value
	# A new game type starts a fresh round on this map, assigning teams again as peers rejoin.
	for s in game.players.values():s.team=-1
	game.pending_teams.clear()
	if game.mode_maplists.has(value):
		game.map_rotation=game.mode_maplists[value].duplicate();game.rotation_index=0
		game._rotate_map(target if value=="as" else game.map_rotation[0])
	else:game._rotate_map(target)

func change_match(value: String) -> void:
	if not game.active or not multiplayer.is_server():return
	var pair:=value.split("|")
	if pair.size()!=2 or not match_choices().any(func(row):return row.mode==pair[0] and row.map==pair[1]):return
	game.match_mode.kind=pair[0]
	if game.mode_maplists.has(pair[0]):game.map_rotation=game.mode_maplists[pair[0]].duplicate()
	for s in game.players.values():s.team=-1
	game.pending_teams.clear()
	game.rotation_index=maxi(0,game.map_rotation.find(pair[1]))
	game._rotate_map(pair[1])
