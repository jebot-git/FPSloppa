extends RefCounted
## Read the same replicated state on desktop and XR; no extra network messages.
static func active(game,listener: int) -> bool:
	if not game.active or game.map_loading or game.quitting or game.intermission>0 or game.lobby.active():return false
	var mode=game.match_mode
	match mode.kind:
		"as":return mode.assault.stage>=1 and not mode.assault.switching and not mode.assault.finished
		"de":return mode.defusal.phase=="live" and mode.defusal.planted
		"tb":
			if mode.titanball.preparing() or mode.titanball.winner!=-1:return false
			for row in mode.fortress.walkers.robots.values():
				if row.loop or row.points.is_empty():continue
				if not mode.titanball.route_id.is_empty() and row.id!=mode.titanball.route_id:continue
				# Actual world distance to the delivery base, not historical progress.
				if row.position.distance_squared_to(row.points[-1])<100.0:return true
			return false
	if not game.players.has(listener):return false
	var player: Dictionary=game.players[listener]
	if player.spectator:return false
	if mode.kind in ["st","ctf","tf"] and not player.dead:
		for flag in mode.flags:
			if flag.carrier==listener:return true
	if mode.kind in ["dm","ig","cc"]:
		return game.frag_limit>0 and player.kills==game.frag_limit-1
	if mode.kind in ["tdm","if","tf"] and player.team in [0,1]:
		# IF scores freeze rounds and TF scores captures; use their real win limit.
		return mode.limit()>0 and mode.scores[player.team]==mode.limit()-1
	return false
