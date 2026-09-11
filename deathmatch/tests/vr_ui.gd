extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")

func point_at(pointer: Node3D,surface: Node3D,pixel: Vector2) -> void:
	var local := Vector3((pixel.x/surface.viewport_size.x-.5)*surface.screen_size.x,(.5-pixel.y/surface.viewport_size.y)*surface.screen_size.y,.011)
	var target: Vector3=surface.to_global(local)
	pointer.get_parent().global_position=target+surface.global_basis.z*.8
	pointer.get_parent().look_at(target,surface.global_basis.y)
	pointer.get_node("RayCast").force_raycast_update()
	pointer._process(.016)

func click(pointer: Node3D) -> void:
	pointer._button_pressed()
	pointer._button_released()

func run() -> void:
	var config_path: String=preload("res://deathmatch/profile.gd").config_path()
	var had_config:=FileAccess.file_exists(config_path)
	var saved_config:=FileAccess.get_file_as_bytes(config_path) if had_config else PackedByteArray()
	var g=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(g)
	g.voice.panel=preload("res://deathmatch/voice/panel.gd").new()
	g.voice.add_child(g.voice.panel)
	g.voice.panel.setup(g.voice)
	g.hud=load("res://deathmatch/interface.gd").new()
	g.add_child(g.hud)
	g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new()
	g.add_child(g.xr_rig)
	check(g.xr_rig.setup(g,true),"Simulated VR initializes")
	await process_frame
	await process_frame
	g.xr_rig.set_process(false)
	g.set_process(false)
	var rig=g.xr_rig
	rig.panel.global_transform=Transform3D(Basis.IDENTITY,Vector3(1000,20,1000))
	rig.keyboard.global_transform=rig.panel.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-1,.15))
	await physics_frame
	await physics_frame
	var menu_scroll: ScrollContainer=g.hud.menu.get_node("MainMenuScroll")
	print("MENU_METRICS ",menu_scroll.size," max=",menu_scroll.get_v_scroll_bar().max_value)
	check(menu_scroll.get_v_scroll_bar().max_value<=menu_scroll.size.y,"Main VR menu fits without scrolling")
	check(g.hud.get_parent() is SubViewport and rig.pointers.size()==2,"Both controller pointers and viewport UI exist")
	var field: LineEdit=g.hud.name_field
	var pixel: Vector2=field.get_global_transform_with_canvas()*(field.size*.5)
	for pointer in rig.pointers:
		point_at(pointer,rig.panel,pixel)
		check(pointer.get_node("RayCast").get_collider()==rig.panel.get_node("StaticBody3D"),"Pointer hits menu instead of world behind it")
		check(absf(pointer.get_node("Laser").mesh.size.z-.79)<.03,"Visible laser stops at menu surface")
		click(pointer)
		check(field.has_focus(),"Trigger click focuses callsign field")
		pointer.get_parent().position.x+=20
		pointer.get_node("RayCast").force_raycast_update()
		pointer._process(.016)
	field.text="VR"
	field.caret_column=2
	rig._process(0)
	rig.set_process(false)
	check(rig.keyboard.visible and rig.keyboard.enabled,"Focusing callsign opens usable virtual keyboard")
	await physics_frame
	await physics_frame
	var keys=rig.keyboard.get_node("Viewport").get_child(0)
	var key=keys.get_node("Background/LowerCase").get_child(0)
	# Exercise the actual TouchScreenButton and pointer route.
	var key_pixel: Vector2=key.get_global_transform_with_canvas()*(key.key_size*.5)
	var pointer=rig.pointers[1]
	point_at(pointer,rig.keyboard,key_pixel)
	check(pointer.get_node("RayCast").get_collider()==rig.keyboard.get_node("StaticBody3D"),"Pointer targets keyboard independently")
	click(pointer)
	await process_frame
	check(field.text.length()==3,"Virtual key inserts exactly one character into callsign")
	keys.on_key_pressed("Backspace",0,false)
	await process_frame
	check(field.text=="VR","Virtual Backspace edits callsign")
	keys.on_key_pressed("Enter",0,false)
	await process_frame
	check(not field.has_focus(),"Virtual Enter finishes callsign editing")
	check(preload("res://deathmatch/profile.gd").load_name()=="VR","Edited callsign persists")
	var dialog:=Window.new()
	rig.panel.get_node("Viewport").add_child(dialog)
	var dialog_field:=LineEdit.new();dialog_field.size=Vector2(180,40);dialog.add_child(dialog_field)
	dialog.popup_centered(Vector2i(240,100));dialog_field.grab_focus()
	await process_frame
	keys.on_key_pressed("A",97,false)
	await process_frame
	check(dialog_field.text=="a","Virtual keyboard routes text to embedded dialog focus")
	dialog.hide();dialog.queue_free()
	# All voice controls must be selectable through the actual world-space pointer.
	var voice_panel=g.voice.panel
	point_at(pointer,rig.panel,g.hud.voice_button.get_global_transform_with_canvas()*(g.hud.voice_button.size*.5))
	click(pointer)
	await process_frame;await process_frame
	check(voice_panel.visible and voice_panel.get_parent()==g.hud.get_child(0),"Voice panel opens inside VR canvas")
	# Include Android-only retry control when checking the smallest menu layout.
	for button in voice_panel.find_children("*","Button",true,false):
		if button.text=="RETRY ACCESS": button.show()
	await process_frame;await process_frame
	check(voice_panel.size.y<=640 and voice_panel.close.get_global_rect().end.y<=960,"Voice controls fit the VR viewport including Android retry")
	for mode in [2,0,1]:
		var button: Button=voice_panel.modes[mode]
		point_at(pointer,rig.panel,button.get_global_transform_with_canvas()*(button.size*.5))
		click(pointer)
		check(g.voice.mode==mode,"Controller selects voice mode %d"%mode)
	point_at(pointer,rig.panel,voice_panel.mute.get_global_transform_with_canvas()*(voice_panel.mute.size*.5))
	click(pointer)
	check(g.voice.muted_all,"Controller toggles incoming voice mute")
	point_at(pointer,rig.panel,voice_panel.volume.get_global_transform_with_canvas()*Vector2(voice_panel.volume.size.x*.25,voice_panel.volume.size.y*.5))
	click(pointer)
	check(g.voice.volume<.4,"Controller adjusts voice playback volume")
	g.players[2]=g._new_state("Test speaker",2)
	voice_panel.elapsed=1;voice_panel.refresh(0)
	await process_frame;await process_frame
	var peer_mute: CheckButton=voice_panel.peers.get_child(0)
	point_at(pointer,rig.panel,peer_mute.get_global_transform_with_canvas()*(peer_mute.size*.5))
	click(pointer)
	check(g.voice.muted.has(2),"Controller mutes an individual player")
	point_at(pointer,rig.panel,voice_panel.close.get_global_transform_with_canvas()*(voice_panel.close.size*.5))
	click(pointer)
	check(not voice_panel.visible,"Controller closes voice panel")
	var settings_button: Button
	for button in g.hud.menu.find_children("*","Button",true,false):
		if button.text=="SETTINGS…":settings_button=button
	point_at(pointer,rig.panel,settings_button.get_global_transform_with_canvas()*(settings_button.size*.5));click(pointer)
	await process_frame;await process_frame
	var settings=g.hud.settings_panel
	check(settings.visible and settings.size.y<=640,"Audio and graphics options open and fit the VR canvas")
	var music_before:float=settings.values.music
	var music_plus:Button=settings.controls.music.get_parent().get_child(3)
	point_at(pointer,rig.panel,music_plus.get_global_transform_with_canvas()*(music_plus.size*.5));click(pointer)
	check(is_equal_approx(settings.values.music,minf(1,music_before+.1)),"Controller changes music volume through the real menu pointer")
	var graphics_button:Button
	for button in settings.find_children("*","Button",true,false):
		if button.text=="GRAPHICS":graphics_button=button
	point_at(pointer,rig.panel,graphics_button.get_global_transform_with_canvas()*(graphics_button.size*.5));click(pointer)
	await process_frame;await process_frame
	var msaa_before:int=settings.values.msaa
	var msaa_button:Button=settings.controls.msaa
	point_at(pointer,rig.panel,msaa_button.get_global_transform_with_canvas()*(msaa_button.size*.5));click(pointer)
	check(settings.values.msaa==(msaa_before+1)%4,"Controller configures graphics without a native popup")
	settings.section="controls";settings.refresh()
	await process_frame;await process_frame
	var turn_button: Button=settings.controls.vr_controls
	point_at(pointer,rig.panel,turn_button.get_global_transform_with_canvas()*(turn_button.size*.5));click(pointer)
	await process_frame;await process_frame
	check(rig.turn_panel.visible,"Controller opens turn settings inside VR menu")
	rig.turn_speed=120;rig.snap_angle=30;rig.smooth_turn=true
	for button in [rig.turn_panel.speed_up,rig.turn_panel.angle_up,rig.turn_panel.mode]:
		point_at(pointer,rig.panel,button.get_global_transform_with_canvas()*(button.size*.5));click(pointer)
	check(rig.turn_speed==150 and rig.snap_angle==35 and not rig.smooth_turn,"Controller configures turn speed, snap angle and mode")
	var turn_settings=preload("res://deathmatch/vr/preferences.gd").read_settings()
	check(turn_settings.turn_speed==150 and turn_settings.snap_angle==35 and not turn_settings.smooth_turn,"Turn preferences persist in client config")
	for button in [rig.turn_panel.controls,rig.turn_panel.seat]:
		point_at(pointer,rig.panel,button.get_global_transform_with_canvas()*(button.size*.5));click(pointer)
	check(rig.left_controls and rig.seated,"Controller enables mirrored controls and seated mode")
	check(rig.turn_panel.size.y<=640,"Expanded VR controls fit headset canvas")
	rig.left_controls=false;rig.seated=false
	rig.turn_panel.hide()
	g.active=true;g.menu_open=false
	rig._process(0)
	check(not rig.keyboard.visible and not rig.panel.enabled and not rig.pointers[0].enabled,"Closing menu disables keyboard and pointers")
	g.active=false;g.set_physics_process(false);g.hud.show_menu(true);rig.panel.visible=true
	var fortress=preload("res://deathmatch/modes/fortress_panel.gd").new();g.hud.get_child(0).add_child(fortress);fortress.setup(g);fortress.open()
	g.menu_open=true;rig.panel.enabled=true;pointer.enabled=true
	await process_frame;await process_frame
	fortress.choice.vr_mode_override=true
	point_at(pointer,rig.panel,fortress.choice.trigger.get_global_transform_with_canvas()*(fortress.choice.trigger.size*.5));click(pointer)
	await process_frame;await process_frame
	check(fortress.choice.popup.visible,"TF class popup opens inside the VR viewport")
	check(not fortress.choice.scroll.get_v_scroll_bar().visible,"VR dropdown hides its scrollbar")
	var previous_class: String=fortress.choice.value
	var drag_at: Vector2=fortress.choice.entries.get_child(2).get_global_transform_with_canvas()*(fortress.choice.entries.get_child(2).size*.5)
	point_at(pointer,rig.panel,drag_at);pointer._button_pressed()
	point_at(pointer,rig.panel,drag_at-Vector2(0,120));pointer._button_released()
	await process_frame
	check(fortress.choice.scroll.scroll_vertical>40,"Holding trigger and dragging scrolls the VR class list")
	check(fortress.choice.popup.visible and fortress.choice.value==previous_class,"Dragging does not accidentally select or close the class list")
	fortress.choice.scroll.scroll_vertical=0;await process_frame
	var class_item=fortress.choice.entries.get_child(0)
	point_at(pointer,rig.panel,class_item.get_global_transform_with_canvas()*(class_item.size*.5));click(pointer)
	check(fortress.choice.value=="scout" and not fortress.choice.popup.visible,"Releasing a stationary trigger selects the TF class")
	fortress.hide();fortress.queue_free()
	g.hud.open_bindings()
	await process_frame;await process_frame
	var bindings=g.hud.bindings_panel
	var bindings_scroll=bindings.find_child("BindingsScroll",true,false)
	bindings_scroll.vr_mode_override=true
	var start_drag:Vector2=bindings_scroll.get_global_transform_with_canvas()*Vector2(120,bindings_scroll.size.y-65)
	point_at(pointer,rig.panel,start_drag);pointer._button_pressed()
	point_at(pointer,rig.panel,start_drag-Vector2(0,300));pointer._button_released()
	await process_frame
	check(bindings_scroll.scroll_vertical>=190 and bindings.capture.is_empty(),"Bindings page trigger-drag scrolls without capturing a desktop binding")
	var selectors:Array=bindings.find_children("*","VBoxContainer",true,false).filter(func(n):return n.get_script()==preload("res://deathmatch/ui/choice.gd"))
	var binding_choice=selectors.back();binding_choice.vr_mode_override=true
	bindings_scroll.ensure_control_visible(binding_choice.trigger)
	await process_frame;await process_frame
	point_at(pointer,rig.panel,binding_choice.trigger.get_global_transform_with_canvas()*(binding_choice.trigger.size*.5));click(pointer)
	await process_frame;await process_frame
	check(binding_choice.popup.visible,"Binding selector opens after scrolling the outer bindings page")
	var binding_before:String=binding_choice.value
	var row=binding_choice.entries.get_child(1)
	var at:Vector2=row.get_global_transform_with_canvas()*(row.size*.5)
	point_at(pointer,rig.panel,at);pointer._button_pressed()
	point_at(pointer,rig.panel,at-Vector2(0,190));pointer._button_released()
	await process_frame
	check(binding_choice.popup.visible and binding_choice.value==binding_before and binding_choice.scroll.scroll_vertical>100,"Bindings dropdown drag continues outside the popup without selecting or closing")
	binding_choice.scroll.scroll_vertical=0;await process_frame
	row=binding_choice.entries.get_child(0)
	point_at(pointer,rig.panel,row.get_global_transform_with_canvas()*(row.size*.5));click(pointer)
	check(not binding_choice.popup.visible and binding_choice.value==binding_choice.items[0].id,"Bindings dropdown accepts a deliberate selection after dragging")
	bindings.hide()
	# Exercise the persistent selector through the same controller-to-viewport route on a wall.
	g.set_physics_process(false);g.headless=false
	g.lobby.offered=[{"mode":"dm","map":"lqdm1"},{"mode":"ctf","map":"lqdm2"}]
	g.lobby.until=g.clock+60;g.lobby.build()
	var wall=g.get_node("Map/WaitingRoom/VoteWall")
	await process_frame;await process_frame;await physics_frame
	var selector=wall.panel.selector
	pointer.enabled=true;pointer.visible=true
	point_at(pointer,wall.surface,selector.modes.trigger.get_global_transform_with_canvas()*(selector.modes.trigger.size*.5));click(pointer)
	await process_frame;await process_frame
	check(selector.modes.popup.visible,"Controller opens wall-mounted mode popup")
	for i in 4:wall.panel.refresh();await process_frame
	check(selector.modes.popup.visible,"Wall mode popup survives live lobby refresh")
	var option=selector.modes.entries.get_child(1)
	point_at(pointer,wall.surface,option.get_global_transform_with_canvas()*(option.size*.5));click(pointer)
	await process_frame;await process_frame
	check(selector.modes.value=="ctf" and selector.maps.items.size()==1,"Controller selects mode and filters the wall maplist")
	point_at(pointer,wall.surface,selector.maps.trigger.get_global_transform_with_canvas()*(selector.maps.trigger.size*.5));click(pointer)
	await process_frame;await process_frame
	option=selector.maps.entries.get_child(0)
	point_at(pointer,wall.surface,option.get_global_transform_with_canvas()*(option.size*.5));click(pointer)
	check(selector.maps.value=="lqdm2","Controller selects map through wall viewport popup")
	var offered_before: Array=g.lobby.offered.duplicate(true)
	wall.panel.set_meta("drag_test_options",[{"mode":"ctf","map":"dummy_map","title":"DRAG TEST MAP"}]);wall.panel.refresh()
	selector.maps.choose("dummy_map");wall.panel.refresh()
	check(wall.panel.vote.disabled and wall.panel.status.text.contains("TEST ENTRY"),"Dummy drag-test entries cannot be submitted as lobby votes")
	check(g.lobby.offered==offered_before,"Drag-test entries leave the real server maplist unchanged")
	# Text chat takes the same authoritative RPC path for desktop and VR recipients.
	g.clock=100;g.players[2].chat_at=0
	g._chat_for(2,"Hello\nVR [b]friends[/b]")
	rig._process(0)
	check(rig.status_hud.chat_messages==PackedStringArray(["Test speaker: Hello VR [b]friends[/b]"]),"Authoritative text chat reaches the VR notification HUD with sender and literal markup")
	for i in 6:g._announcement("Combat event %d"%i)
	rig._process(0)
	check(rig.status_hud.chat_messages.size()==1,"Combat feed bursts do not evict VR chat")
	g._announcement("Second speaker: "+"Hello everyone! ".repeat(9).left(140),true)
	g._announcement("Third speaker: Last message",true)
	rig._process(0)
	check(g.chat_feed.size()==2 and rig.status_hud.chat_messages[1]=="Third speaker: Last message","VR chat keeps the two most recent messages in order")
	rig.status_hud.update_capture({"text":"FLAG CAPTURED","detail":"RED +1","team":0})
	rig.status_hud.update_vote({"title":"CHANGE MAP","yes":1,"needed":2,"no":0,"seconds":20})
	await process_frame
	check(not rig.status_hud.capture_text.is_empty() and not rig.status_hud.vote_text.is_empty() and rig.status_hud.chat_labels[1].text=="Third speaker: Last message","Chat coexists with capture and vote notifications")
	check(rig.status_hud.chat_labels[0].get_line_count()>1 and rig.status_hud.chat_labels[0].get_line_count()<=3,"Long chat wraps within its notification slot")
	check(is_equal_approx(rig.status_surface.mesh.size.y*.5-rig.status_surface.mesh.center_offset.y,.146),"Chat space preserves the existing HUD position and pixel scale")
	g.clock=108;rig._process(0)
	check(rig.status_hud.chat_messages.is_empty() and rig.status_hud.chat_labels[1].text.is_empty(),"Chat notifications expire after eight seconds")
	g._announcement("Old session: goodbye",true)
	g.disconnect_game();rig._process(0)
	check(g.chat_feed.is_empty() and rig.status_hud.chat_messages.is_empty(),"Disconnect clears chat before joining another server")
	g.free()
	if had_config:
		var config_file:=FileAccess.open(config_path,FileAccess.WRITE)
		config_file.store_buffer(saved_config)
	else: DirAccess.remove_absolute(config_path)
	print("VR_UI_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
