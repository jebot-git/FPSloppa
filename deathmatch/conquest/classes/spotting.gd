extends RefCounted
const Attribution=preload("res://deathmatch/server/attribution.gd")
## Team-shared name/icon spotting. Authority checks world LOS at 10 Hz.
const ICONS={"shocktroop":"\ue000","scout":"\ue001","medic":"\ue002","technician":"\ue003"}
const GrassCover=preload("res://tools/voxel_battle/grass_cover.gd")
const GRASS_RANGE_SCALE:=.25
const MEMORY:=10.0
const RANGE:=75.0
const SCOUT_RANGE:=150.0
var icon_font:FontFile
func font() -> FontFile:
	if not icon_font:
		icon_font=load("res://deathmatch/conquest/classes/icons/class_icons.ttf")
		icon_font.fallbacks=[preload("res://deathmatch/ui/cq/assets/Unitblock.ttf"),ThemeDB.fallback_font]
	return icon_font
var spotted:Dictionary={}
var next_scan:=0.0
func tick(game) -> void:
	var token:=Attribution.begin("simulation.spotting")
	_attributed_tick(game)
	Attribution.end(token)

func _attributed_tick(game) -> void:
	if game.clock<next_scan:return
	next_scan=game.clock+.1
	for target in spotted.keys():
		if not game.players.has(target) or game.players[target].dead:spotted.erase(target)
	var seen:Dictionary={}
	var candidate_rows:Array=[];var actor_ids:Array=game.players.keys()
	var backend=preload("res://deathmatch/native/runtime.gd").backend()
	if backend:
		var positions:=PackedVector3Array();var teams:=PackedInt32Array();var observers:=PackedInt32Array();var targets:=PackedInt32Array();var radii:=PackedFloat64Array()
		for id in actor_ids:
			var state:Dictionary=game.players[id]
			positions.append(game.fighters[id].position);teams.append(state.team);observers.append(1 if game.classes.alive(id) else 0)
			targets.append(1 if not state.dead and not state.spectator and not game.classes.cloaked(id) else 0);radii.append(range_for(game,id))
		candidate_rows=backend.range_candidates(positions,teams,observers,targets,radii)
	for observer_index in actor_ids.size():
		var observer=actor_ids[observer_index]
		if not game.classes.alive(observer):continue
		var team:int=game.players[observer].team
		if team not in [0,1]:continue
		var origin:Vector3=game.fighters[observer].position+Vector3.UP*game.fighters[observer].eye_height()
		var radius:float=range_for(game,observer)
		if radius<=0:continue
		var candidates:Array=actor_ids
		if candidate_rows.size()==actor_ids.size():
			candidates=[]
			for index in candidate_rows[observer_index]:candidates.append(actor_ids[index])
		for target in candidates:
			if target==observer or game.players[target].dead or game.players[target].spectator or game.players[target].team==team or game.classes.cloaked(target):continue
			var key:=Vector2i(team,target)
			if seen.has(key):continue
			var body=game.fighters[target]
			var target_radius:float=radius*detection_scale(game,target)
			if game.fighters[observer].position.distance_squared_to(body.position)>target_radius*target_radius:continue
			for height in [body.eye_height(),body.eye_height()*.55]:
				var end:Vector3=body.position+Vector3.UP*height
				if Attribution.ray(game.get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(origin,end,1),"query.spotting.tick.ray").is_empty():
					if not spotted.has(target):spotted[target]=[0.0,0.0]
					spotted[target][team]=game.clock+MEMORY
					seen[key]=true
					break
func reveal(target:int,team:int,clock:float) -> void:
	if team not in [0,1]:return
	if not spotted.has(target):spotted[target]=[0.0,0.0]
	spotted[target][team]=maxf(spotted[target][team],clock+MEMORY)
func visible(game,observer:int,target:int) -> bool:
	if observer==target or not game.players.has(observer) or not game.players.has(target):return false
	var viewer:Dictionary=game.players[observer];var player:Dictionary=game.players[target]
	if viewer.dead or viewer.spectator or player.dead or player.spectator:return false
	if viewer.team==player.team:
		return game.fighters[observer].position.distance_squared_to(game.fighters[target].position)<=10000.0
	if viewer.team not in [0,1]:return false
	if game.classes.cloaked(target) and not game.recon_drone.detected(target,viewer.team):return false
	return spotted.get(target,[0.0,0.0])[viewer.team]>game.clock

static func range_for(game,id:int) -> float:
	var scout:bool=game.classes.role(id)=="scout"
	var state:Dictionary=game.classes.states.get(id,{})
	if state.get("nv",false) and state.get("nb",0.0)>game.clock:return 0.0
	var fraction:=1.0
	if "battle_map" in game and game.battle_map and game.battle_map.lighting:fraction=game.battle_map.lighting.light_fraction()
	var minimum:float=(100.0 if scout else 50.0) if state.get("nv",false) else (25.0 if scout else 15.0)
	return lerpf(minimum,SCOUT_RANGE if scout else RANGE,clampf(fraction,0,1))

static func detection_scale(game,target:int)->float:
	if not game.fighters.has(target):return 1.
	var body=game.fighters[target]
	if body.stance!="prone" or game.battery_tanks.mounted(target):return 1.
	return GRASS_RANGE_SCALE if GrassCover.contains(body.position) else 1.
