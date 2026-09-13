@tool
extends EditorExportPlugin
func _get_name() -> String: return "EntrywayExternalAssets"
func _export_file(path: String,_type: String,_features: PackedStringArray) -> void:
	if path.begins_with("res://addons/bhaptics_native/"):
		var desktop: bool=(_features.has("linux") or _features.has("windows")) and _features.has("x86_64")
		var android: bool=_features.has("android") and _features.has("arm64")
		if (not desktop and not android) or _features.has("dedicated_server"):skip();return
		var library:="fpsloppa-bhaptics-android.aar" if android else "fpsloppa_bhaptics_native.dll" if _features.has("windows") else "libfpsloppa_bhaptics_native.so"
		if not FileAccess.file_exists("res://addons/bhaptics_native/bin/"+library):skip();return
	if path.ends_with(".vrm") or path.begins_with("res://maps/") or path.begins_with("res://vrm/"):skip()
