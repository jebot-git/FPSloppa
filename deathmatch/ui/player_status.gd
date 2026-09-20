extends RefCounted
## Shared desktop/VR presentation of authoritative team, carrier and ability state.
static func read(game,id: int) -> Dictionary:
	var state: Dictionary=game.players.get(id,{})
	var team: int=state.get("team",-1) if game.match_mode.team_game() and not state.get("spectator",false) else -1
	var result: Dictionary={"team":team,"team_text":game.match_mode.TEAMS[team]+" TEAM" if team in [0,1] else "SPECTATOR" if state.get("spectator",false) else "","ability":"","carrier":"","flag_team":-1}
	if state.is_empty() or state.get("dead",true) or state.get("spectator",false) or game.lobby.active():return result
	if game.match_mode.kind=="cq" and game.fighters.has(id) and game.intermission<=0:
		result.ability=preload("res://deathmatch/conquest/jetpack.gd").status(game.fighters[id].jetpack_state)
	if game.match_mode.fortress.enabled() and game.intermission<=0:
		var ability: Dictionary=game.match_mode.fortress.ability_state(id)
		if not ability.is_empty():
			result.ability=ability.label+" · "+("READY" if ability.ready else "READY IN %.1fs"%ability.remaining)
			if ability.active>0:result.ability+=" · ACTIVE %.1fs"%ability.active
	if game.match_mode.titanball.preparing() and game.intermission<=0:
		var seconds:=ceili(game.match_mode.titanball.preparation_left)
		result.carrier="HANGAR OPENS IN %d:%02d"%[seconds/60,seconds%60]
	if game.match_mode.kind in ["ctf","tf"]:
		for index in game.match_mode.flags.size():
			if game.match_mode.flags[index].carrier==id:
				result.flag_team=index;result.carrier="YOU HAVE THE "+game.match_mode.TEAMS[index]+" FLAG · RETURN TO YOUR CAPTURE POINT"
	return result
