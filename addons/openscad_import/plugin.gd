@tool
extends EditorPlugin
var importer: EditorImportPlugin
func _enter_tree() -> void:
	importer=preload("res://addons/openscad_import/importer.gd").new();add_import_plugin(importer)
func _exit_tree() -> void:remove_import_plugin(importer);importer=null
