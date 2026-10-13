extends "res://tools/vrm_to_mdl/ranger_match.gd"
const Trace=preload("res://tools/vrm_to_mdl/profile/trace.gd")
const AnimationMetrics=preload("res://deathmatch/avatars/animation_metrics.gd")
func create_game():
	var scene=super.create_game();scene.set_script(preload("res://tools/vrm_to_mdl/profile/arena.gd"));return scene
func run() -> void:
	await super.run()
	Trace.enabled=true;AnimationMetrics.reset();AnimationMetrics.enabled=true
func _process(delta: float) -> bool:
	if Trace.enabled:Trace.commit()
	return super._process(delta)
func finish() -> void:
	Trace.enabled=false;AnimationMetrics.enabled=false
	var profile:={"scopes":Trace.result(),"avatar_scopes":AnimationMetrics.samples.duplicate(true),"limits":"Inclusive nested scopes; do not add parent and child times. Diagnostic overhead included. Frame buckets collect prior render callbacks and current physics ticks."}
	FileAccess.open(output+"/profile.json",FileAccess.WRITE).store_string(JSON.stringify(profile,"  "))
	await super.finish()
