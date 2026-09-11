extends PanelContainer
## The voice panel lives in the same canvas as the VR menu, with no native popup.
var voice
var mumble: Button
var modes: Array[Button]=[]
var status: Label
var peers: VBoxContainer
var mute: CheckButton
var volume: HSlider
var close: Button
var roster_key:=""
var elapsed:=0.0
func setup(service: Node) -> void:
	voice=service
	name="VoicePanel"
	visible=false
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background=preload("res://deathmatch/ui/iron_theme.gd").panel()
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: background.set_content_margin(side,20)
	add_theme_stylebox_override("panel",background)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	add_child(column)
	var theme_resource=preload("res://deathmatch/ui/iron_theme.gd").theme()
	theme_resource.default_font_size=18
	column.theme=theme_resource
	var intro:=Label.new()
	intro.text="VOICE CHAT\nPush-to-talk: hold V or the off-hand controller grip"
	column.add_child(intro)
	mumble=Button.new();mumble.text="OPEN EXTERNAL MUMBLE CLIENT";mumble.custom_minimum_size.y=44;column.add_child(mumble)
	mumble.pressed.connect(func():
		var err=preload("res://deathmatch/voice/external.gd").open_client(voice.game.mumble_url)
		voice.message="Opened Mumble. Configure its microphone and push-to-talk in that app." if err==OK else "Install a Mumble client that handles mumble:// links. Server: "+voice.game.mumble_url)
	var mode_row:=HBoxContainer.new()
	column.add_child(mode_row)
	var group:=ButtonGroup.new()
	for label in ["LISTEN ONLY","PUSH TO TALK","VOICE ACTIVATION"]:
		var mode:=Button.new()
		mode.text=label;mode.toggle_mode=true;mode.button_group=group
		mode.custom_minimum_size.y=48;mode.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		mode.pressed.connect(voice.set_mode.bind(modes.size(),true))
		mode_row.add_child(mode);modes.append(mode)
	var devices:=Button.new()
	devices.custom_minimum_size.y=44
	devices.text="Microphone: "+(AudioServer.input_device if not AudioServer.input_device.is_empty() else "System default")+" (select to cycle)"
	devices.pressed.connect(func():
		var available:=AudioServer.get_input_device_list()
		if available.is_empty(): return
		voice.select_input_device(available[(available.find(AudioServer.input_device)+1)%available.size()])
		devices.text="Microphone: "+(AudioServer.input_device if not AudioServer.input_device.is_empty() else "System default")+" (select to cycle)"
		voice.set_mode(voice.mode))
	column.add_child(devices)
	mute=CheckButton.new()
	mute.text="Mute all incoming voice";mute.custom_minimum_size.y=44
	mute.toggled.connect(func(value):
		voice.muted_all=value
		voice.save_preferences()
		if value:
			for id in voice.streams.keys(): voice.remove_stream(id))
	column.add_child(mute)
	var volume_label:=Label.new();volume_label.text="Voice playback volume";column.add_child(volume_label)
	volume=HSlider.new()
	volume.min_value=0;volume.max_value=1;volume.step=.05;volume.value=voice.volume
	volume.custom_minimum_size.y=44
	volume.value_changed.connect(func(value):
		voice.volume=value
		voice.game.presentation.voice=value
		preload("res://deathmatch/settings/preferences.gd").save_settings(voice.game.presentation))
	column.add_child(volume)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y=52
	column.add_child(status)
	var retry:=Button.new();retry.text="RETRY ACCESS";retry.custom_minimum_size.y=44
	retry.visible=OS.has_feature("android")
	retry.pressed.connect(voice.retry_access);column.add_child(retry)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	peers=VBoxContainer.new();peers.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(peers)
	close=Button.new();close.text="BACK";close.custom_minimum_size.y=48
	close.pressed.connect(hide);column.add_child(close)

func open() -> void:
	volume.set_value_no_signal(voice.volume)
	show()
	get_parent().move_child(self,-1)
	elapsed=1;refresh(0)

func refresh(delta: float) -> void:
	mumble.visible=voice.game.voice_backend=="mumble"
	mumble.disabled=voice.game.mumble_url.is_empty()
	if not visible: return
	elapsed+=delta
	if elapsed<.15: return
	elapsed=0
	for i in range(modes.size()):
		modes[i].disabled=voice.game.voice_backend=="mumble"
		modes[i].set_pressed_no_signal(i==voice.mode)
		modes[i].disabled=voice.game.active and not voice.game.voice_enabled
	mute.set_pressed_no_signal(voice.muted_all)
	status.text=("TRANSMITTING · " if voice.transmitting else "")+voice.message+"\nInput level: %d%%"%mini(100,roundi(voice.meter*500))
	var key:=str(voice.game.players.keys())+str(voice.muted)
	if key==roster_key: return
	roster_key=key
	for child in peers.get_children(): child.queue_free()
	for id in voice.game.players:
		if id==multiplayer.get_unique_id() or id<1: continue
		var check:=CheckButton.new()
		check.text="Mute "+str(voice.game.players[id].name);check.custom_minimum_size.y=44
		check.button_pressed=voice.muted.has(id)
		check.toggled.connect(func(value): voice.set_muted(id,value))
		peers.add_child(check)
