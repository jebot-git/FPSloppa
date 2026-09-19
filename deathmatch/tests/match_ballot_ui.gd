extends SceneTree
var failures: Array=[]
const Choice=preload("res://deathmatch/ui/choice.gd")
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func click(control: Control) -> void:
	var at:=control.get_global_transform_with_canvas()*(control.size*.5)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
func run() -> void:
	seed(1234);root.size=Vector2i(1200,720);root.content_scale_size=root.size
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
	if not g.hud:g.hud=preload("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.start_host("Ballot UI",0,100,30,true);g.practice=false
	g.votes.allowed_modes=["dm","ctf","ig"]
	g.mode_maplists={"dm":["qsrc_dm1","qsrc_dm6"],"ctf":["qsrc_dm1","qsrc_dm6"],"ig":["qsrc_dm6"]}
	g._end_round();g.hud._process(0)
	var panel=g.hud.next_match_panel
	check(panel.visible and g.menu_open and panel.grid.columns==3,"Round end automatically opens an immediately clickable 3x3 ballot")
	await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		for card in g.lobby.offered:
			for row in g.map_catalog:
				if row.id==card.map:await g.map_previews.ensure(row)
		panel.refresh()
		check(panel.cards.all(func(card):return card.preview.texture!=null),"All nine ballot cards display cached rendered map previews")
	click(panel.cards[4].button);panel.refresh()
	check(g.lobby.selections.get(1)==4 and panel.cards[4].button.button_pressed,"Desktop pointer selects a full combination with one click")
	for size in [Vector2i(1200,720),Vector2i(854,640)]:
		root.size=size;root.content_scale_size=size
		panel.refresh()
		for frame in 4:await process_frame
		check(panel.get_combined_minimum_size().y<=size.y and panel.cards[8].button.get_global_rect().end.y<size.y,"Nine choices fit the %dx%d canvas"%[size.x,size.y])
		check(panel.cards.all(func(card):return card.button.get_global_rect().encloses(card.count.get_global_rect())),"Vote counts stay inside every card at %dx%d"%[size.x,size.y])
		if DisplayServer.get_name()!="headless":
			RenderingServer.force_draw(false)
			DirAccess.make_dir_recursive_absolute("res://test-results/match-ballot")
			root.get_texture().get_image().save_png("res://test-results/match-ballot/grid-%dx%d.png"%[size.x,size.y])
	g.menu_open=false;g.hud.show_menu(false);g.hud._process(0)
	check(not panel.visible,"Closing the intermission ballot does not reopen it every frame")
	g.menu_open=true;g.hud.show_menu(true)
	var choice=Choice.new();g.hud.menu.add_child(choice);choice.position=Vector2(20,20);choice.size=Vector2(320,48)
	var options: Array=[]
	for index in 30:options.append({"id":str(index),"title":"Option %02d"%index})
	choice.configure(options,"TEST SCROLL")
	await process_frame;await process_frame;choice.open_popup();await process_frame;await process_frame
	var event:=InputEventJoypadMotion.new();event.axis=JOY_AXIS_LEFT_Y;event.axis_value=1;root.push_input(event,true);choice._process(.4)
	check(choice.scroll.scroll_vertical>100 and choice.popup.visible and choice.value.is_empty(),"Gamepad joystick scrolls the dropdown without selecting a row")
	event=InputEventJoypadMotion.new();event.axis=JOY_AXIS_LEFT_Y;event.axis_value=-1;root.push_input(event,true);choice._process(.4)
	check(choice.scroll.scroll_vertical==0,"Gamepad joystick also scrolls upward")
	event=InputEventJoypadMotion.new();event.axis=JOY_AXIS_LEFT_Y;event.axis_value=.1;root.push_input(event,true);choice._process(1)
	check(choice.scroll.scroll_vertical==0,"Joystick deadzone prevents menu drift")
	choice.drag_pressed=true;g.hud.show_menu(false)
	check(not choice.popup.visible and not choice.drag_pressed and choice.joy_axes.is_empty(),"Menu close clears every dropdown's popup and input state immediately")
	g.hud.show_menu(true);await process_frame
	check(not choice.popup.visible,"Reopening the menu does not resurrect an old dropdown")
	g.demos.playing=true;g.lobby.view={"options":[{"mode":"dm","map":"qsrc_dm1"}],"seconds":20};panel.show();panel.refresh()
	check(panel.cards[0].button.disabled and panel.response.text.contains("legacy"),"Older demo lobby options remain readable without offering live votes")
	g.demos.playing=false
	if DisplayServer.get_name()!="headless":
		g.lobby.enabled=true;g.lobby.begin();g.menu_open=false;g.hud.show_menu(false)
		var wall=g.get_node("Map/WaitingRoom/VoteWall")
		wall.panel.refresh()
		check(wall.panel.cards.all(func(card):return card.preview.texture!=null),"Lobby wall shares the same cached previews as the intermission ballot")
		g.camera.global_position=Vector3(-4,3.4,-2);g.camera.look_at(wall.global_position);g.camera.make_current()
		for frame in 6:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://test-results/match-ballot/lobby-preview-wall.png")
	print("MATCH_BALLOT_UI_RESULT ",JSON.stringify(failures))
	if DisplayServer.get_name()!="headless":
		await g.request_quit()
	else:
		g.disconnect_game();await process_frame;await process_frame;g.free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
