extends SceneTree
const Policy=preload("res://deathmatch/rendering_policy.gd")
func _initialize() -> void:
	var values: Dictionary={}
	for property in ProjectSettings.get_property_list():values[property.name]=ProjectSettings.get_setting(property.name)
	var error:=Policy.settings_error(values)
	if not error.is_empty():push_error(error);quit(1);return
	assert(Policy.supported("mobile","vulkan"))
	for backend in [["gl_compatibility","opengl3"],["mobile","d3d12"],["mobile","metal"],["forward_plus","vulkan"]]:
		assert(not Policy.supported(backend[0],backend[1]))
	assert(Policy.supported("gl_compatibility","dummy",true))
	for key in ["rendering/rendering_device/fallback_to_d3d12","rendering/rendering_device/fallback_to_opengl3"]:
		var bad:=values.duplicate();bad[key]=true;assert(not Policy.settings_error(bad).is_empty())
	var bad:=values.duplicate();bad["rendering/rendering_device/driver.windows"]="d3d12";assert(not Policy.settings_error(bad).is_empty())
	print("RENDERER_POLICY_RESULT ",JSON.stringify({"method":"mobile","driver":"vulkan","opengl_fallback":false,"d3d12_fallback":false,"passed":true}));quit()
