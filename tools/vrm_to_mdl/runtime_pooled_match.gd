extends "res://tools/vrm_to_mdl/no_ai_shoot.gd"
## Uninstrumented production FX path; no profile arena/visual overrides.
func prepare_avatars() -> bool:
	if not super.prepare_avatars():return false
	game._weapon_visuals()
	return true
func run() -> void:
	await super.run()
	game.variant_visuals.reset_pool_stats()
func finish() -> void:
	var report: Dictionary=game.variant_visuals.shape_pool_report()
	assert(report.invariants_ok and report.straight_tracers>0 and report.curved_tracers==0)
	FileAccess.open(output+"/pool.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await super.finish()
