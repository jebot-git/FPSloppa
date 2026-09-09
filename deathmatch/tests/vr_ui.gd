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
	var turn_button: Button
	for button in g.hud.vr_actions.get_children():
		if button.text=="TURN SETTINGS…":turn_button=button
	point_at(pointer,rig.panel,turn_button.get_global_transform_with_canvas()*(turn_button.size*.5));click(pointer)
	await process_frame;await process_frame
	check(rig.turn_panel.visible,"Controller opens turn settings inside VR menu")
	rig.turn_speed=120;rig.snap_angle=30;rig.smooth_turn=true
	for button in [rig.turn_panel.speed_up,rig.turn_panel.angle_up,rig.turn_panel.mode]:
		point_at(pointer,rig.panel,button.get_global_transform_with_canvas()*(button.size*.5));click(pointer)
	check(rig.turn_speed==150 and rig.snap_angle==35 and not rig.smooth_turn,"Controller configures turn speed, snap angle and mode")
	var turn_settings=preload("res://deathmatch/vr/preferences.gd").read_settings()
	check(turn_settings.turn_speed==150 and turn_settings.snap_angle==35 and not turn_settings.smooth_turn,"Turn preferences persist in client config")
	rig.turn_panel.hide()
	g.active=true;g.menu_open=false
	rig._process(0)
	check(not rig.keyboard.visible and not rig.panel.enabled and not rig.pointers[0].enabled,"Closing menu disables keyboard and pointers")
	g.free()
	if had_config:
		var config_file:=FileAccess.open(config_path,FileAccess.WRITE)
		config_file.store_buffer(saved_config)
	else: DirAccess.remove_absolute(config_path)
	print("VR_UI_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
