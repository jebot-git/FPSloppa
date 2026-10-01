extends PanelContainer
var rig
var book
var mode: Button
var speed: Label
var angle: Label
var controls: Button
var seat: Button
var stock: Button
var pump: Button
var notice: Label
var speed_up: Button
var angle_up: Button
func setup(value: Node) -> void:
	rig=value;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	var style=preload("res://deathmatch/ui/iron_theme.gd").panel()
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_content_margin(side,20)
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",6);add_child(column)
	var title:=Label.new();title.add_theme_font_override("font",preload("res://deathmatch/ui/BebasNeue-Regular.ttf"));title.text="VR CONTROLS";title.add_theme_font_size_override("font_size",30);column.add_child(title)
	controls=add_button(column,"",func():rig.left_controls=not rig.left_controls;rig.cycle_latched=false;save())
	seat=add_button(column,"",func():rig.seated=not rig.seated;rig.recenter();save())
	var weapons:=HBoxContainer.new();column.add_child(weapons)
	stock=add_button(weapons,"",func():rig.virtual_stock_enabled=not rig.virtual_stock_enabled;rig.virtual_stock.reset();save())
	pump=add_button(weapons,"",func():rig.pump_auto_transfer=not rig.pump_auto_transfer;rig.physical_reload.reset();save())
	pump.tooltip_text="M3: keep offhand grip held and release weapon grip to snap into the pump hold. Grip the weapon hand to take it back."
	var recenter=add_button(column,"RECENTER / CALIBRATE SEATED HEIGHT",func():rig.recenter();refresh())
	mode=add_button(column,"",func():rig.smooth_turn=not rig.smooth_turn;save())
	for setting in ["turn_speed","snap_angle"]:
		var label:=Label.new();label.text="Smooth turn speed" if setting=="turn_speed" else "Snap turn angle";column.add_child(label)
		var row:=HBoxContainer.new();column.add_child(row)
		var step:float=30 if setting=="turn_speed" else 5
		add_button(row,"−",adjust.bind(setting,-step))
		var number:=Label.new();number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;number.custom_minimum_size.x=260;row.add_child(number)
		var plus:=add_button(row,"+",adjust.bind(setting,step))
		if setting=="turn_speed":speed=number;speed_up=plus
		else:angle=number;angle_up=plus
	notice=Label.new();notice.text="Changes apply immediately and are saved for next time.";notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(notice)
	var space:=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(space)
	book=preload("res://deathmatch/ui/menu_pages.gd").new();add_child(book)
	book.add_page("home","VR CONTROLS")
	var turning: VBoxContainer=book.add_page("turning","TURNING")
	var handling: VBoxContainer=book.add_page("handling","WEAPON HANDLING")
	var posture: VBoxContainer=book.add_page("posture","HANDEDNESS & SEATING")
	book.link("home","turning","TURNING")
	book.link("home","handling","WEAPON HANDLING")
	book.link("home","posture","HANDEDNESS & SEATING")
	for child in column.get_children():
		if child in [title,notice,space] or child==weapons:continue
		child.reparent(posture if child in [controls,seat,recenter] else turning)
	stock.reparent(handling);pump.reparent(handling)
	notice.reparent(book);book.move_child(notice,book.back_button.get_index())
	column.queue_free();book.closed.connect(hide)
	refresh()
func add_button(parent: Node,label: String,action: Callable) -> Button:
	var b:=Button.new();b.text=label;b.custom_minimum_size=Vector2(90,52);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(action);parent.add_child(b);return b
func adjust(key: String,amount: float) -> void:
	rig.set(key,clampf(float(rig.get(key))+amount,30 if key=="turn_speed" else 15,360 if key=="turn_speed" else 90));save()
func save() -> void:
	var error:int=rig.save_turn_settings()
	notice.text="Saved. Changes apply immediately." if error==OK else "Could not save settings: "+error_string(error)
	refresh()
func refresh() -> void:
	controls.text="CONTROLS: "+("LEFT-HANDED · MOVE R / TURN L" if rig.left_controls else "RIGHT-HANDED · MOVE L / TURN R")
	seat.text="SEATED: "+("ON (suspended with body tracking)" if rig.seated else "OFF")
	stock.text="VIRTUAL STOCK: "+("ON" if rig.virtual_stock_enabled else "OFF")
	pump.text="M3 AUTO OFFHAND HOLD: "+("ON" if rig.pump_auto_transfer else "OFF")
	mode.text="TURN MODE: "+("SMOOTH" if rig.smooth_turn else "SNAP")
	speed.text="%.0f° / s"%rig.turn_speed;angle.text="%.0f°"%rig.snap_angle
func go_back() -> void:book.go_back()
func open() -> void:
	book.navigate("home");refresh();get_parent().move_child(self,-1);show()
