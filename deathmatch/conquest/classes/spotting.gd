extends RefCounted
## Team-shared name/icon spotting. Authority checks world LOS at 10 Hz.
const ICONS={"shocktroop":"\ue000","scout":"\ue001","medic":"\ue002","technician":"\ue003"}
const MEMORY:=10.0
var icon_font:FontFile
func font() -> FontFile:
	if not icon_font:
		icon_font=load("res://deathmatch/conquest/classes/icons/class_icons.ttf")
		icon_font.fallbacks=[ThemeDB.fallback_font]
	return icon_font
var spotted:Dictionary={}
var next_scan:=0.0
func tick(game) -> void:
	if game.clock<next_scan:return
	next_scan=game.clock+.1
	for target in spotted.keys():
		if not game.players.has(target) or game.players[target].dead:spotted.erase(target)
	var seen:Dictionary={}
	for observer in game.players:
		if not game.classes.alive(observer):continue
		var team:int=game.players[observer].team
		if team not in [0,1]:continue
		var origin:Vector3=game.fighters[observer].position+Vector3.UP*game.fighters[observer].eye_height()
		var radius:float=100.0 if game.classes.role(observer)=="scout" else 50.0
		for target in game.players:
			if target==observer or game.players[target].dead or game.players[target].spectator or game.players[target].team==team or game.classes.cloaked(target):continue
			var key:=Vector2i(team,target)
			if seen.has(key):continue
			var body=game.fighters[target]
			if game.fighters[observer].position.distance_squared_to(body.position)>radius*radius:continue
			for height in [body.eye_height(),body.eye_height()*.55]:
				var end:Vector3=body.position+Vector3.UP*height
				if game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1)).is_empty():
					if not spotted.has(target):spotted[target]=[0.0,0.0]
					spotted[target][team]=game.clock+MEMORY
					seen[key]=true
					break
func visible(game,observer:int,target:int) -> bool:
	if observer==target or not game.players.has(observer) or not game.players.has(target):return false
	var viewer:Dictionary=game.players[observer];var player:Dictionary=game.players[target]
	if viewer.dead or viewer.spectator or player.dead or player.spectator:return false
	if viewer.team==player.team:
		return game.fighters[observer].position.distance_squared_to(game.fighters[target].position)<=10000.0
	if viewer.team not in [0,1] or game.classes.cloaked(target):return false
	return spotted.get(target,[0.0,0.0])[viewer.team]>game.clock
