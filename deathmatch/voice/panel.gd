extends Window
var voice
var modes: OptionButton
var status: Label
var peers: VBoxContainer
var roster_key:=""
var elapsed:=0.0
func setup(service: Node) -> void:
	voice=service
	title="VOICE CHAT"
	size=Vector2i(900,700)
	min_size=size
	visible=false
	close_requested.connect(hide)
	var margin:=MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var theme_resource:=Theme.new()
	theme_resource.default_font_size=28
	column.theme=theme_resource
	var intro:=Label.new()
	intro.text="Match-wide voice · microphone off by default\nPush-to-talk: V or off-hand controller grip"
	column.add_child(intro)
	modes=OptionButton.new()
	for label in ["MIC OFF (listen only)","PUSH TO TALK","VOICE ACTIVATION"]: modes.add_item(label)
	modes.item_selected.connect(voice.set_mode)
	column.add_child(modes)
	var devices:=OptionButton.new()
	for device in AudioServer.get_input_device_list(): devices.add_item(device)
	devices.item_selected.connect(func(index):
		AudioServer.input_device=devices.get_item_text(index)
		voice.set_mode(voice.mode))
	column.add_child(devices)
	var mute:=CheckButton.new()
	mute.text="Mute all incoming voice"
	mute.toggled.connect(func(value):
		voice.muted_all=value
		if value:
			for id in voice.streams.keys(): voice.remove_stream(id))
	column.add_child(mute)
	var volume:=HSlider.new()
	volume.min_value=0; volume.max_value=1; volume.step=.05; volume.value=voice.volume
	volume.custom_minimum_size.y=30
	volume.tooltip_text="Voice playback volume"
	volume.value_changed.connect(func(value): voice.volume=value)
	column.add_child(volume)
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	peers=VBoxContainer.new()
	peers.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(peers)
	var close:=Button.new()
	close.text="CLOSE"
	close.custom_minimum_size.y=48
	close.pressed.connect(hide)
	column.add_child(close)

func refresh(delta: float) -> void:
	if not visible: return
	elapsed+=delta
	if elapsed<.15: return
	elapsed=0
	modes.select(voice.mode)
	modes.disabled=voice.game.active and not voice.game.voice_enabled
	status.text=("TRANSMITTING · " if voice.transmitting else "")+voice.message+"\nInput level: %d%%"%mini(100,roundi(voice.meter*500))
	var key:=str(voice.game.players.keys())+str(voice.muted)
	if key==roster_key: return
	roster_key=key
	for child in peers.get_children(): child.queue_free()
	for id in voice.game.players:
		if id==multiplayer.get_unique_id() or id<1: continue
		var check:=CheckButton.new()
		check.text="Mute "+str(voice.game.players[id].name)
		check.button_pressed=voice.muted.has(id)
		check.toggled.connect(func(value): voice.set_muted(id,value))
		peers.add_child(check)
