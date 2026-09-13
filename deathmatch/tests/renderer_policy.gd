extends SceneTree
## Prevent exports silently regaining the unsupported OpenGL fallback.
func _initialize() -> void:
	var method: String=ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")
	var fallback: bool=ProjectSettings.get_setting_with_override("rendering/rendering_device/fallback_to_opengl3")
	assert(method=="mobile")
	assert(not fallback)
	assert(ProjectSettings.get_setting("rendering/rendering_device/driver.android")=="vulkan")
	print("RENDERER_POLICY_RESULT ",JSON.stringify({"method":method,"opengl_fallback":fallback,"passed":true}))
	quit()
