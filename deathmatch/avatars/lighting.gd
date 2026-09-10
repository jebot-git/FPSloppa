extends RefCounted
## One-time material policy; no per-frame light queries or extra render passes.
static func prepare(material: Material) -> void:
	if material.has_meta("arena_lighting_prepared"):return
	material.set_meta("arena_lighting_prepared",true)
	if material is ShaderMaterial and material.shader and material.shader.resource_path.contains("/mtoon"):
		material.set_shader_parameter("_ArenaLightingEnabled",true)
		material.set_shader_parameter("_ArenaFill",.10)
		material.set_shader_parameter("_ArenaDirect",.60)
		material.set_shader_parameter("_ArenaLightLimit",.55)
	elif material is StandardMaterial3D:
		# VRMs may use regular glTF/PBR or KHR_materials_unlit instead of MToon.
		# Retain the material type so VRM material-colour/UV expression tracks work.
		material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.metallic=minf(material.metallic,.25)
		material.roughness=maxf(material.roughness,.65)
		material.rim_enabled=false
		if material.emission_enabled:
			material.emission_energy_multiplier=minf(material.emission_energy_multiplier,.25)
			material.emission=Color(minf(material.emission.r,.4),minf(material.emission.g,.4),minf(material.emission.b,.4),material.emission.a)
		else:
			material.emission_enabled=true
			material.emission_texture=material.albedo_texture
			material.emission=Color(material.albedo_color.r*.08,material.albedo_color.g*.08,material.albedo_color.b*.08,1)
			material.emission_energy_multiplier=1
