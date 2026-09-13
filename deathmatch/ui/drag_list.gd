extends "res://deathmatch/ui/drag_scroll.gd"
## Model selection uses release-to-select buttons, so a trigger drag never selects.
signal item_selected(index: int)
var column: VBoxContainer
var entries: Array[Button]=[]
var item_count: int:
	get:return entries.size()
func _ready() -> void:
	super._ready()
	column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(column)
func clear() -> void:
	for button in entries:column.remove_child(button);button.queue_free()
	entries.clear()
func add_item(text: String) -> void:
	var button:=Button.new();button.text=text;button.toggle_mode=true;button.custom_minimum_size.y=44;button.clip_text=true
	var index:=entries.size();entries.append(button);column.add_child(button)
	button.pressed.connect(func():select(index);item_selected.emit(index))
func select(index: int) -> void:
	for i in entries.size():entries[i].set_pressed_no_signal(i==index)
