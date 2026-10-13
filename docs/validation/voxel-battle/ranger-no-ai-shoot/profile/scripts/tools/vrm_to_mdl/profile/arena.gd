extends "res://tools/voxel_battle/arena.gd"
const Trace=preload("res://tools/vrm_to_mdl/profile/trace.gd")
func create_bot_controller() -> Node:return preload("res://tools/vrm_to_mdl/profile/bots.gd").new()
func _physics_process(delta: float) -> void:
	var scope_started:=Trace.begin()
	super._physics_process(delta)
	Trace.end("arena_physics",scope_started)
func _server_tick(delta: float) -> void:
	var scope_started:=Trace.begin()
	super._server_tick(delta)
	Trace.end("server_tick",scope_started)
func _record_history() -> void:
	var scope_started:=Trace.begin()
	super._record_history()
	Trace.end("history",scope_started)
func _send_snapshot() -> void:
	var scope_started:=Trace.begin()
	super._send_snapshot()
	Trace.end("snapshot",scope_started)
func _check_water() -> void:
	var scope_started:=Trace.begin()
	super._check_water()
	Trace.end("water_killzone",scope_started)
func _collect(id: int) -> void:
	var scope_started:=Trace.begin()
	super._collect(id)
	Trace.end("pickups",scope_started)
func _update_projectiles(delta: float,movement_start: Dictionary={}) -> void:
	var scope_started:=Trace.begin()
	super._update_projectiles(delta,movement_start)
	Trace.end("projectiles",scope_started)
func _process(delta: float) -> void:
	var scope_started:=Trace.begin()
	super._process(delta)
	Trace.end("arena_render_process",scope_started)
