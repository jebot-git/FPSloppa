extends "res://deathmatch/arena.gd"
const BattleMap=preload("res://tools/voxel_battle/map.gd")
var battle_map
func _load_map(_map_id: String) -> bool:
	if is_instance_valid(battle_map):return true
	for child in $Map.get_children():child.free()
	battle_map=BattleMap.new();battle_map.name="VoxelJungle";$Map.add_child(battle_map)
	battle_map.build(not headless)
	spawn_points.assign(battle_map.spawn_positions);spawn_yaws.clear()
	for i in spawn_points.size():spawn_yaws.append(0.0 if i%2==0 else PI)
	current_map="voxel_jungle";map_title="Jungle Frontier";map_sha="local-procedural-jungle-8km2-v1"
	fall_limit=-48
	var runtime=preload("res://deathmatch/maps/runtime.gd").new();runtime.name="MapRuntime";$Map.add_child(runtime)
	runtime.game=self;runtime.process_physics_priority=-50
	runtime.contents=preload("res://tools/voxel_battle/water_contents.gd").new();runtime.has_contents=true
	runtime.triggers.setup(runtime,[])
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

func _create_fighter(id:int) -> void:
	super._create_fighter(id)
	fighters[id].stroke_only_water=true
func water_view_raise(actor,eye_height:float) -> float:
	if not actor.underwater:return 0.0
	var water:=BattleMap.Landscape.water_sample(actor.position.x,actor.position.z)
	return maxf(0,water.y+.12-(actor.render_position().y+eye_height)) if water.x>.5 else 0.0

func _process(delta:float) -> void:
	super._process(delta)
	if headless or not is_instance_valid(battle_map):return
	var eye:Camera3D=world_view_camera()
	if eye:battle_map.update_view(eye)

func world_view_camera() -> Camera3D:return xr_rig.head if is_vr() else camera
