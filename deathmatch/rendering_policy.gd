extends RefCounted
## Check the active backend too: command-line overrides bypass project defaults.
static func supported(method: String,driver: String,headless: bool=false) -> bool:
	return headless or method=="mobile" and driver=="vulkan"
static func startup_error() -> String:
	if supported(RenderingServer.get_current_rendering_method(),RenderingServer.get_current_rendering_driver_name(),DisplayServer.get_name()=="headless"):return ""
	return "FPSloppa requires Vulkan with the Mobile renderer. OpenGL, Direct3D and other rendering backends are unsupported. Remove renderer overrides or launch with --rendering-method mobile --rendering-driver vulkan."
static func settings_error(values: Dictionary) -> String:
	for key in ["rendering/renderer/rendering_method","rendering/renderer/rendering_method.mobile"]:
		if values.get(key,values.get("rendering/renderer/rendering_method"))!="mobile":return key+" must be mobile"
	for suffix in ["",".windows",".linuxbsd",".android"]:
		var key: String="rendering/rendering_device/driver"+suffix
		# Godot omits default-valued settings in project.binary. Vulkan is
		# the pinned engine default on all supported target platforms.
		if values.get(key,"vulkan")!="vulkan":return key+" must be vulkan"
	for backend in ["opengl3","d3d12"]:
		var key: String="rendering/rendering_device/fallback_to_"+backend
		if values.get(key,true)!=false:return key+" must be disabled"
	return ""
