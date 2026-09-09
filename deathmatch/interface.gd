extends CanvasLayer
const W = preload("res://deathmatch/weapons.gd")
const Profile = preload("res://deathmatch/profile.gd")
var game
var map_import: Button
var map_choice: OptionButton
var avatar_picker: Window
var avatar_status: Label
var menu: Control
var status: Label
var chat: LineEdit
var hud: Control
var vitals: Label
var ammo: Label
var weapon: Label
var match_status: Label
var kill_feed: Label
var center_message: Label
var toast_label: Label
var damage: ColorRect
var hit: Label
var scoreboard: PanelContainer
var scores: Label
var name_field: LineEdit
var address_field: LineEdit
var port_field: SpinBox
var frags: SpinBox
var minutes: SpinBox
var vr_actions: HBoxContainer
var controls: Label
var toast_until := 0.0
var resume: Button
var leave: Button
var launch_buttons: Array = []
var voice_button: Button

func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("45555b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

func text(parent: Node,value: String,size: int = 16,color: Color = Color("dce3df")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func setup(arena: Node) -> void:
	game = arena
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_status = text(hud,"",17)
	match_status.position = Vector2(24,18)
	avatar_status = text(hud,"",13,Color("a1c7c0"))
	avatar_status.position = Vector2(24,45)
	kill_feed = text(hud,"",15,Color("becbc8"))
	kill_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kill_feed.offset_left = -580
	kill_feed.offset_top = 20
	kill_feed.offset_right = -24
	kill_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bottom := PanelContainer.new()
	hud.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -98
	bottom.add_theme_stylebox_override("panel",panel_style(Color(.025,.04,.045,.92)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",36)
	bottom.add_child(row)
	vitals = text(row,"",26,Color("d9e8df"))
	vitals.custom_minimum_size.x = 310
	weapon = text(row,"",18,Color("e7bb70"))
	weapon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo = text(row,"",29,Color("f4d29c"))
	ammo.custom_minimum_size.x = 230
	var cross := text(hud,"+",23,Color(.88,.94,.91,.75))
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.offset_left = -7
	cross.offset_top = -17
	hit = text(hud,"×",32,Color("ffdc90"))
	hit.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hit.offset_left = -10
	hit.offset_top = -24
	center_message = text(hud,"",26,Color("f3e4bc"))
	center_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_message.offset_left = -380
	center_message.offset_right = 380
	center_message.offset_top = 55
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = text(hud,"",17,Color("a1d9c6"))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -400
	toast_label.offset_right = 400
	toast_label.offset_top = -140
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage = ColorRect.new()
	damage.color = Color(1,.02,0,0)
	hud.add_child(damage)
	damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scoreboard = PanelContainer.new()
	hud.add_child(scoreboard)
	scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scoreboard.offset_left = -340
	scoreboard.offset_right = 340
	scoreboard.offset_top = -215
	scoreboard.offset_bottom = 140
	scoreboard.add_theme_stylebox_override("panel",panel_style(Color(.02,.035,.04,.97)))
	scores = text(scoreboard,"",21)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono","monospace"])
	scores.add_theme_font_override("font",mono)
	chat = LineEdit.new()
	hud.add_child(chat)
	chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	chat.offset_left = 24
	chat.offset_right = -24
	chat.offset_top = -178
	chat.offset_bottom = -142
	chat.placeholder_text = "Say something · Enter sends · Esc cancels"
	chat.max_length = 140
	chat.visible = false
	chat.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			chat.text = ""
			chat.release_focus()
			chat.hide()
			if game.is_vr(): show_menu(true)
			get_viewport().set_input_as_handled()
	)
	chat.text_submitted.connect(func(value):
		game.chat_send(value)
		chat.text = ""
		chat.release_focus()
		chat.hide()
		if game.is_vr(): show_menu(true)
		get_viewport().set_input_as_handled()
	)
	_build_menu(root)
	show_menu(true)

func _build_menu(root: Control) -> void:
	menu = Control.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(.015,.026,.03,.91)
	menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650,0)
	panel.add_theme_stylebox_override("panel",panel_style(Color("122027")))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	text(column,"U A C   /   C O M B A T   S I M U L A T I O N",13,Color("8aafa9"))
	text(column,"ENTRYWAY",40,Color("efddba"))
	text(column,"DEATHMATCH  /  2–8 PLAYERS",17,Color("c39860"))
	text(column,"Fast movement. No magazines. Every pickup matters.",15,Color("aebdbb"))
	var identity := HBoxContainer.new()
	column.add_child(identity)
	text(identity,"CALLSIGN",14).custom_minimum_size.x = 110
	name_field = LineEdit.new()
	name_field.text = game.nickname
	name_field.max_length = 18
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(name_field)
	name_field.focus_exited.connect(save_preferences)
	name_field.text_submitted.connect(func(_value): name_field.release_focus())
	name_field.tooltip_text = "Saved for your next match. In VR, select this field to open the keyboard."
	avatar_picker = preload("res://deathmatch/avatars/picker.gd").new()
	add_child(avatar_picker)
	avatar_picker.setup(game.avatars)
	button(identity,"MODEL…",avatar_picker.open)
	if game.voice and game.voice.panel:
		game.voice.panel.reparent(root)
		game.voice.panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		voice_button=button(identity,"VOICE…",game.voice.panel.open)
	var connection := HBoxContainer.new()
	column.add_child(connection)
	text(connection,"HOST ADDRESS",14).custom_minimum_size.x = 110
	address_field = LineEdit.new()
	address_field.text = "127.0.0.1"
	address_field.placeholder_text = "IP or hostname"
	address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection.add_child(address_field)
	port_field = SpinBox.new()
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.value = 7777
	connection.add_child(port_field)
	var map_row := HBoxContainer.new()
	column.add_child(map_row)
	text(map_row,"ARENA",14).custom_minimum_size.x=110
	map_choice=OptionButton.new()
	map_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for row in game.map_catalog: map_choice.add_item(row.title)
	map_choice.item_selected.connect(func(index): game.selected_map=game.map_catalog[index].id)
	map_row.add_child(map_choice)
	var bsp_dialog:=FileDialog.new()
	bsp_dialog.access=FileDialog.ACCESS_FILESYSTEM
	bsp_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	bsp_dialog.filters=PackedStringArray(["*.bsp ; Quake I BSP map"])
	add_child(bsp_dialog)
	bsp_dialog.file_selected.connect(_import_bsp)
	map_import=button(map_row,"IMPORT BSP…",func(): bsp_dialog.popup_centered_ratio(.8))
	var rules := HBoxContainer.new()
	rules.add_theme_constant_override("separation",10)
	column.add_child(rules)
	text(rules,"HOST RULES",14).custom_minimum_size.x = 100
	frags = SpinBox.new()
	frags.min_value = 1
	frags.max_value = 100
	frags.value = 20
	rules.add_child(frags)
	text(rules,"frags",14)
	minutes = SpinBox.new()
	minutes.min_value = 1
	minutes.max_value = 60
	minutes.value = 10
	rules.add_child(minutes)
	text(rules,"minutes",14)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var host := button(actions,"HOST MATCH",func(): game.start_host(name_field.text,int(port_field.value),int(frags.value),int(minutes.value),false))
	var join := button(actions,"JOIN MATCH",func(): game.start_join(name_field.text,address_field.text,int(port_field.value)))
	var training := button(actions,"PRACTICE VS BOTS",func(): game.start_host(name_field.text,0,int(frags.value),int(minutes.value),true))
	launch_buttons = [host,join,training]
	resume = button(column,"RESUME",func():
		game.menu_open = false
		show_menu(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game.is_vr() else Input.MOUSE_MODE_CAPTURED
	)
	leave = button(column,"LEAVE MATCH",func(): game.disconnect_game())
	vr_actions=HBoxContainer.new()
	column.add_child(vr_actions)
	button(vr_actions,"CHAT",func():
		if game.active:
			show_menu(false)
			open_chat())
	button(vr_actions,"RECENTER VR",func():
		if game.is_vr(): game.xr_rig.recenter())
	button(vr_actions,"SWAP GUN HAND",func():
		if game.is_vr(): game.xr_rig.left_handed=not game.xr_rig.left_handed)
	button(vr_actions,"TURN SETTINGS…",func():
		if game.is_vr(): game.xr_rig.turn_panel.open())
	var tracking_actions:=HBoxContainer.new()
	column.add_child(tracking_actions)
	button(tracking_actions,"CALIBRATE BODY",func():
		if game.is_vr(): game.xr_rig.tracking.calibrate(); status.text=game.xr_rig.tracking.status)
	button(tracking_actions,"SLIMEVR OSC ON / OFF",func():
		if game.is_vr(): game.xr_rig.tracking.toggle_osc(); status.text=game.xr_rig.tracking.status)
	button(tracking_actions,"BODY TRACKING ON / OFF",func():
		if game.is_vr(): game.xr_rig.tracking.enabled=not game.xr_rig.tracking.enabled)
	status = text(column,"LAN / direct IP · Internet hosts must forward the selected UDP port.",14,Color("a1c7c0"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(590,32)
	controls=text(column,"WASD  Move   SHIFT  Walk   MOUSE  Aim / fire   1–7 / WHEEL  Weapons\nE  Door   F  Weapon whip   TAB  Scores   ENTER  Chat   ESC  Menu\nSPACE  Jump / swim in Quake maps; respawn when dead.",13,Color("859b9e"))
	button(column,"QUIT",func(): get_tree().quit())
	var config := ConfigFile.new()
	if config.load(Profile.config_path())==OK:
		address_field.text = str(config.get_value("network","address","127.0.0.1"))
	if not FileAccess.file_exists(Profile.config_path()): save_preferences()

func save_preferences() -> void:
	name_field.text = Profile.clean(name_field.text,Profile.system_name())
	game.nickname = name_field.text
	var error := Profile.save(name_field.text,address_field.text)
	if error!=OK: game.status("Could not save callsign: "+error_string(error))

func button(parent: Node,title: String,action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size.y = 34
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size",15)
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func show_menu(open: bool) -> void:
	menu.visible = open
	resume.visible = game.active
	leave.visible = game.active
	for b in launch_buttons: b.visible = not game.active
	if not open:
		if game.voice and game.voice.panel: game.voice.panel.hide()
		save_preferences()

func open_chat() -> void:
	chat.show()
	chat.grab_focus()
	game.fire_down = false

func toast(message: String) -> void:
	toast_label.text = message
	toast_until = game.clock+2.5

func _process(_delta: float) -> void:
	if game==null: return
	map_choice.disabled=game.active
	map_import.disabled=game.active
	vr_actions.visible=game.is_vr()
	if game.is_vr(): controls.text="LEFT STICK Move · RIGHT STICK Turn / ↑↓ weapons\nTRIGGER Fire / select · RIGHT A Jump / respawn\nLEFT X/A Use · RIGHT B Menu · LEFT Y/B Scores"
	hud.visible = game.active
	avatar_status.text = game.avatars.message
	if not game.active: return
	var state: Dictionary = game.local_state()
	if state.is_empty(): return
	var d: Dictionary = W.DATA[state.weapon]
	vitals.text = "%03d  HEALTH    %03d  ARMOR" % [state.hp,state.armor]
	weapon.text = d.name+"\n"+"B %d   S %d   R %d   C %d" % [state.ammo[0],state.ammo[1],state.ammo[2],state.ammo[3]]
	ammo.text = ("∞" if d.ammo<0 else str(state.ammo[d.ammo]))+"  "+("MELEE" if d.ammo<0 else W.AMMO_NAMES[d.ammo])
	match_status.text = "%s   ·   %02d:%02d   ·   %d FRAGS   ·   %d PLAYERS   ·   %d ms" % [game.map_title.to_upper(),int(game.round_left)/60,int(game.round_left)%60,game.frag_limit,game.players.size(),game.local_ping]
	if game.voice and game.voice.transmitting: match_status.text += "   ·   MIC LIVE"
	var lines := PackedStringArray()
	for entry in game.feed:
		if entry.until>game.clock: lines.append(entry.text)
	kill_feed.text = "\n".join(lines)
	hit.visible = game.hit_flash>0
	damage.color.a = game.hurt_flash*.28
	toast_label.visible = game.clock<toast_until
	center_message.text = ""
	if game.intermission>0:
		center_message.text = game.round_message+"\nNext round in %d" % ceili(game.intermission)
	elif state.dead:
		var wait: float = maxf(0,state.respawn_at-game.clock)
		center_message.text = "FRAGGED\n"+("Respawn in %.1f" % wait if wait>0 else "Fire or Space to respawn")
	elif state.invulnerable>game.clock:
		center_message.text = "SPAWN PROTECTION"
	scoreboard.visible = not game.menu_open and (Input.is_physical_key_pressed(KEY_TAB) or (game.is_vr() and game.xr_rig.scores) or game.intermission>0)
	if scoreboard.visible:
		var sorted: Array = game.players.values().duplicate()
		sorted.sort_custom(func(a,b): return a.kills>b.kills)
		var board := "ENTRYWAY  /  DEATHMATCH\n\nMARINE                       FRAGS    DEATHS    PING\n"
		for player in sorted:
			board += "\n%-23s    %3d       %3d       %3d" % [player.name,player.kills,player.deaths,player.ping]
		scores.text = board

func _import_bsp(path: String) -> void:
	status.text="Importing Quake BSP geometry and textures…"
	await get_tree().process_frame
	var row: Dictionary=game.Maps.import_custom(path)
	if row.has("error"):
		status.text=row.error
		return
	game.map_catalog=game.Maps.catalog()
	map_choice.clear()
	for i in range(game.map_catalog.size()):
		map_choice.add_item(game.map_catalog[i].title)
		if game.map_catalog[i].id==row.id: map_choice.select(i)
	game.selected_map=row.id
	status.text="Map imported. Joining clients will download it from the host."

func refresh_maps() -> void:
	map_choice.clear()
	for row in game.map_catalog:
		map_choice.add_item(row.title)
		if row.id==game.selected_map: map_choice.select(map_choice.item_count-1)
