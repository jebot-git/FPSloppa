extends "res://tools/voxel_battle/bots.gd"
const Trace=preload("res://tools/vrm_to_mdl/profile/trace.gd")
func setup(arena: Node) -> void:
	navigation=preload("res://tools/vrm_to_mdl/profile/navigation.gd").new()
	super.setup(arena)
func tick(delta: float) -> void:
	var scope_started:=Trace.begin()
	super.tick(delta)
	Trace.end("bot_tick",scope_started)
func perceive(id: int,brain: Dictionary) -> void:
	var scope_started:=Trace.begin()
	super.perceive(id,brain)
	Trace.end("bot_perception",scope_started)
func plan(id: int,brain: Dictionary) -> void:
	var scope_started:=Trace.begin()
	super.plan(id,brain)
	Trace.end("bot_planning",scope_started)
func combat(id: int,brain: Dictionary,delta: float=.2) -> void:
	var scope_started:=Trace.begin()
	super.combat(id,brain,delta)
	Trace.end("bot_combat",scope_started)
func steer(id: int,brain: Dictionary,delta: float) -> void:
	var scope_started:=Trace.begin()
	super.steer(id,brain,delta)
	Trace.end("bot_steering",scope_started)
func jetpack_steer(id: int,brain: Dictionary) -> void:
	var scope_started:=Trace.begin()
	super.jetpack_steer(id,brain)
	Trace.end("bot_jetpack_safety",scope_started)
