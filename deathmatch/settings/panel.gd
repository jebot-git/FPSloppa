extends PanelContainer
const Preferences=preload("res://deathmatch/settings/preferences.gd")
var game
var values: Dictionary={}
var controls: Dictionary={}
var notice: Label
var section:="audio"
var config_path:=""
var audio_page: VBoxContainer
var graphics_page: VBoxContainer
var input_page: VBoxContainer
var tracking_page: VBoxContainer
var tracking_status: Label
func setup(arena: Node) -> void:
	game=arena;values=game.presentation;name="AudioGraphicsSettings";hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	var style=preload("res://deathmatch/ui/iron_theme.gd").panel()
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_content_margin(side,20)
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	var title:=Label.new();title.add_theme_font_override("font",preload("res://deathmatch/ui/BebasNeue-Regular.ttf"));title.text="SETTINGS";title.add_theme_font_size_override("font_size",28);column.add_child(title)
	var tabs:=HBoxContainer.new();column.add_child(tabs)
	button(tabs,"AUDIO",func():section="audio";refresh())
	button(tabs,"GRAPHICS",func():section="graphics";refresh())
	button(tabs,"CONTROLS",func():section="controls";refresh())
	button(tabs,"TRACKING",func():section="tracking";refresh())
	input_page=VBoxContainer.new();input_page.add_theme_constant_override("separation",8);column.add_child(input_page)
	tracking_page=VBoxContainer.new();tracking_page.add_theme_constant_override("separation",8);column.add_child(tracking_page)
	button(input_page,"BINDINGS…",func():game.hud.open_bindings())
	controls.vr_controls=button(input_page,"VR CONTROLS…",func():
		if game.is_vr():game.xr_rig.turn_panel.open())
	controls.gun_hand=button(input_page,"SWAP GUN HAND",func():
		if game.is_vr():game.xr_rig.left_handed=not game.xr_rig.left_handed;refresh())
	controls.recenter=button(tracking_page,"RECENTER VR",func():
		if game.is_vr():game.xr_rig.recenter();refresh())
	controls.calibrate=button(tracking_page,"CALIBRATE BODY",func():
		if game.is_vr():game.xr_rig.tracking.calibrate();refresh())
	controls.osc=button(tracking_page,"SLIMEVR OSC",func():
		if game.is_vr():game.xr_rig.tracking.toggle_osc();refresh())
	controls.body=button(tracking_page,"BODY TRACKING",func():
		if game.is_vr():game.xr_rig.tracking.enabled=not game.xr_rig.tracking.enabled;refresh())
	tracking_status=Label.new();tracking_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;tracking_page.add_child(tracking_status)
	audio_page=VBoxContainer.new();audio_page.add_theme_constant_override("separation",8);column.add_child(audio_page)
	graphics_page=VBoxContainer.new();graphics_page.add_theme_constant_override("separation",8);column.add_child(graphics_page)
	for row in [["master","Master volume"],["effects","Sound effects"],["music","Music"],["voice","Voice playback"]]:stepper(audio_page,row[0],row[1],.1)
	controls.spatial_audio=button(audio_page,"",func():
		values.spatial_audio="stereo" if values.spatial_audio=="steam_audio" else "steam_audio";game.spatial.apply_backend();save())
	controls.output=button(audio_page,"",func():
		var devices:=AudioServer.get_output_device_list()
		if not devices.is_empty():values.output=devices[(devices.find(AudioServer.output_device)+1)%devices.size()];save())
	button(audio_page,"VOICE CHAT & MICROPHONE…",func():
		if game.voice and game.voice.panel:game.voice.panel.open())
	stepper(graphics_page,"render_scale","Render resolution",.05)
	controls.msaa=button(graphics_page,"",func():values.msaa=(int(values.msaa)+1)%4;save())
	controls.shadows=button(graphics_page,"",func():values.shadows=not values.shadows;save())
	controls.fullscreen=button(graphics_page,"",func():values.fullscreen=not values.fullscreen;save())
	stepper(graphics_page,"fov","Desktop field of view",5)
	stepper(graphics_page,"hud_scale","VR HUD size",.1)
	stepper(graphics_page,"hud_y","VR HUD height",.05)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="Changes apply immediately and are saved.";column.add_child(notice)
	var space:=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(space)
	button(column,"BACK",hide)
	refresh()
func button(parent: Node,title: String,action: Callable) -> Button:
	var control:=Button.new();control.text=title;control.custom_minimum_size=Vector2(76,44);control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(control);control.pressed.connect(action);return control
func stepper(parent: Node,key: String,title: String,step: float) -> void:
	var row:=HBoxContainer.new();parent.add_child(row)
	var label:=Label.new();label.text=title;label.custom_minimum_size.x=220;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
	button(row,"−",adjust.bind(key,-step))
	var amount:=Label.new();amount.custom_minimum_size.x=90;amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;row.add_child(amount);controls[key]=amount
	button(row,"+",adjust.bind(key,step))
func adjust(key: String,step: float) -> void:
	var bounds:=Preferences.limits(key)
	values[key]=clampf(values[key]+step,bounds[0],bounds[1]);save()
func save() -> void:
	Preferences.apply(game,values)
	var err:=Preferences.save_settings(values,config_path)
	notice.text="Saved. Changes applied." if err==OK else "Settings applied; saving failed: "+error_string(err)
	refresh()
func refresh() -> void:
	audio_page.visible=section=="audio";graphics_page.visible=section=="graphics";input_page.visible=section=="controls";tracking_page.visible=section=="tracking"
	for key in ["vr_controls","gun_hand","recenter","calibrate","osc","body"]:controls[key].disabled=not game.is_vr()
	tracking_status.text=game.xr_rig.tracking.status if game.is_vr() else "Connect a VR headset to configure tracking."
	if game.is_vr():
		controls.gun_hand.text="GUN HAND: "+("LEFT" if game.xr_rig.left_handed else "RIGHT")+" · SWAP"
		controls.body.text="BODY TRACKING: "+("ON" if game.xr_rig.tracking.enabled else "OFF")
		controls.osc.text="SLIMEVR OSC: "+("ON" if game.xr_rig.tracking.udp!=null else "OFF")
	values.voice=game.voice.volume
	for key in ["master","effects","voice","music","render_scale"]:controls[key].text="%d%%"%roundi(values[key]*100)
	controls.fov.text="%d°"%roundi(values.fov);controls.fov.get_parent().visible=not game.is_vr()
	controls.hud_scale.text="%d%%"%roundi(values.hud_scale*100)
	controls.hud_y.text="%+.0f cm"%(values.hud_y*100)
	controls.msaa.text="ANTI-ALIASING: "+["OFF","2× MSAA","4× MSAA","8× MSAA"][int(values.msaa)]
	controls.shadows.text="SHADOWS: "+("ON" if values.shadows else "OFF")
	controls.fullscreen.text="DISPLAY: "+("FULLSCREEN" if values.fullscreen else "WINDOWED");controls.fullscreen.visible=not game.is_vr() and not OS.has_feature("android")
	controls.spatial_audio.text="SPATIAL AUDIO: "+("STEAM AUDIO HRTF (HEADPHONES)" if values.spatial_audio=="steam_audio" else "STANDARD STEREO")
	controls.output.text="OUTPUT: "+AudioServer.output_device+" (select to cycle)"
func open() -> void:
	refresh();get_parent().move_child(self,-1);show()
