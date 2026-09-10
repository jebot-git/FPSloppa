extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func click(control: Control):
	var pos:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=pos;event.pressed=down;root.push_input(event,true)
func run():
	root.size=Vector2i(854,640)
	root.content_scale_size=Vector2i(854,640)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.hud=preload("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
	await process_frame;await process_frame
	var quit_button: Control=game.hud.menu.get_node("QuitFooter")
	check(quit_button.get_global_rect().end.y<=640 and quit_button.size.y>=44,"Quit remains inside the 640px VR canvas with a usable target")
	game.hud.open_host();await process_frame;await process_frame
	check(game.hud.host_panel.visible and game.hud.host_panel.size.y<=640,"Host button opens a separate setup menu that fits VR")
	check(game.hud.host_panel.is_ancestor_of(game.hud.map_choice) and game.hud.host_panel.is_ancestor_of(game.hud.frags),"Map and match limits live exclusively in Host setup")
	check(game.hud.host_mode.items.size()==game.match_mode.NAMES.size(),"Host menu offers every supported game mode")
	game.hud.host_panel.hide()
	game.hud.open_demos();await process_frame;await process_frame
	var demos=game.hud.demos_panel
	check(demos.actions.columns==2 and demos.actions.get_children().all(func(b):return b.get_global_rect().end.y<=596),"Demo actions fit in two compact columns within the VR canvas")
	check(demos.size.y<=640,"Demo menu and Back fit without overflow")
	demos.hide()
	game.active=true;game._add_player(1,"Test");game._add_player(2,"Other")
	game.votes.allowed_modes=["dm","ctf"];game.mode_maplists={"dm":["lqdm1","lqdm2"],"ctf":["lqdm1"]}
	var panel=game.hud.votes_panel;panel.open();await process_frame;await process_frame
	var selector=panel.selector
	check(selector.maps.trigger.disabled,"Map selection is disabled until mode is selected")
	click(selector.modes.trigger);await process_frame;await process_frame
	check(selector.modes.popup.visible,"Mouse/pointer press opens embedded mode popup")
	for i in 5:panel.refresh();await process_frame
	check(selector.modes.popup.visible,"Mode popup stays open across live vote refreshes")
	click(selector.modes.entries.get_child(1));await process_frame;await process_frame
	check(selector.modes.value=="ctf" and not selector.modes.popup.visible,"Selecting a mode closes only its popup")
	check(selector.maps.items.size()==1 and selector.maps.items[0].id=="lqdm1","Map choices follow selected mode's server maplist")
	click(selector.maps.trigger);await process_frame
	click(selector.maps.entries.get_child(0));await process_frame
	check(selector.ready_to_vote(),"Map entry remains clickable in the same VR canvas")
	check(not game.votes.start(1,"match","ctf|lqdm2"),"Server rejects maps outside the requested mode maplist")
	check(game.votes.start(1,"match","ctf|lqdm1"),"Server accepts valid combined mode and map ballot")
	check(game.votes.snapshot().title.contains("ctf / lqdm1"),"Vote notification identifies both mode and map")
	game.menu_open=false;game.hud.show_menu(false);await process_frame
	check(game.hud.vote_alert.visible and game.hud.vote_alert.text.contains("YES 1/2"),"Active vote has a persistent visible HUD alert and counts")
	game.active=false;game.queue_free();await process_frame;await process_frame
	print("VOTE_UI_RESULT ",failures);quit(0 if failures.is_empty() else 1)
