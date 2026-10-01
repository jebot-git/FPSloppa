extends PanelContainer
const Choice=preload("res://deathmatch/ui/choice.gd")
const LABELS={"forward":"Forward","back":"Backward","left":"Strafe left","right":"Strafe right","jump":"Jump / ski","slow":"Walk","use":"Use / interact","melee":"Melee","scores":"Scoreboard","chat":"Text chat","team_chat":"Team text chat","team_ptt":"Team voice","ptt":"Push to talk","crouch":"Crouch (hold)","prone":"Prone (toggle)","down":"Swim down","reload":"Reload / magazine release","jetpack":"Jetpack","fire":"Fire","alt_fire":"Alternate fire / Tribes zoom","zoom_range":"Tribes zoom range","offhand_fire":"Offhand fire","next_weapon":"Next weapon","previous_weapon":"Previous weapon","ability":"Class ability","support":"Support-hand grip","menu":"Menu","weapon_wheel":"Weapon wheel"}
const DESKTOP_GROUPS={"MOVEMENT":["forward","back","left","right","jump","slow","crouch","prone","down","jetpack"],"COMBAT & EQUIPMENT":["fire","alt_fire","zoom_range","offhand_fire","reload","melee","use","next_weapon","previous_weapon"],"COMMUNICATION & MATCH":["scores","chat","team_chat","team_ptt","ptt"]}
const ROLES={"weapon":"Weapon hand","support":"Support hand","move":"Movement hand","turn":"Turning hand","left":"Left hand","right":"Right hand"}
const INPUT_LABELS={"trigger":"Trigger","grip":"Grip","ax_button":"A / X","by_button":"B / Y","primary_click":"Stick click","none":"Unbound"}
const OPTIONS={"two_handed":"Support-hand aiming","physical_jump":"Physical jump","physical_crouch":"Physical crouch","physical_prone":"Physical prone","tracked_leg_animation":"Animate tracked legs while still","physical_interactions":"Physical ability / console buttons","face_expressions":"Face expressions (experimental)"}
var game
var capture:=""
var device:="desktop"
var notice: Label
var buttons: Dictionary={}
var pages: Dictionary={}
var tabs: Dictionary={}
var axis_choices: Dictionary={}
var vr_choices: Dictionary={}
var checks: Dictionary={}
var scroll: ScrollContainer
var reset: Button
var category
var groups: Dictionary={}
var selected_groups: Dictionary={"desktop":"MOVEMENT","vr":"WEAPON ACTIONS"}
func setup(arena: Node) -> void:
	game=arena;theme=preload("res://deathmatch/ui/iron_theme.gd").theme();hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	var layout:=VBoxContainer.new();layout.add_theme_constant_override("separation",12);margin.add_child(layout)
	var header:=HBoxContainer.new();layout.add_child(header)
	var title:=Label.new();title.text="CONTROL BINDINGS";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	var close:=Button.new();close.text="BACK";close.custom_minimum_size=Vector2(120,48);header.add_child(close);close.pressed.connect(close_panel)
	var tab_row:=HBoxContainer.new();layout.add_child(tab_row)
	for id in ["desktop","vr"]:
		var tab:=Button.new();tab.text="DESKTOP" if id=="desktop" else "VR";tab.toggle_mode=true;tab.custom_minimum_size.y=48;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab_row.add_child(tab);tabs[id]=tab
		tab.pressed.connect(func():select_device(id))
	category=Choice.new();layout.add_child(category);category.selected.connect(select_group)
	scroll=preload("res://deathmatch/ui/drag_scroll.gd").new();scroll.name="BindingsScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	for id in tabs:
		var page:=VBoxContainer.new();page.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page.add_theme_constant_override("separation",8);content.add_child(page);pages[id]=page
	for group in DESKTOP_GROUPS:
		var group_page=group_column("desktop",group)
		section(group_page,group)
		for action in DESKTOP_GROUPS[group]:
			var row:=binding_row(group_page,LABELS[action]);var button:=Button.new();button.custom_minimum_size.y=48;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(button);buttons[action]=button
			button.pressed.connect(func():begin_capture(action))
	var sticks=group_column("vr","STICKS & MOVEMENT")
	section(sticks,"STICKS")
	for action in ["move","turn"]:
		var row:=binding_row(sticks,"Movement stick" if action=="move" else "Turning stick")
		var axis=selector(row,{"move":"Movement hand","turn":"Turning hand","left":"Left hand","right":"Right hand"});axis_choices[action]=axis
		axis.selected.connect(func(value):game.bindings.axes[action]=value;save())
	var weapons=group_column("vr","WEAPON ACTIONS")
	var communication=group_column("vr","MENUS & COMMUNICATION")
	for action in game.bindings.VR:
		var row:=binding_row(communication if action in ["menu","scores","chat","team_chat","ptt","team_ptt","weapon_wheel"] else weapons,LABELS[action]);var hand=selector(row,ROLES);var input=selector(row,INPUT_LABELS);vr_choices[action]=[hand,input]
		hand.selected.connect(func(value):set_vr_binding(action,0,value))
		input.selected.connect(func(value):set_vr_binding(action,1,value))
	var physical=group_column("vr","PHYSICAL CONTROLS & TRACKING")
	for option in OPTIONS:
		var check:=CheckButton.new();check.text=OPTIONS[option];check.custom_minimum_size.y=48;physical.add_child(check);checks[option]=check
		check.toggled.connect(func(value):game.bindings.set(option,value);save())
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",12);layout.add_child(footer)
	notice=Label.new();notice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(notice)
	reset=Button.new();reset.custom_minimum_size.y=48;footer.add_child(reset)
	reset.pressed.connect(func():cancel_capture();game.bindings.reset_bindings(device);save())
	visibility_changed.connect(func():
		if not visible:cancel_capture();close_choices())
	select_device("vr" if game.is_vr() else "desktop");refresh()
