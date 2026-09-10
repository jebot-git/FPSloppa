extends CanvasLayer
const W = preload("res://deathmatch/weapons.gd")
const Profile = preload("res://deathmatch/profile.gd")
var game
var fortress_button: Button
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
var votes_panel: PanelContainer
var votes_button: Button
var settings_panel: PanelContainer
var spectator_choice: CheckButton
var scoreboard_was_open:=false

func panel_style(color: Color) -> StyleBoxFlat:
	var style=preload("res://deathmatch/ui/iron_theme.gd").panel()
	style.bg_color=Color(.12,.105,.085,color.a)
	return style

func text(parent: Node,value: String,size: int = 16,color: Color = Color("e5d5ad")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func setup(arena: Node) -> void:
	game = arena
	var root := Control.new()
	root.theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_status = text(hud,"",17)
	match_status.position = Vector2(24,18)
	avatar_status = text(hud,"",13,Color("ae9571"))
	avatar_status.position = Vector2(24,72)
	kill_feed = text(hud,"",15,Color("c3b499"))
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
	vitals = text(row,"",26,Color("e5d5ad"))
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
	toast_label = text(hud,"",17,Color("e5bc75"))
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
	settings_panel=preload("res://deathmatch/settings/panel.gd").new()
	root.add_child(settings_panel);settings_panel.setup(game)
	votes_panel=preload("res://deathmatch/modes/panel.gd").new();root.add_child(votes_panel);votes_panel.setup(game)
	show_menu(true)

func _build_menu(root: Control) -> void:
	menu = Control.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(.035,.025,.02,.94)
	menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu_scroll:=ScrollContainer.new();menu.add_child(menu_scroll);menu_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;center.size_flags_vertical=Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650,0)
	panel.add_theme_stylebox_override("panel",panel_style(Color("122027")))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	panel.add_child(column)
	text(column,"I R O N   /   B L O O D   /   T H U N D E R",13,Color("ae9571"))
	var logo:=text(column,"FPSloppa",40,Color("d7a966"))
	logo.add_theme_font_override("font",preload("res://deathmatch/ui/BebasNeue-Regular.ttf"))
	logo.add_theme_color_override("font_shadow_color",Color("7e211b"));logo.add_theme_constant_override("shadow_offset_y",3)
	text(column,"DEATHMATCH  /  2–8 PLAYERS",17,Color("c39860"))
	text(column,"Fast movement. No magazines. Every pickup matters.",15,Color("baac95"))
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
	button(identity,"SETTINGS…",func():settings_panel.open())
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
	var assets_panel=preload("res://deathmatch/assets/panel.gd").new();get_child(0).add_child(assets_panel);assets_panel.setup(game)
	button(map_row,"ASSETS…",assets_panel.open)
	map_import=button(map_row,"IMPORT BSP…",func(): bsp_dialog.popup_centered_ratio(.8))
	var rules := HBoxContainer.new()
	rules.add_theme_constant_override("separation",10)
	column.add_child(rules)
	var mode_choice:=OptionButton.new()
	for kind in game.match_mode.NAMES:
		mode_choice.add_item(kind.to_upper()+" · "+game.match_mode.NAMES[kind]);mode_choice.set_item_metadata(mode_choice.item_count-1,kind)
	rules.add_child(mode_choice)
	rules.move_child(mode_choice,0)
	frags = SpinBox.new()
	frags.min_value = 1
	frags.max_value = 100
	frags.value = 20
	rules.add_child(frags)
	text(rules,"limit",14)
	minutes = SpinBox.new()
	minutes.min_value = 1
	minutes.max_value = 60
	minutes.value = 10
	rules.add_child(minutes)
	text(rules,"minutes",14)
	spectator_choice=CheckButton.new();spectator_choice.text="Join as spectator";spectator_choice.custom_minimum_size.y=36
	column.add_child(spectator_choice)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var host := button(actions,"HOST MATCH",func(): game.start_host(name_field.text,int(port_field.value),int(frags.value),int(minutes.value),false,str(mode_choice.get_selected_metadata())))
	var join := button(actions,"JOIN MATCH",func(): game.start_join(name_field.text,address_field.text,int(port_field.value),spectator_choice.button_pressed))
	var training := button(actions,"PRACTICE VS BOTS",func(): game.start_host(name_field.text,0,int(frags.value),int(minutes.value),true,str(mode_choice.get_selected_metadata())))
	launch_buttons = [host,join,training]
	resume = button(column,"RESUME",func():
		game.menu_open = false
		show_menu(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game.is_vr() else Input.MOUSE_MODE_CAPTURED
	)
	var session_actions:=HBoxContainer.new();column.add_child(session_actions)
	leave = button(session_actions,"LEAVE MATCH",func(): game.disconnect_game())
	var fortress_panel=preload("res://deathmatch/modes/fortress_panel.gd").new();get_child(0).add_child(fortress_panel);fortress_panel.setup(game)
	fortress_button=button(session_actions,"TF CLASS…",fortress_panel.open)
	votes_button=button(session_actions,"TEAMS & VOTES…",func():votes_panel.open())
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
	button(vr_actions,"VR CONTROLS…",func():
		if game.is_vr(): game.xr_rig.turn_panel.open())
	var tracking_actions:=HBoxContainer.new()
	column.add_child(tracking_actions)
	button(tracking_actions,"CALIBRATE BODY",func():
		if game.is_vr(): game.xr_rig.tracking.calibrate(); status.text=game.xr_rig.tracking.status)
	button(tracking_actions,"SLIMEVR OSC ON / OFF",func():
		if game.is_vr(): game.xr_rig.tracking.toggle_osc(); status.text=game.xr_rig.tracking.status)
	button(tracking_actions,"BODY TRACKING ON / OFF",func():
		if game.is_vr(): game.xr_rig.tracking.enabled=not game.xr_rig.tracking.enabled)
	var feature_actions:=HBoxContainer.new();column.add_child(feature_actions)
	button(feature_actions,"DEMOS…",open_demos)
	button(feature_actions,"BINDINGS…",open_bindings)
	button(feature_actions,"LOBBY VOTE…",open_lobby)
	status = text(column,"LAN / direct IP · Internet hosts must forward the selected UDP port.",14,Color("ae9571"))
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
	spectator_choice.visible=not game.active
	leave.visible = game.active
	votes_button.visible=game.active
	if votes_panel and not open:votes_panel.hide()
	for b in launch_buttons: b.visible = not game.active
	if not open:
		if settings_panel:settings_panel.hide()
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
	fortress_button.visible=game.active and game.match_mode.kind=="tf" and not game.local_state().get("spectator",false)
	map_choice.disabled=game.active
	map_import.disabled=game.active and multiplayer.is_server()
	vr_actions.visible=game.is_vr()
	if game.is_vr(): controls.text="LEFT STICK Move · RIGHT STICK Turn / ↑↓ weapons\nTRIGGER Fire / select · RIGHT A Jump / respawn\nLEFT X/A Use · RIGHT B Menu · LEFT Y/B Scores"
	hud.visible = game.active
	avatar_status.text = game.avatars.message
	if not game.active:
		scoreboard_was_open=false
		return
	if game.intermission>0 and not scoreboard_was_open:
		game.menu_open=false;show_menu(false)
		if not game.headless and not game.is_vr():Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scoreboard_was_open=game.intermission>0
	var state: Dictionary = game.local_state()
	if state.is_empty(): return
	var d: Dictionary = game.match_mode.fortress.weapon_data(multiplayer.get_unique_id(),state.weapon)
	vitals.text = "%03d  HEALTH    %03d  ARMOR" % [state.hp,state.armor]
	weapon.text = d.name+"\n"+"B %d   S %d   R %d   C %d" % [state.ammo[0],state.ammo[1],state.ammo[2],state.ammo[3]]
	ammo.text = ("∞" if d.ammo<0 else str(state.ammo[d.ammo]))+"  "+("ENERGY" if state.weapon==9 and d.ammo<0 else "MELEE" if d.ammo<0 else W.AMMO_NAMES[d.ammo])
	match_status.text = "%s   ·   %02d:%02d   ·   %d FRAGS   ·   %d PLAYERS   ·   %d ms" % [game.map_title.to_upper(),int(game.round_left)/60,int(game.round_left)%60,game.frag_limit,game.players.values().filter(func(player):return not player.spectator).size(),game.local_ping]
	if game.match_mode.kind!="dm":
		match_status.text=game.match_mode.status(game.multiplayer.get_unique_id()).replace(" · RED FLAG","\nRED FLAG").replace(" · HILL","\nHILL")+" · %02d:%02d"%[int(game.round_left)/60,int(game.round_left)%60]
	var vote: Dictionary=game.votes.snapshot() if game.multiplayer.is_server() else game.votes.view
	if not vote.is_empty():match_status.text+="\nVOTE: "+vote.title+" · MENU → TEAMS & VOTES"
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
	elif state.spectator:
		center_message.text="SPECTATING · WASD move · SPACE / CTRL fly" if not game.is_vr() else "SPECTATING"
	elif state.dead:
		var wait: float = maxf(0,state.respawn_at-game.clock)
		center_message.text = "FRAGGED\n"+("Respawn in %.1f" % wait if wait>0 else "Fire or Space to respawn")
	elif state.invulnerable>game.clock:
		center_message.text = "SPAWN PROTECTION"
	if state.spectator:
		vitals.text="SPECTATOR";weapon.text="";ammo.text=""
	scoreboard.visible = not game.menu_open and (game.bindings.pressed("scores") or (game.is_vr() and game.xr_rig.scores) or game.intermission>0)
	if scoreboard.visible:
		var sorted: Array=game.players.values().filter(func(player):return not player.spectator)
		sorted.sort_custom(func(a,b):return a.kills>b.kills if a.kills!=b.kills else a.deaths<b.deaths)
		var board: String="ROUND COMPLETE\n"+game.round_message+"\nNext round in %d\n"%ceili(game.intermission) if game.intermission>0 else "FPSloppa / "+game.match_mode.NAMES[game.match_mode.kind]+"\n"
		if game.match_mode.team_game():board+="RED %d : BLUE %d   LIMIT %d\n"%[game.match_mode.scores[0],game.match_mode.scores[1],game.match_mode.limit()]
		board+="\nMARINE                 FRAGS   DEATHS   PING\n"
		for player in sorted:
			board+="\n%-18s     %3d      %3d    %3d"%[("R " if player.team==0 else "B " if player.team==1 else "")+player.name,player.kills,player.deaths,player.ping]
		var spectators: Array=game.players.values().filter(func(player):return player.spectator)
		if not spectators.is_empty():
			board+="\n\nSpectators:"
			for i in range(spectators.size()):board+=("\n" if i%2==0 else "   ")+spectators[i].name
		scores.text=board
		scores.add_theme_font_size_override("font_size",16 if game.players.size()>8 else 20)
		scoreboard.offset_top=-280 if game.players.size()>8 else -220
		center_message.text=""

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
	if not game.active:game.selected_map=row.id
	if game.active and not multiplayer.is_server():
		game.uploads.upload(row);status.text="Map imported. Offering it to the server for reuse…"
	else:status.text="Map imported. Joining clients will download it from the host."

func refresh_maps() -> void:
	map_choice.clear()
	for row in game.map_catalog:
		map_choice.add_item(row.title)
		if row.id==game.selected_map: map_choice.select(map_choice.item_count-1)

var bindings_panel
func open_bindings() -> void:
	if not is_instance_valid(bindings_panel) or bindings_panel.is_queued_for_deletion():
		bindings_panel=preload("res://deathmatch/settings/bindings_panel.gd").new();get_child(0).add_child(bindings_panel);bindings_panel.setup(game)
	bindings_panel.open()

var lobby_panel
func open_lobby() -> void:
	if not game.lobby.active():toast("Lobby voting is available between matches on enabled servers.");return
	if not is_instance_valid(lobby_panel):
		lobby_panel=preload("res://deathmatch/modes/lobby_panel.gd").new();get_child(0).add_child(lobby_panel);lobby_panel.setup(game)
	lobby_panel.open()

var demos_panel
func open_demos() -> void:
	if not is_instance_valid(demos_panel):
		demos_panel=preload("res://deathmatch/demos/panel.gd").new();get_child(0).add_child(demos_panel);demos_panel.setup(game)
	demos_panel.open()
