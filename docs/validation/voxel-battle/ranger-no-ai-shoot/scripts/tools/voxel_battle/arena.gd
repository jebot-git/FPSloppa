extends "res://deathmatch/arena.gd"
const BattleMap=preload("res://tools/voxel_battle/map.gd")
var battle_map
func _load_map(_map_id: String) -> bool:
	if is_instance_valid(battle_map):return true
	for child in $Map.get_children():child.free()
	battle_map=BattleMap.new();battle_map.name="VoxelValley";$Map.add_child(battle_map)
	battle_map.build(not headless)
	spawn_points.assign(battle_map.spawn_positions);spawn_yaws.clear()
	for i in spawn_points.size():spawn_yaws.append(0.0 if i%2==0 else PI)
	current_map="voxel_valley";map_title="Valley Junction";map_sha="local-procedural-valley-v2"
	fall_limit=-12
	var runtime=preload("res://deathmatch/maps/runtime.gd").new();runtime.name="MapRuntime";$Map.add_child(runtime)
	runtime.game=self;runtime.triggers.setup(runtime,[])
	return true
func create_bot_controller() -> Node:
	return preload("res://tools/voxel_battle/bots.gd").new()
func jetpack_allowed() -> bool:return true
func _spawn(id: int) -> void:
	super._spawn(id)
	if players[id].spectator:return
	fighters[id].update_height(1.70,true)
	if armory.kind=="cs" and not players[id].has("cs_sniper"):
		var team: int=players[id].team
		var ordinal: int=players.values().filter(func(s):return s.team==team).size()-1
		players[id].cs_sniper=ordinal%4==0
	if players[id].get("cs_sniper",false):
		players[id].owned=[0,2,9];players[id].weapon=9;players[id].ammo=[0,7,10,0];players[id].cs_reserve=[0,35,30,0]
func _update_crouch(id: int,pose: Dictionary,command: Dictionary={}) -> void:
	super._update_crouch(id,pose,command)
	if not players[id].crouch and not players[id].prone and pose.is_empty():fighters[id].update_height(1.70)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_check_water()
func _check_water() -> void:
	if not multiplayer.is_server() or not is_instance_valid(battle_map):return
	for id in players:
		if not players[id].dead and not players[id].spectator and battle_map.Landscape.in_water(fighters[id].position):
			_damage(id,id,100000,"WATER",true)
