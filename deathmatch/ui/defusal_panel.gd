extends CanvasLayer
const View=preload("res://deathmatch/ui/weapon_wheel.gd")
const Shop=preload("res://deathmatch/counterstrike/buy_wheel.gd")
const WheelState=preload("res://deathmatch/vr/weapon_wheel_state.gd")
var rules
var opened:=false
var tribes:=false
var tribes_shop=preload("res://deathmatch/tribes/buy_wheel.gd").new()
var page:=0
var view: Control
var label: Label
var root: Control
var hover:=-1
var shade: ColorRect
func setup(value):
	rules=value;layer=6;tribes=rules==rules.game.match_mode.tribes
	shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.035,.045,.055,.94);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade);shade.hide()
	root=Control.new();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	view=View.new();view.size=View.SIZE;root.add_child(view);view.mouse_filter=Control.MOUSE_FILTER_STOP
	view.gui_input.connect(mouse_input)
	label=Label.new();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",21);root.add_child(label)
	root.hide()
func toggle():
	opened=not opened;page=0;hover=-1
	if tribes and opened:tribes_shop.open(rules.game.local_state())
	if opened:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	else:restore_mouse()
	refresh()
func restore_mouse():
	if rules.game.active and not rules.game.menu_open and not rules.game.demos.playing:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func close():
	if opened:opened=false;restore_mouse()
	root.hide()
	shade.hide()
func refresh():
	var game=rules.game;var id: int=game.multiplayer.get_unique_id()
	if opened and (not (rules.enabled() if tribes else rules.can_buy(id)) or game.menu_open or game.demos.playing):close()
	root.visible=opened
	shade.visible=opened
	if not opened:return
	var scale_value:=minf(get_viewport().get_visible_rect().size.y/980.0,.9)
	root.scale=Vector2.ONE*scale_value;root.position=(get_viewport().get_visible_rect().size-View.SIZE*scale_value)*.5
	var entries: Array=tribes_shop.rows(rules,id) if tribes else Shop.rows(rules,id,page)
	for entry in entries:entry.desktop=true
	view.set_content(entries,hover,-1,false)
	label.position=Vector2(0,-32);label.size=Vector2(900,30)
	label.text="CHOOSE EQUIPMENT · B / ESC CLOSE · "+("INVENTORY STATION: EQUIP NOW" if rules.can_refit(id) else "FAVOURITES: BUY AT A FRIENDLY STATION" if rules.base_ctf() else "QUEUED FOR NEXT RESPAWN") if tribes else "CLICK TO BUY · B / ESC CLOSE · %ds · %s"%[ceili(maxf(0,rules.phase_end-game.clock)),rules.account(id).notice]
func mouse_input(event: InputEvent):
	if event is InputEventMouseMotion:
		var offset: Vector2=event.position-View.CENTER
		hover=WheelState.sector(Vector2(offset.x,-offset.y),view.rows.size()) if offset.length()>View.INNER and offset.length()<View.OUTER else -1;refresh()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if hover>=0 and hover<view.rows.size():select(int(view.rows[hover].id))
		view.accept_event()
func select(item: int):
	if tribes:
		if tribes_shop.select(item,rules,rules.game.multiplayer.get_unique_id()):close();return
		hover=-1;refresh();return
	if Shop.GROUPS.has(item):page=item
	elif item==Shop.BACK:page=0
	else:rules.send("buy",item)
	hover=-1;refresh()
func handle_key(code: int) -> bool:
	if code in [KEY_B,KEY_ESCAPE]:close();return true
	if code>=KEY_1 and code<=KEY_9:
		var index:=code-KEY_1
		if index<view.rows.size():select(view.rows[index].id)
		return true
	return false
func _input(event: InputEvent):
	if opened and event is InputEventKey and event.pressed and not event.echo and handle_key(event.physical_keycode):get_viewport().set_input_as_handled()
