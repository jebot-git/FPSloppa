@tool
extends Node3D
@export var attributes: Dictionary = {}
func set_entity_dictionary(value: Dictionary) -> void:
	attributes = value.duplicate(true)
func set_import_value(_key: String, _value: String) -> bool:
	return true
