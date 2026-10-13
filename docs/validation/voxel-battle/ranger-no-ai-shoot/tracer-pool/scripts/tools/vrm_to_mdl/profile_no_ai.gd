extends "res://tools/vrm_to_mdl/no_ai_shoot.gd"
const Trace=preload("res://tools/vrm_to_mdl/profile/trace.gd")
func create_game():
	var scene=super.create_game();scene.set_script(preload("res://tools/vrm_to_mdl/profile/no_ai_arena.gd"));return scene
func prepare_avatars() -> bool:
	if not super.prepare_avatars():return false
	game.variant_combat=preload("res://tools/vrm_to_mdl/profile/cs_combat.gd").new();game.variant_combat.setup(game)
	return true
func run() -> void:
	await super.run()
	Trace.enabled=true
func _process(delta: float) -> bool:
	if Trace.enabled:Trace.commit()
	return super._process(delta)
func finish() -> void:
	Trace.enabled=false
	FileAccess.open(output+"/profile.json",FileAccess.WRITE).store_string(JSON.stringify({"scopes":Trace.result(),"limits":"Inclusive scopes, diagnostic overhead; movement wrapper copies the original server loop and adds timers only."},"  "))
	await super.finish()