func section(parent: Control,title: String) -> void:
	var label:=Label.new();label.text=title;label.custom_minimum_size.y=40;parent.add_child(label)
func binding_row(parent: Control,title: String) -> HBoxContainer:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);parent.add_child(row)
	var label:=Label.new();label.text=title;label.custom_minimum_size.x=260;row.add_child(label)
	return row
func selector(parent: Control,labels: Dictionary):
	var choice=Choice.new();choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(choice)
	var items: Array=[]
	for id in labels:items.append({"id":id,"title":labels[id]})
	choice.configure(items,"SELECT");return choice
func select_device(id: String) -> void:
	cancel_capture();close_choices();device=id
	for key in pages:pages[key].visible=key==id;tabs[key].set_pressed_no_signal(key==id)
	var options: Array=[]
	for group in groups[id]:options.append({"id":group,"title":group})
	category.configure(options,"CATEGORY");category.choose(selected_groups[id])
	scroll.scroll_vertical=0;reset.text="RESET "+id.to_upper()+" BINDINGS";notice.text=""
func close_choices() -> void:
	for choice in axis_choices.values():choice.close_popup()
	for pair in vr_choices.values():
		for choice in pair:choice.close_popup()
func close_panel() -> void:cancel_capture();hide()
func cancel_capture() -> void:
	capture="";refresh()
func begin_capture(action: String) -> void:
	if game.is_vr():notice.text="Use a keyboard or mouse to edit desktop bindings.";return
	capture=action;notice.text="Press a key or mouse button. Escape cancels.";refresh()
func set_vr_binding(action: String,index: int,value: String) -> void:
	var parts: PackedStringArray=game.bindings.vr[action].split(":");parts[index]=value;game.bindings.vr[action]=":".join(parts);save()
func refresh() -> void:
	for action in buttons:
		var key:int=game.bindings.keys[action]
		buttons[action].text="PRESS KEY…" if capture==action else key_label(key)
	for action in axis_choices:refresh_choice(axis_choices[action],game.bindings.axes[action])
	for action in vr_choices:
		var parts: PackedStringArray=game.bindings.vr[action].split(":")
		for i in 2:refresh_choice(vr_choices[action][i],parts[i])
	for option in checks:checks[option].set_pressed_no_signal(game.bindings.get(option))
func refresh_choice(choice,value: String) -> void:
	choice.set_block_signals(true);choice.choose(value);choice.set_block_signals(false)
func key_label(key: int) -> String:
	if key>0:return OS.get_keycode_string(key)
	return {MOUSE_BUTTON_LEFT:"Left mouse",MOUSE_BUTTON_RIGHT:"Right mouse",MOUSE_BUTTON_MIDDLE:"Middle mouse",MOUSE_BUTTON_WHEEL_UP:"Wheel up",MOUSE_BUTTON_WHEEL_DOWN:"Wheel down",MOUSE_BUTTON_WHEEL_LEFT:"Wheel left",MOUSE_BUTTON_WHEEL_RIGHT:"Wheel right",MOUSE_BUTTON_XBUTTON1:"Mouse back",MOUSE_BUTTON_XBUTTON2:"Mouse forward"}.get(-key,"Mouse "+str(-key))
func save() -> void:
	var error:int=game.bindings.save();notice.text="Saved" if error==OK else "Save failed: "+error_string(error);refresh()
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or capture.is_empty():return
	var code:=0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:cancel_capture();notice.text="Cancelled";get_viewport().set_input_as_handled();return
		code=event.physical_keycode
	elif event is InputEventMouseButton and event.pressed:code=-event.button_index
	if code!=0:
		game.bindings.keys[capture]=code;capture="";save();get_viewport().set_input_as_handled()
func open() -> void:
	select_device("vr" if game.is_vr() else "desktop");refresh();show();get_parent().move_child(self,-1)

func group_column(kind: String,label: String) -> VBoxContainer:
	if not groups.has(kind):groups[kind]={}
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);pages[kind].add_child(column);groups[kind][label]=column
	return column
func select_group(id: String) -> void:
	selected_groups[device]=id;cancel_capture();close_choices();scroll.scroll_vertical=0
	for group in groups[device]:groups[device][group].visible=group==id
