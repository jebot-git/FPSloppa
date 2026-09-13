extends RefCounted
static func capture(game) -> Dictionary:
	var ranked: Array=game.players.values().filter(func(p):return not p.spectator).duplicate(true)
	var team_game: bool=game.match_mode.team_game()
	ranked.sort_custom(func(a,b):
		if team_game and a.team!=b.team:return a.team<b.team
		if a.kills!=b.kills:return a.kills>b.kills
		if a.deaths!=b.deaths:return a.deaths<b.deaths
		return a.name.naturalnocasecmp_to(b.name)<0)
	var result: Array=[]
	for p in ranked:
		result.append({"name":p.name,"team":p.team,"kills":p.kills,"deaths":p.deaths,"ping":p.ping,"class_name":game.match_mode.fortress.CLASSES.get(p.get("tf_class","soldier"),{}).get("name","UNKNOWN")})
	return {"title":"ROUND COMPLETE · "+game.round_message if game.intermission>0 else "FPSLOPPA · "+game.match_mode.NAMES[game.match_mode.kind],"summary":"RED %d  /  BLUE %d   ·   %s"%[game.match_mode.scores[0],game.match_mode.scores[1],game.map_title] if team_game else game.map_title,"team_game":team_game,"tf":game.match_mode.fortress.enabled(),"ranked":result,"spectators":game.players.values().filter(func(p):return p.spectator).map(func(p):return p.name)}
