extends Node
var game
var effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new()
var environment:WorldEnvironment
var saved_msaa:=-1
var saved_aa:=-1
func configure_aa(viewport:Viewport,active:bool)->void:
	if active:
		if viewport.msaa_3d!=Viewport.MSAA_DISABLED or saved_msaa<0:
			saved_msaa=viewport.msaa_3d;saved_aa=viewport.screen_space_aa
		viewport.msaa_3d=Viewport.MSAA_DISABLED
		if saved_msaa>0:viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	elif saved_msaa>=0:
		viewport.msaa_3d=saved_msaa;viewport.screen_space_aa=saved_aa;saved_msaa=-1;saved_aa=-1
func setup(arena) -> void:
	game=arena
	environment=game.get_node("Environment")
	if not environment.compositor:environment.compositor=Compositor.new()
	var effects:=environment.compositor.compositor_effects;effects.append(effect);environment.compositor.compositor_effects=effects
func _process(_delta:float) -> void:
	var id:int=game.multiplayer.get_unique_id()
	effect.enabled=game.active and game.night_vision.enabled_for(id)
	configure_aa(game.get_viewport(),effect.enabled)
	if not effect.enabled:game.night_vision.clear_local_effects();return
	var fraction:=1.0
	if game.battle_map and game.battle_map.lighting:fraction=game.battle_map.lighting.light_fraction()
	var eye:Transform3D=game.night_vision.visual_eye()
	effect.configure(lerpf(6000,1.3,fraction),game.classes.role(id)=="scout",game.night_vision.static_glare(eye),Time.get_ticks_msec()/1000.0,fraction,game.night_vision.flash_samples(eye))
func _exit_tree() -> void:
	effect.enabled=false
	if is_instance_valid(game):configure_aa(game.get_viewport(),false)
	if is_instance_valid(environment) and environment.compositor:
		var effects:=environment.compositor.compositor_effects;effects.erase(effect);environment.compositor.compositor_effects=effects
	RenderingServer.call_on_render_thread(effect.release)
