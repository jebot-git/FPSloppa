extends "res://tools/vrm_to_mdl/profile/no_ai_arena.gd"
func _impacts(start: Vector3,ends: PackedVector3Array,weapon: int) -> void:
	var total_stamp:=Trace.begin()
	if is_instance_valid(district_worker):district_worker.event("_impacts",[start,ends,weapon])
	demos.event("_impacts",[start,ends,weapon])
	if headless or weapon<2: return
	var definition: Dictionary=armory.data(weapon).duplicate()
	if match_mode.kind=="tf" and weapon==9:definition.name="SNIPER RIFLE"
	if match_mode.kind=="tf" and weapon==7:definition.kind="hitscan"
	var visuals_stamp:=Trace.begin()
	_weapon_visuals().impacts(armory.effective(),start,ends,weapon,definition)
	Trace.end("impact_visuals",visuals_stamp)
	var impact_budget:=2
	for end in ends:
		if impact_budget>0:
			var direction: Vector3=(end-start).normalized()
			var ray_stamp:=Trace.begin()
			var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(end-direction*.08,end+direction*.08,1))
			Trace.end("impact_surface_ray",ray_stamp)
			if not hit.is_empty():
				var audio_stamp:=Trace.begin()
				spatial.play("impact",hit.position+hit.normal*.02,-17)
				Trace.end("impact_audio",audio_stamp)
				impact_budget-=1
	Trace.end("impact_effects",total_stamp)
func _weapon_visuals():
	if not is_instance_valid(variant_visuals):
		variant_visuals=preload("res://tools/vrm_to_mdl/profile/impact_visuals.gd").new();variant_visuals.name="WeaponEffects";add_child(variant_visuals);variant_visuals.illumination.connect(_weapon_illumination)
	return variant_visuals
