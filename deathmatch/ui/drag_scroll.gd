extends ScrollContainer
## Shared pointer-drag and stick scrolling for desktop and VR menu pages.
var pressed:=false
var dragging:=false
var start:=Vector2.ZERO
var initial:=0
var button_states: Dictionary={}
var vr_mode_override:=false
var stick_remainder:=0.0
var joy_axes: Dictionary={}
func _ready() -> void:
	add_to_group("arena_scrolls")
	scroll_deadzone=100000
	update_mode()
	horizontal_scroll_mode=SCROLL_MODE_DISABLED
	visibility_changed.connect(func():
		if not is_visible_in_tree():cancel_drag();joy_axes.clear();stick_remainder=0.0)
func update_mode() -> void:
	var vr:=vr_mode_override or XRServer.primary_interface!=null and XRServer.primary_interface.is_initialized()
	vertical_scroll_mode=SCROLL_MODE_SHOW_NEVER if vr else SCROLL_MODE_AUTO
func _process(delta: float) -> void:
	update_mode()
	if not joy_axes.is_empty() and active_scroll(get_viewport(),Vector2.INF)!=self:joy_axes.clear()
	var axis:=0.0
	for value in joy_axes.values():
		if absf(value)>absf(axis):axis=value
	if axis!=0.0:scroll_active(get_viewport(),axis,delta)
func cancel_drag() -> void:
	for button in button_states:
		if is_instance_valid(button):button.set_pressed_no_signal(button_states[button])
	button_states.clear();pressed=false;dragging=false
func scroll_with_stick(axis: float,delta: float) -> void:
	if absf(axis)<.25:stick_remainder=0.0;return
	stick_remainder+=signf(axis)*(absf(axis)-.25)/.75*600.0*delta
	var pixels:=int(stick_remainder);stick_remainder-=pixels
	scroll_vertical+=pixels
static func scroll_active(viewport: Viewport,axis: float,delta: float) -> bool:
	var target=active_scroll(viewport,Vector2.INF)
	if not target:return false
	target.scroll_with_stick(axis,delta);return true
static func active_scroll(viewport: Viewport,point: Vector2):
	for selector in viewport.get_tree().get_nodes_in_group("arena_selectors"):
		if selector.get_viewport()==viewport and selector.popup.visible:return null
	var target=null
	var hovered:=viewport.gui_get_hovered_control()
	for scroll in viewport.get_tree().get_nodes_in_group("arena_scrolls"):
		if scroll.get_viewport()!=viewport or not scroll.is_visible_in_tree() or scroll.obscured():continue
		if point!=Vector2.INF and not scroll.get_global_rect().has_point(point):continue
		if hovered and (hovered==scroll or scroll.is_ancestor_of(hovered)):return scroll
		if target==null or scroll.is_greater_than(target):target=scroll
	return target
func obscured() -> bool:
	# A later full panel must not let its sticks/drag affect the panel below it.
	var node: Node=self
	while node.get_parent() and not node.get_parent() is Viewport:
		var siblings:=node.get_parent().get_children()
		for i in range(node.get_index()+1,siblings.size()):
			var other=siblings[i]
			if other is PanelContainer and other.is_visible_in_tree() and other.get_global_rect().encloses(get_global_rect()):return true
		node=node.get_parent()
	return false
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_Y]:
		if active_scroll(get_viewport(),Vector2.INF)==self:
			joy_axes[event.axis]=event.axis_value;get_viewport().set_input_as_handled()
		else:joy_axes.clear()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_scroll(get_viewport(),event.position)!=self:return
			var control:=get_viewport().gui_get_hovered_control()
			while control and control!=self:
				# Preserve direct manipulation of sliders, text, numeric values and bars.
				if control is Range or control is LineEdit or control is TextEdit:return
				control=control.get_parent_control()
			pressed=true;dragging=false;start=event.position;initial=scroll_vertical
			button_states.clear()
			for button in find_children("*","BaseButton",true,false):button_states[button]=button.button_pressed
		elif pressed:
			var was_dragging:=dragging
			cancel_drag()
			if was_dragging:get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pressed:
		var distance:float=(event.position.y-start.y)/maxf(.01,get_global_transform_with_canvas().get_scale().y)
		if absf(distance)>8:dragging=true
		if dragging:
			scroll_vertical=initial-roundi(distance);get_viewport().set_input_as_handled()
