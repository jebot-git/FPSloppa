@tool
extends EditorExportPlugin
func _get_name() -> String: return "EntrywayExternalAssets"
func _export_file(path: String,_type: String,_features: PackedStringArray) -> void:
	if path.ends_with(".vrm") or path.begins_with("res://maps/") or path.begins_with("res://vrm/"):skip()
