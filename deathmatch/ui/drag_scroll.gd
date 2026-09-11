extends ScrollContainer
## Trigger dragging across child controls without turning a drag into a click.
var pressed:=false
var dragging:=false
var start:=Vector2.ZERO
var initial:=0
var vr_mode_override:=false
func _ready() -> void:
	scroll_deadzone=100000
	horizontal_scroll_mode=SCROLL_MODE_DISABLED
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():pressed=false;return
	var vr:=vr_mode_override or XRServer.primary_interface!=null and XRServer.primary_interface.is_initialized()
	if not vr:return
	vertical_scroll_mode=SCROLL_MODE_SHOW_NEVER
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			for selector in get_tree().get_nodes_in_group("arena_selectors"):
				if selector.get_viewport()==get_viewport() and selector.popup.visible:return
			pressed=get_global_rect().has_point(event.position);dragging=false
			start=event.position;initial=scroll_vertical
		elif pressed:
			pressed=false
			if dragging:
				for button in find_children("*","BaseButton",true,false):button.set_pressed_no_signal(false)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pressed:
		var distance:float=(event.position.y-start.y)/maxf(.01,get_global_transform_with_canvas().get_scale().y)
		if absf(distance)>8:dragging=true
		if dragging:
			scroll_vertical=initial-roundi(distance)
			get_viewport().set_input_as_handled()
