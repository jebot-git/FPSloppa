@tool
extends EditorExportPlugin
func _get_name() -> String:return "FPSloppaNativeBluetooth"
func _supports_platform(platform: EditorExportPlatform) -> bool:return platform is EditorExportPlatformAndroid
func _get_android_libraries(_platform: EditorExportPlatform,_debug: bool) -> PackedStringArray:
	var path:="res://addons/bhaptics_native/bin/fpsloppa-bhaptics-android.aar"
	return PackedStringArray([path]) if FileAccess.file_exists(path) else PackedStringArray()
