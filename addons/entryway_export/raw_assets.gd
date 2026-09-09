@tool
extends EditorExportPlugin
func _get_name() -> String: return "EntrywayRawAssets"
func _export_begin(_features: PackedStringArray,_is_debug: bool,_path: String,_flags: int) -> void:
	# include_filter does not retain the originals of editor-imported VRMs.
	for manifest in ["res://deathmatch/avatars/models/manifest.json","res://deathmatch/maps/manifest.json"]:
		var rows=JSON.parse_string(FileAccess.get_file_as_string(manifest))
		for row in rows:
			add_file(row.path,FileAccess.get_file_as_bytes(row.path),false)
func _export_file(path: String,_type: String,_features: PackedStringArray) -> void:
	if path.ends_with(".vrm"): skip() # Runtime reads original bytes, not imported scenes.
