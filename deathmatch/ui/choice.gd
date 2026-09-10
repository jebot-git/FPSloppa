extends VBoxContainer
## In-canvas selection: no native PopupMenu window or outside-click dismissal.
signal selected(value: String)
var trigger: Button
var popup: PanelContainer
var entries: VBoxContainer
var scroll: ScrollContainer
var drag_origin:=Vector2.ZERO
var drag_scroll:=0
var drag_pressed:=false
var dragging:=false
var vr_mode_override:=false
var value:=""
var items: Array=[]
var prompt:="SELECT"
func _init() -> void:
	trigger=Button.new();trigger.custom_minimum_size.y=48;trigger.text=prompt;add_child(trigger)
	popup=PanelContainer.new();popup.add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(8));var layer:=CanvasLayer.new();layer.layer=50;add_child(layer);layer.add_child(popup);popup.hide()
	popup.theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	scroll=ScrollContainer.new();scroll.scroll_deadzone=100000;scroll.gui_input.connect(drag_input);scroll.custom_minimum_size.y=156;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;popup.add_child(scroll)
	entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(entries)
	trigger.pressed.connect(open_popup)
func _ready() -> void:add_to_group("arena_selectors")
func open_popup() -> void:
	for other in get_tree().get_nodes_in_group("arena_selectors"):
		if other!=self and other.get_viewport()==get_viewport():other.popup.hide()
	popup.scale=trigger.get_global_transform_with_canvas().get_scale()
	popup.size=Vector2(trigger.size.x,156)
	popup.position=trigger.get_global_transform_with_canvas()*Vector2(0,trigger.size.y)
	popup.position.y=minf(popup.position.y,get_viewport_rect().size.y-popup.size.y*popup.scale.y-8)
	drag_pressed=false;dragging=false
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER if using_vr() else ScrollContainer.SCROLL_MODE_AUTO
	popup.show()
func _process(_delta: float) -> void:
	if not is_visible_in_tree():popup.hide()
func configure(options: Array,label: String) -> void:
	prompt=label
	if items==options:update_label();return
	items=options.duplicate(true)
	if not items.any(func(row):return row.id==value):value=""
	for child in entries.get_children():entries.remove_child(child);child.queue_free()
	for item in items:
		var b:=Button.new();b.text=item.title;b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.custom_minimum_size.y=44;entries.add_child(b)
		b.gui_input.connect(drag_input)
		b.pressed.connect(func():
			if not dragging:choose(item.id))
	update_label()
func choose(id: String) -> void:
	if not items.any(func(row):return row.id==id):return
	value=id;popup.hide();update_label();selected.emit(id)
func update_label() -> void:
	trigger.text=prompt+"  ▾"
	for item in items:
		if item.id==value:trigger.text=item.title+"  ▾"
	trigger.disabled=items.is_empty()
func clear_selection() -> void:
	value="";popup.hide();update_label()

func using_vr() -> bool:
	return vr_mode_override or XRServer.primary_interface!=null and XRServer.primary_interface.is_initialized()
func drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_origin=event.global_position;drag_scroll=scroll.scroll_vertical;drag_pressed=true;dragging=false
		else:drag_pressed=false
	elif event is InputEventMouseMotion and drag_pressed:
		var distance: float=(event.global_position.y-drag_origin.y)/maxf(.01,popup.scale.y)
		if absf(distance)>8:dragging=true
		if dragging:scroll.scroll_vertical=drag_scroll-roundi(distance)
