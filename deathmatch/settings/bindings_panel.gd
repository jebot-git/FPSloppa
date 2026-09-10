extends PanelContainer
var game
var capture:=""
var notice: Label
var buttons: Dictionary={}
func setup(arena: Node) -> void:
	game=arena;theme=preload("res://deathmatch/ui/iron_theme.gd").theme();hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll:=ScrollContainer.new();add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	var title:=Label.new();title.text="CONTROL BINDINGS";column.add_child(title)
	var close:=Button.new();close.text="BACK";close.custom_minimum_size.y=52;column.add_child(close);close.pressed.connect(func():capture="";hide())
	for option in ["two_handed","physical_jump"]:
		var check:=CheckButton.new();check.text="Support-hand aim (hold grip near fore-end)" if option=="two_handed" else "Physical playspace jump (standing only)";check.button_pressed=game.bindings.get(option);check.custom_minimum_size.y=48;column.add_child(check)
		check.toggled.connect(func(value):game.bindings.set(option,value);save())
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="Select a desktop action, then press a key or mouse button. Escape cancels. VR roles follow your hand settings. Shared bindings trigger both actions.";column.add_child(notice)
	for action in game.bindings.KEYS:
		var button:=Button.new();button.custom_minimum_size.y=48;column.add_child(button);buttons[action]=button
		button.pressed.connect(func():capture=action;notice.text="Press a key / mouse button for "+action+"; Escape cancels.")
	for action in ["move","turn"]:
		var label:=Label.new();label.text="VR "+action+" stick";column.add_child(label)
		var axis:=preload("res://deathmatch/ui/choice.gd").new();column.add_child(axis)
		var roles: Array=[]
		for role in ["move","turn","left","right"]:roles.append({"id":role,"title":role})
		axis.configure(roles,"SELECT STICK");axis.choose(game.bindings.axes[action])
		axis.selected.connect(func(value):game.bindings.axes[action]=value;save())
	for action in game.bindings.VR:
		var row:=HBoxContainer.new();column.add_child(row)
		var label:=Label.new();label.text="VR "+action;label.custom_minimum_size.x=180;row.add_child(label)
		var choice:=preload("res://deathmatch/ui/choice.gd").new();choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(choice)
		var roles: Array=[]
		for role in ["weapon","support","move","turn","left","right"]:
			for input in game.bindings.INPUTS:
				var value: String=role+":"+input;roles.append({"id":value,"title":value})
		choice.configure(roles,"SELECT BINDING");choice.choose(game.bindings.vr[action])
		choice.selected.connect(func(value):game.bindings.vr[action]=value;save())
	var reset:=Button.new();reset.text="RESET BINDINGS";reset.custom_minimum_size.y=48;column.add_child(reset)
	reset.pressed.connect(func():game.bindings.keys=game.bindings.KEYS.duplicate();game.bindings.vr=game.bindings.VR.duplicate();game.bindings.axes={"move":"move","turn":"turn"};save();hide();queue_free();game.hud.open_bindings())
	var back:=Button.new();back.text="BACK";back.custom_minimum_size.y=52;column.add_child(back);back.pressed.connect(func():capture="";hide())
	refresh()
func refresh() -> void:
	for action in buttons:
		var key:int=game.bindings.keys[action]
		buttons[action].text=action.to_upper()+": "+(OS.get_keycode_string(key) if key>0 else "MOUSE "+str(-key))
func save() -> void:
	var error:int=game.bindings.save();notice.text="Saved. Escape and the controller menu button remain available." if error==OK else "Save failed: "+error_string(error);refresh()
func _input(event: InputEvent) -> void:
	if not visible or capture.is_empty():return
	var code:=0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:capture="";get_viewport().set_input_as_handled();return
		code=event.physical_keycode
	elif event is InputEventMouseButton and event.pressed:code=-event.button_index
	if code!=0:
		game.bindings.keys[capture]=code;capture="";save();get_viewport().set_input_as_handled()
func open() -> void:refresh();show();get_parent().move_child(self,-1)
