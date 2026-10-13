extends "res://tools/vrm_to_mdl/profile_impacts.gd"
func create_game():
	var scene=super.create_game();scene.set_script(preload("res://tools/vrm_to_mdl/profile/pooled_arena.gd"));return scene
func prepare_avatars() -> bool:
	if not super.prepare_avatars():return false
	game._weapon_visuals() # Allocate the pool before the measured interval.
	return true
func run() -> void:
	await super.run()
	game.variant_visuals.reset_measurement()
func finish() -> void:
	var report: Dictionary=game.variant_visuals.pool_report()
	assert(report.invariants_ok and report.fallbacks==0)
	FileAccess.open(output+"/pool.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await super.finish()
