extends SceneTree
func _initialize() -> void:
	for method in ClassDB.class_get_method_list("OpenXRInterface"):
		if "refresh" in method.name: print(method)
	for property in ProjectSettings.get_property_list():
		if "foveation" in property.name or "eye_gaze" in property.name: print(property.name,"=",ProjectSettings.get_setting(property.name))
	quit()
