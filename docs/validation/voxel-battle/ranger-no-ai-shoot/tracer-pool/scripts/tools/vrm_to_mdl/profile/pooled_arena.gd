extends "res://tools/vrm_to_mdl/profile/impact_arena.gd"
func _weapon_visuals():
	if not is_instance_valid(variant_visuals):
		variant_visuals=preload("res://tools/vrm_to_mdl/profile/pooled_visuals.gd").new();variant_visuals.name="WeaponEffects";add_child(variant_visuals);variant_visuals.illumination.connect(_weapon_illumination)
	return variant_visuals
