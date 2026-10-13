extends "res://tools/ut99_avatar/benchmark_arena.gd"
const Meter=preload("res://tools/ut99_avatar/profile/meter.gd")
func _create_fighter(id:int) -> void:
	# Same production factory wiring, substituting only the timed subclass.
	var actor=preload("res://tools/ut99_avatar/profile/fighter.gd").new()
	var team:int=players[id].team
	actor.setup(id,players[id].name,match_mode.COLORS[team] if team>=0 else COLORS[players[id].color])
	actor.set_nametag(players[id].name,team,match_mode.COLORS[team] if team>=0 else COLORS[players[id].color])
	actor.movement_sound.connect(_fighter_movement_sound.bind(id));actor.quake_movement=true
	actor.configure_jetpack(jetpack_allowed() and not lobby.active());actor.spectator=players[id].spectator
	add_child(actor)
	if not headless:load("res://deathmatch/maps/filtering.gd").new().apply(actor,int(presentation.get("texture_filter",2)),false)
	fighters[id]=actor
func _weapon_visuals():
	if not is_instance_valid(variant_visuals):
		variant_visuals=preload("res://tools/ut99_avatar/profile/effects.gd").new();variant_visuals.name="WeaponEffects";add_child(variant_visuals);variant_visuals.illumination.connect(_weapon_illumination)
	return variant_visuals
func _physics_process(delta:float) -> void:
	var stamp:=Meter.begin("gameplay_tick")
	super._physics_process(delta);Meter.end("gameplay_tick",stamp)
func _server_tick(delta:float) -> void:
	var stamp:=Meter.begin("server_tick")
	super._server_tick(delta);Meter.end("server_tick",stamp)
func _process(delta:float) -> void:
	var stamp:=Meter.begin("game_scene_update")
	super._process(delta);Meter.end("game_scene_update",stamp)
func _trace(start:Vector3,end:Vector3,exclude:int,rewind:float=0.0,radius:float=0.0,movement_start:Dictionary={},candidates:Variant=null) -> Dictionary:
	var stamp:=Meter.begin("hit_trace")
	var result:Dictionary=super._trace(start,end,exclude,rewind,radius,movement_start,candidates);Meter.end("hit_trace",stamp)
	return result
func _shot_solution(id:int,offhand:bool=false) -> Dictionary:
	var stamp:=Meter.begin("shot_solution")
	var result:Dictionary=super._shot_solution(id,offhand);Meter.end("shot_solution",stamp)
	return result
func _impacts(start:Vector3,ends:PackedVector3Array,weapon:int) -> void:
	var stamp:=Meter.begin("impact_dispatch")
	super._impacts(start,ends,weapon);Meter.end("impact_dispatch",stamp)
func _variant_shot_fx(id:int,weapon:int,alternate:bool) -> void:
	var stamp:=Meter.begin("shot_fx_dispatch")
	super._variant_shot_fx(id,weapon,alternate);Meter.end("shot_fx_dispatch",stamp)
func _record_history() -> void:
	var stamp:=Meter.begin("history")
	super._record_history();Meter.end("history",stamp)
func _send_snapshot() -> void:
	var stamp:=Meter.begin("snapshot")
	super._send_snapshot();Meter.end("snapshot",stamp)
func _update_projectiles(delta:float,movement_start:Dictionary={}) -> void:
	var stamp:=Meter.begin("projectiles")
	super._update_projectiles(delta,movement_start);Meter.end("projectiles",stamp)
func _update_melee(id:int) -> void:
	var stamp:=Meter.begin("melee")
	super._update_melee(id);Meter.end("melee",stamp)
func _collect(id:int) -> void:
	var stamp:=Meter.begin("pickup_collection")
	super._collect(id);Meter.end("pickup_collection",stamp)
