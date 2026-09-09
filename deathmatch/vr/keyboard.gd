extends XRToolsVirtualKeyboard2D
## Route text to the menu's focused viewport (including embedded dialogs).
## Global Input.parse_input_event during a touch callback can lose the key to
## another viewport's handled state. Deliver after the pointer event completes.
var focus_target: Callable

func on_key_pressed(scan_code_text: String, unicode: int, shift: bool) -> void:
	if not focus_target.is_valid(): return
	var target: Control=focus_target.call()
	if not (target is LineEdit or target is TextEdit): return
	var event := InputEventKey.new()
	event.keycode=OS.find_keycode_from_string(scan_code_text)
	event.physical_keycode=event.keycode
	event.unicode=unicode if unicode else event.keycode
	event.shift_pressed=shift
	event.pressed=true
	_deliver.call_deferred(target,event)
	if _shift_down:
		_shift_down=false
		_update_visible()

func _deliver(target: Control,event: InputEventKey) -> void:
	if not is_instance_valid(target) or not target.has_focus() or not target.is_visible_in_tree(): return
	var viewport := target.get_viewport()
	viewport.push_input(event,true)
	var release: InputEventKey=event.duplicate()
	release.pressed=false
	viewport.push_input(release,true)
