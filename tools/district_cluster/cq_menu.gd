extends Control
signal join_requested
var join_button: Button
var message: Label
var soundscape
func setup(audio: Node) -> void:
	soundscape=audio
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back:=ColorRect.new();back.color=Color(.025,.033,.047);back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(back)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(420,0);box.add_theme_constant_override("separation",16);center.add_child(box)
	var title:=Label.new();title.text="CONQUEST";title.add_theme_font_size_override("font_size",48);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(title)
	var subtitle:=Label.new();subtitle.text="VESPER · A CITY AT WAR";subtitle.modulate=Color(.65,.7,.77);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(subtitle)
	var line:=HSeparator.new();box.add_child(line)
	join_button=Button.new();join_button.name="JoinCampaign";join_button.text="Join campaign";join_button.custom_minimum_size.y=48;box.add_child(join_button)
	join_button.pressed.connect(func():join_button.disabled=true;message.text="Connecting…";join_requested.emit())
	for kind in ["Music","Ambience"]:
		var row:=HBoxContainer.new();box.add_child(row)
		var caption:=Label.new();caption.text=kind;caption.custom_minimum_size.x=100;row.add_child(caption)
		var slider:=HSlider.new();slider.name=kind+"Volume";slider.min_value=0;slider.max_value=1;slider.step=.01;slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		slider.value=soundscape.music_volume if kind=="Music" else soundscape.ambience_volume;row.add_child(slider)
		slider.value_changed.connect(func(value):
			if kind=="Music":soundscape.music_volume=value
			else:soundscape.ambience_volume=value
			var preferences:=ConfigFile.new();preferences.set_value("audio","music",soundscape.music_volume);preferences.set_value("audio","ambience",soundscape.ambience_volume);preferences.save("user://cq_audio.cfg"))
	var exit_button:=Button.new();exit_button.text="Quit";box.add_child(exit_button);exit_button.pressed.connect(func():get_tree().root.close_requested.emit())
	message=Label.new();message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=45;message.modulate=Color(.8,.7,.65);box.add_child(message)
	join_button.grab_focus()
func failed(text: String) -> void:
	message.text=text;join_button.disabled=false;join_button.grab_focus()
