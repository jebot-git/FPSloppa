extends Node
var game
var effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new()
var environment:WorldEnvironment
func setup(arena) -> void:
	game=arena
	environment=game.get_node("Environment")
	if not environment.compositor:environment.compositor=Compositor.new()
	var effects:=environment.compositor.compositor_effects;effects.append(effect);environment.compositor.compositor_effects=effects
func _process(_delta:float) -> void:
	var id:int=game.multiplayer.get_unique_id()
	effect.enabled=game.active and game.night_vision.enabled_for(id)
	if not effect.enabled:return
	var fraction:=1.0
	if game.battle_map and game.battle_map.lighting:fraction=game.battle_map.lighting.light_fraction()
	effect.configure(lerpf(6000,1.3,fraction),game.classes.role(id)=="scout",clampf(game.night_vision.blind_for(id)/.6,0,1),Time.get_ticks_msec()/1000.0)
func _exit_tree() -> void:
	effect.enabled=false
	if is_instance_valid(environment) and environment.compositor:
		var effects:=environment.compositor.compositor_effects;effects.erase(effect);environment.compositor.compositor_effects=effects
	RenderingServer.call_on_render_thread(effect.release)
