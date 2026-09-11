extends CanvasLayer
const W = preload("res://deathmatch/weapons.gd")
const Profile = preload("res://deathmatch/profile.gd")
var game
var fortress_button: Button
var map_import: Button
var map_choice
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
var water_tint: ColorRect
var damage: ColorRect
var hit: Label
var scoreboard: PanelContainer
var scores: Label
var score_table
var suicide: Button
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
var capture_alert: Label
var vote_alert: Button
var votes_button: Button
var settings_panel: PanelContainer
var host_panel: PanelContainer
var host_mode
var host_port: SpinBox
var spectator_choice: CheckButton

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
	kill_feed.offset_top = 50
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
	water_tint=ColorRect.new();water_tint.color=Color(.035,.20,.28,.14);hud.add_child(water_tint)
	water_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);water_tint.mouse_filter=Control.MOUSE_FILTER_IGNORE;water_tint.hide()
	damage = ColorRect.new()
	damage.color = Color(1,.02,0,0)
	hud.add_child(damage)
	damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_table=preload("res://deathmatch/ui/scoreboard.gd").new()
	scoreboard=score_table
	hud.add_child(scoreboard)
	score_table.setup()
	scores=score_table.title
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
	capture_alert=Label.new();root.add_child(capture_alert);capture_alert.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;capture_alert.add_theme_font_size_override("font_size",24)
	capture_alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);capture_alert.offset_left=-410;capture_alert.offset_right=410;capture_alert.offset_top=140;capture_alert.offset_bottom=212
	capture_alert.add_theme_stylebox_override("normal",preload("res://deathmatch/ui/iron_theme.gd").panel(8));capture_alert.hide();capture_alert.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vote_alert=Button.new();vote_alert.name="ActiveVoteAlert";root.add_child(vote_alert)
	vote_alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	vote_alert.offset_left=-370;vote_alert.offset_right=370;vote_alert.offset_top=64;vote_alert.offset_bottom=132;vote_alert.hide()
	vote_alert.pressed.connect(func():game.menu_open=true;show_menu(true);votes_panel.open())
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
	menu_scroll.offset_bottom=-56
	menu_scroll.name="MainMenuScroll"
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
	var logo:=text(column,"FPSloppa",40,Color("d7a966"))
	logo.add_theme_font_override("font",preload("res://deathmatch/ui/BebasNeue-Regular.ttf"))
	logo.add_theme_color_override("font_shadow_color",Color("7e211b"));logo.add_theme_constant_override("shadow_offset_y",3)
	text(column,"ARENA COMBAT  /  2–8 PLAYERS",17,Color("c39860"))
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
	host_panel=PanelContainer.new();host_panel.name="HostMatchMenu";root.add_child(host_panel)
	host_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host_panel.hide()
	host_panel.add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(24))
	var host_column:=VBoxContainer.new();host_column.add_theme_constant_override("separation",12);host_panel.add_child(host_column)
	var host_title:=text(host_column,"HOST MATCH",30);host_title.add_theme_font_override("font",preload("res://deathmatch/ui/BebasNeue-Regular.ttf"))
	text(host_column,"Configure your arena, game mode and match limits.",16)
	var host_network:=HBoxContainer.new();host_column.add_child(host_network)
	text(host_network,"SERVER PORT",16);host_port=SpinBox.new();host_port.min_value=1024;host_port.max_value=65535;host_port.value=7777;host_network.add_child(host_port)
	var map_row := HBoxContainer.new()
	host_column.add_child(map_row)
	text(map_row,"ARENA",14).custom_minimum_size.x=110
	map_choice=preload("res://deathmatch/ui/choice.gd").new()
	map_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	map_row.add_child(map_choice)
	map_choice.selected.connect(func(id):game.selected_map=id)
	refresh_maps()
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
	host_column.add_child(rules)
	host_mode=preload("res://deathmatch/ui/choice.gd").new();host_column.add_child(host_mode)
	var host_modes: Array=[]
	for kind in game.match_mode.NAMES:host_modes.append({"id":kind,"title":game.match_mode.NAMES[kind]})
	host_mode.configure(host_modes,"SELECT GAME MODE");host_mode.choose("dm")
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
	var host_space:=Control.new();host_space.size_flags_vertical=Control.SIZE_EXPAND_FILL;host_column.add_child(host_space)
	var host_actions:=HBoxContainer.new();host_column.add_child(host_actions)
	var start_host:=button(host_actions,"START HOST",func():game.start_host(name_field.text,int(host_port.value),int(frags.value),int(minutes.value),false,host_mode.value))
	start_host.custom_minimum_size.y=48
	var start_practice:=button(host_actions,"PRACTICE VS BOTS",func():game.start_host(name_field.text,0,int(frags.value),int(minutes.value),true,host_mode.value))
	start_practice.custom_minimum_size.y=48
	button(host_column,"BACK",host_panel.hide).custom_minimum_size.y=44
	spectator_choice=CheckButton.new();spectator_choice.text="Join as spectator";spectator_choice.custom_minimum_size.y=36
	column.add_child(spectator_choice)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var host := button(actions,"HOST MATCH…",open_host)
	var join := button(actions,"JOIN MATCH",func(): game.start_join(name_field.text,address_field.text,int(port_field.value),spectator_choice.button_pressed))
	launch_buttons = [host,join]
	resume = button(column,"RESUME",func():
		game.menu_open = false
		show_menu(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game.is_vr() else Input.MOUSE_MODE_CAPTURED
	)
	var session_actions:=HBoxContainer.new();column.add_child(session_actions)
	suicide=button(session_actions,"SUICIDE · −1 FRAG",func():
		game.request_suicide()
		game.menu_open=false;show_menu(false)
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if game.is_vr() else Input.MOUSE_MODE_CAPTURED
	)
	suicide.tooltip_text="Respawn after the normal delay. Costs one frag. Unavailable while frozen or waiting between rounds."
	leave = button(session_actions,"LEAVE MATCH",func():
		# Hiding a pressed VR control can deliver another release during teardown.
		if game.active:game.disconnect_game()
	)
	var fortress_panel=preload("res://deathmatch/modes/fortress_panel.gd").new();get_child(0).add_child(fortress_panel);fortress_panel.setup(game)
	fortress_button=button(session_actions,"TF CLASS…",fortress_panel.open)
	votes_button=button(session_actions,"TEAMS & VOTES…",func():votes_panel.open())
	vr_actions=HBoxContainer.new()
	column.add_child(vr_actions)
	button(vr_actions,"CHAT",func():
		if game.active:
			show_menu(false)
			open_chat())
	var feature_actions:=HBoxContainer.new();column.add_child(feature_actions)
	button(feature_actions,"DEMOS…",open_demos)
	status = text(column,"LAN / direct IP · Internet hosts must forward the selected UDP port.",14,Color("ae9571"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(590,32)
	controls=text(column,"WASD  Move   SHIFT  Walk   MOUSE  Aim / fire   1–7 / WHEEL  Weapons\nE  Door   F  Weapon whip   TAB  Scores   ENTER  Chat   ESC  Menu\nSPACE  Jump / swim in Quake maps; respawn when dead.",13,Color("859b9e"))
	var quit_button:=button(menu,"QUIT",func(): game.request_quit())
	quit_button.name="QuitFooter"
	quit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	quit_button.offset_top=-52;quit_button.offset_bottom=-4;quit_button.offset_left=8;quit_button.offset_right=-8
	var config := ConfigFile.new()
	if config.load(Profile.config_path())==OK:
		address_field.text = str(config.get_value("network","address","127.0.0.1"))
	if not FileAccess.file_exists(Profile.config_path()): save_preferences()

	var connection_overlay=preload("res://deathmatch/network/loading_overlay.gd").new()
	root.add_child(connection_overlay);connection_overlay.setup(game)

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
	suicide.visible = game.active
	votes_button.visible=game.active
	if votes_panel and not open:votes_panel.hide()
	for b in launch_buttons: b.visible = not game.active
	if not open:
		if settings_panel:settings_panel.hide()
		if host_panel:host_panel.hide()
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
	fortress_button.visible=game.active and not game.demos.playing and game.match_mode.kind=="tf" and not game.local_state().get("spectator",false)
	map_choice.trigger.disabled=game.active
	map_import.disabled=game.active and multiplayer.is_server()
	vr_actions.visible=game.is_vr()
	if game.is_vr(): controls.text="LEFT STICK Move · RIGHT STICK Turn / ↑↓ weapons\nTRIGGER Fire / select · RIGHT A Jump / respawn\nLEFT X/A Use · RIGHT B Menu · HOLD LEFT Y/B Scores"
	hud.visible = game.active
	avatar_status.text = ""
	vote_alert.visible=false;capture_alert.visible=false
	if not game.active:
		return
	var state: Dictionary = game.local_state()
	var viewed_id: int=game.demos.selected_player if game.demos.playing else multiplayer.get_unique_id()
	suicide.disabled=game.demos.playing or state.is_empty() or state.get("dead",true) or state.get("spectator",false) or game.intermission>0 or game.lobby.active() or game.match_mode.special.blocked(viewed_id)
	if state.is_empty(): return
	var d: Dictionary = game.match_mode.fortress.weapon_data(viewed_id,state.weapon)
	vitals.text = "%03d  HEALTH    %03d  ARMOR" % [state.hp,state.armor]
	weapon.text = d.name+"\n"+"B %d   S %d   R %d   C %d" % [state.ammo[0],state.ammo[1],state.ammo[2],state.ammo[3]]
	ammo.text = ("∞" if d.ammo<0 else str(state.ammo[d.ammo]))+"  "+("ENERGY" if state.weapon==9 and d.ammo<0 else "MELEE" if d.ammo<0 else W.AMMO_NAMES[d.ammo])
	match_status.text = "%s   ·   %02d:%02d   ·   %d FRAGS   ·   %d PLAYERS" % [game.map_title.to_upper(),int(game.round_left)/60,int(game.round_left)%60,game.frag_limit,game.players.values().filter(func(player):return not player.spectator).size()]
	if game.match_mode.kind!="dm":
		match_status.text=game.match_mode.status(viewed_id).replace(" · RED FLAG","\nRED FLAG").replace(" · HILL","\nHILL")+" · %02d:%02d"%[int(game.round_left)/60,int(game.round_left)%60]
	var capture: Dictionary=game.match_mode.capture_status()
	capture_alert.visible=not capture.is_empty() and (not game.is_vr() or game.menu_open or game.intermission>0)
	if not capture.is_empty():
		capture_alert.text=capture.text+"\n"+capture.detail
		capture_alert.add_theme_color_override("font_color",Color("ffa18c") if capture.team==0 else Color("91caff"))
	var vote: Dictionary=game.votes.snapshot() if game.multiplayer.is_server() else game.votes.view
	vote_alert.visible=not vote.is_empty() and not game.menu_open and not game.is_vr()
	if not vote.is_empty():vote_alert.text="VOTE STARTED · %s\nYES %d/%d · NO %d · %ds · ESC → TEAMS & VOTES"%[vote.title,vote.yes,vote.needed,vote.no,vote.seconds]
	if not vote.is_empty():match_status.text+="\nVOTE: "+vote.title+" · MENU → TEAMS & VOTES"
	if game.voice and game.voice.transmitting: match_status.text += "   ·   MIC LIVE"
	var lines := PackedStringArray()
	for entry in game.feed:
		if entry.until>game.clock: lines.append(entry.text)
	kill_feed.text = "\n".join(lines)
	hit.visible = game.hit_flash>0
	damage.color.a = game.hurt_flash*.28
	var actor=game.fighters.get(viewed_id)
	water_tint.visible=actor!=null and actor.underwater and not state.dead and not game.menu_open
	if water_tint.visible:match_status.text+="   ·   "+("AIR %ds"%ceili(actor.air_left) if actor.air_left>0 else "DROWNING · SURFACE!")
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
	scoreboard.visible = not game.menu_open and (game.bindings.pressed("scores") or (game.is_vr() and game.xr_rig.scores))
	if scoreboard.visible:
		score_table.refresh(game)
		center_message.text=""

func _import_bsp(path: String) -> void:
	status.text="Importing Quake BSP geometry and textures…"
	await get_tree().process_frame
	var row: Dictionary=game.Maps.import_custom(path)
	if row.has("error"):
		status.text=row.error
		return
	game.map_catalog=game.Maps.catalog()
	if not game.active:game.selected_map=row.id
	refresh_maps()
	if game.active and not multiplayer.is_server():
		game.uploads.upload(row);status.text="Map imported. Offering it to the server for reuse…"
	else:status.text="Map imported. Joining clients will download it from the host."

func refresh_maps() -> void:
	var rows: Array=[]
	for row in game.map_catalog:rows.append({"id":row.id,"title":row.title})
	map_choice.configure(rows,"SELECT ARENA");map_choice.choose(game.selected_map)

func open_host() -> void:
	refresh_maps();host_panel.get_parent().move_child(host_panel,-1);host_panel.show()

var bindings_panel
func open_bindings() -> void:
	if not is_instance_valid(bindings_panel) or bindings_panel.is_queued_for_deletion():
		bindings_panel=preload("res://deathmatch/settings/bindings_panel.gd").new();get_child(0).add_child(bindings_panel);bindings_panel.setup(game)
	bindings_panel.open()

var demos_panel
func open_demos() -> void:
	if not is_instance_valid(demos_panel):
		demos_panel=preload("res://deathmatch/demos/panel.gd").new();get_child(0).add_child(demos_panel);demos_panel.setup(game)
	demos_panel.open()
