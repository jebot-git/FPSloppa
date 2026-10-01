extends VBoxContainer
const Preferences=preload("res://deathmatch/haptics/preferences.gd")
var game
var config_path:=""
var enabled: CheckButton
var backend
var host: LineEdit
var port: SpinBox
var osc_row: HBoxContainer
var ble_row: HBoxContainer
var strength_row: HBoxContainer
var strength: HSlider
var strength_label: Label
var device_choice
var devices_snapshot:=""
var toggles: Dictionary={}
var status: Label
var notice: Label
var test_button: Button
func setup(arena: Node) -> void:
	game=arena;add_theme_constant_override("separation",8)
	var help:=Label.new();help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	help.text="FPSloppa Vest v1 · Native Bluetooth is preferred on supported platforms."
	add_child(help)
	var mode_row:=HBoxContainer.new();add_child(mode_row)
	enabled=CheckButton.new();enabled.text="Enable bHaptics";enabled.custom_minimum_size.y=44;enabled.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mode_row.add_child(enabled)
	backend=preload("res://deathmatch/ui/choice.gd").new();mode_row.add_child(backend)
	var outputs: Array=[{"id":"osc","title":"OSC receiver"}]
	if Preferences.Platform.supports_native():outputs.append({"id":"ble","title":"Native Bluetooth"})
	backend.configure(outputs,"OUTPUT");backend.selected.connect(func(_id):save())
	osc_row=HBoxContainer.new();add_child(osc_row)
	var label:=Label.new();label.text="Receiver IP";osc_row.add_child(label)
	host=LineEdit.new();host.size_flags_horizontal=Control.SIZE_EXPAND_FILL;host.placeholder_text="127.0.0.1";host.max_length=45;osc_row.add_child(host)
	port=SpinBox.new();port.min_value=1;port.max_value=65535;port.step=1;port.custom_minimum_size.x=115;osc_row.add_child(port)
	button(osc_row,"APPLY",save)
	ble_row=HBoxContainer.new();add_child(ble_row)
	button(ble_row,"SCAN",func():
		if game.haptics and game.haptics.output.has_method("scan"):game.haptics.output.scan())
	device_choice=preload("res://deathmatch/ui/choice.gd").new();device_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ble_row.add_child(device_choice)
	button(ble_row,"CONNECT",func():
		if game.haptics and game.haptics.output.has_method("connect_device") and not device_choice.value.is_empty():
			game.haptics.output.connect_device(device_choice.value))
	strength_row=HBoxContainer.new();add_child(strength_row)
	strength_label=Label.new();strength_label.custom_minimum_size.x=160;strength_row.add_child(strength_label)
	strength=HSlider.new();strength.min_value=0;strength.max_value=1;strength.step=.05;strength.size_flags_horizontal=Control.SIZE_EXPAND_FILL;strength.custom_minimum_size.y=36;strength_row.add_child(strength)
	strength.value_changed.connect(func(_value: float):save())
	var categories:=HBoxContainer.new();add_child(categories)
	for key in ["recoil","damage","environment","healing","pickups"]:
		var toggle:=CheckButton.new();toggle.text={"recoil":"Recoil","damage":"Damage","environment":"Hazards","healing":"Healing","pickups":"Pickups"}[key];toggle.custom_minimum_size.y=40;toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;categories.add_child(toggle);toggles[key]=toggle
		toggle.toggled.connect(func(_on: bool):save())
	var buttons:=HBoxContainer.new();add_child(buttons)
	test_button=button(buttons,"TEST VEST",func():
		if game.haptics:notice.text="Test sent; feel for a short chest pulse." if game.haptics.test_pulse() else "Test unavailable. Enable feedback and connect/check the receiver.")
	button(buttons,"STOP",func():enabled.set_pressed_no_signal(false);save())
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="OSC strength is set in the receiver. Direct Bluetooth supports X40 and Air only.";add_child(notice)
	enabled.toggled.connect(func(_on: bool):save())
	var values: Dictionary=game.haptics.values if game.haptics else Preferences.read_settings()
	enabled.set_pressed_no_signal(values.enabled);backend.set_block_signals(true);backend.choose(values.backend);backend.set_block_signals(false);host.text=values.host;port.value=values.port;strength.set_value_no_signal(values.intensity)
	for key in toggles:toggles[key].set_pressed_no_signal(values[key])
	refresh()
func button(parent: Node,title: String,action: Callable) -> Button:
	var control:=Button.new();control.text=title;control.custom_minimum_size=Vector2(76,44);control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(control);control.pressed.connect(action);return control
func save() -> void:
	var values: Dictionary={"enabled":enabled.button_pressed,"backend":backend.value,"intensity":strength.value,"host":host.text.strip_edges(),"port":int(port.value)}
	for key in toggles:values[key]=toggles[key].button_pressed
	if values.backend=="osc" and not Preferences.valid_endpoint(values.host,values.port):
		values.enabled=false;enabled.set_pressed_no_signal(false)
		if game.haptics:game.haptics.configure(values)
		Preferences.save_settings(values,config_path)
		notice.text="Enter a numeric receiver IP address and valid UDP port, then apply.";return
	if game.haptics:game.haptics.configure(values)
	var err:=Preferences.save_settings(values,config_path)
	notice.text="Saved. Use TEST VEST to check feedback." if err==OK else "Applied; saving failed: "+error_string(err)
	refresh()
func refresh() -> void:
	var direct: bool=backend.value=="ble"
	osc_row.visible=not direct;ble_row.visible=direct;strength_row.visible=direct
	strength_label.text="Strength: %d%%"%roundi(strength.value*100)
	status.text=game.haptics.status_text() if game.haptics else "bHaptics is unavailable on this client."
	enabled.disabled=game.haptics==null
	test_button.disabled=game.haptics==null or not game.haptics.values.enabled
	if direct and game.haptics and game.haptics.output.has_method("devices"):
		var devices: Array=game.haptics.output.devices()
		var snapshot:=JSON.stringify(devices)
		if snapshot!=devices_snapshot:
			devices_snapshot=snapshot
			var options: Array=[]
			for device in devices:options.append({"id":str(device.id),"title":str(device.name)+" · "+str(device.id)})
			device_choice.configure(options,"SCAN FOR A VEST")
func _process(_delta: float) -> void:
	if is_visible_in_tree():refresh()
