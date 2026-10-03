extends RefCounted
## Shared desktop/VR presentation of authoritative team, carrier and ability state.
static func vitals(game,id: int) -> Dictionary:
	var state: Dictionary=game.players.get(id,{})
	var result:={"name":"ARMOUR","value":int(state.get("armor",0)),"maximum":200.0,"health_max":100.0}
	if game.match_mode.tribes.enabled() and game.fighters.has(id):
		var profile: Dictionary=game.match_mode.tribes.definition(id)
		result={"name":"ENERGY","value":roundi(game.fighters[id].tribes_state.energy) if not state.get("dead",true) else 0,"maximum":profile.energy,"health_max":float(profile.hp)}
	return result
static func read(game,id: int) -> Dictionary:
	var state: Dictionary=game.players.get(id,{})
	var team: int=state.get("team",-1) if game.match_mode.team_game() and not state.get("spectator",false) else -1
	var result: Dictionary={"team":team,"team_text":game.match_mode.TEAMS[team]+" TEAM" if team in [0,1] else "SPECTATOR" if state.get("spectator",false) else "","ability":"","carrier":"","flag_team":-1}
	if game.match_mode.defusal.enabled() and team in [0,1]:
		result.team_text="TERRORISTS" if game.match_mode.defusal.role(id)==0 else "COUNTER-TERRORISTS"
		result.carrier=game.match_mode.defusal.hint(id)
	if state.is_empty() or state.get("dead",true) or state.get("spectator",false) or game.lobby.active():return result
	if game.match_mode.fortress.enabled() and game.intermission<=0:
		var ability: Dictionary=game.match_mode.fortress.ability_state(id)
		if not ability.is_empty():
			result.ability=ability.label+" · "+("READY" if ability.ready else "READY IN %.1fs"%ability.remaining)
			if ability.active>0:result.ability+=" · ACTIVE %.1fs"%ability.active
	if game.armory.effective()=="tribes" and game.fighters.has(id):
		result.ability=game.fighters[id].Tribes.status(game.fighters[id])+" · "+game.match_mode.tribes.Arsenal.PACKS[state.get("tribes_pack","energy")].name+" · SHOULDER: "+game.match_mode.tribes.Arsenal.NAMES[state.get("tribes_grenade",9)]
		if game.match_mode.tribes.mode_enabled():result.ability+=" · TEAM ENERGY "+game.match_mode.tribes.energy_text(id)
		if state.get("tribes_next","light")!=state.get("tribes_class","light"):result.ability+=(" · FAVOURITE: " if game.match_mode.tribes.base_ctf() else " · NEXT: ")+state.tribes_next.to_upper()
	if game.armory.effective()=="cs16":result.ability=game.variant_combat.cs.label(id)
	if game.match_mode.defusal.enabled() and state.get("vr_device",false) and state.get("physical",false):
		var utility=game.match_mode.defusal.utility;var kind: int=utility.shoulder_selected(id)
		if kind>=0:result.ability+=" · SHOULDER: "+utility.NAMES[kind]
	if game.jetpacks.enabled() and game.fighters.has(id) and game.fighters[id].jetpack_enabled and game.intermission<=0:
		result.ability+=(" · " if not result.ability.is_empty() else "")+game.fighters[id].Jetpack.status(game.fighters[id].jetpack_state)
	if game.match_mode.titanball.preparing() and game.intermission<=0:
		var seconds:=ceili(game.match_mode.titanball.preparation_left)
		result.carrier="HANGAR OPENS IN %d:%02d"%[seconds/60,seconds%60]
	if game.match_mode.kind in ["ctf","tf","st"]:
		for index in game.match_mode.flags.size():
			if game.match_mode.flags[index].carrier==id:
				result.flag_team=index;result.carrier="YOU HAVE THE "+game.match_mode.TEAMS[index]+" FLAG · RETURN TO YOUR CAPTURE POINT"
	if game.match_mode.kind=="st":
		if result.flag_team>=0:result.carrier="ENEMY FLAG · RETURN HOME"
		result.carrier+=(" · " if not result.carrier.is_empty() else "")+"SENSOR: "+game.match_mode.tribes.deployables.sensor_status(id)
	return result
