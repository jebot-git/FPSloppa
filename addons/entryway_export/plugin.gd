@tool
extends EditorPlugin
var exporter: EditorExportPlugin
var bluetooth_exporter: EditorExportPlugin
func _enter_tree() -> void:
	exporter=preload("res://addons/entryway_export/raw_assets.gd").new()
	add_export_plugin(exporter)
	bluetooth_exporter=preload("res://addons/bhaptics_native/android_export.gd").new()
	add_export_plugin(bluetooth_exporter)
func _exit_tree() -> void:
	remove_export_plugin(exporter)
	remove_export_plugin(bluetooth_exporter)
