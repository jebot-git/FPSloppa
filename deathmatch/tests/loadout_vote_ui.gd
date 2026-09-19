extends SceneTree
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func click(control:Control):
	var point:=control.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
func draw(path:String):
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/loadout-votes/"+path+".png")
func run():
	root.size=Vector2i(854,640);root.content_scale_size=root.size
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
	g.start_host("Vote UI",0,100,60,true,"dm","doom");g.practice=false;g._add_player(2,"Other voter")
	g.votes.allowed_modes=["dm","tf","ig"];g.mode_maplists={"dm":["qsrc_dm1"],"tf":["tf_ironspan"],"ig":["qsrc_dm1"]}
	g.hud.show_menu(true);var panel=g.hud.votes_panel;panel.open()
	var selector=panel.selector;selector.modes.choose("dm");selector.maps.choose("qsrc_dm1")
	await process_frame;await process_frame
	check(selector.loadouts.items.size()==3 and selector.loadouts.value=="doom","Eligible match offers all three loadouts")
	click(selector.loadouts.trigger);await process_frame;panel.refresh();await process_frame
	check(selector.loadouts.popup.visible,"Loadout popup remains open across vote refresh")
	click(selector.loadouts.entries.get_child(1));await process_frame;panel.refresh()
	check(selector.loadouts.value=="quake" and not panel.call_loadout.disabled and not panel.call_map.disabled,"Pointer selection enables loadout-only and same-map match votes")
	panel.call_loadout.pressed.emit();panel.refresh()
	check(g.votes.ballot.get("kind","")=="loadout" and panel.notice.text.contains("QUAKE"),"In-game button proposes a visible loadout ballot")
	check(panel.get_combined_minimum_size().y<=640 and panel.get_global_rect().end.y<=640,"In-game vote menu fits the 640-pixel VR canvas")
	await draw("ingame-quake")
	g.votes.reset();selector.modes.choose("tf");selector.maps.choose("tf_ironspan");panel.refresh()
	check(selector.loadouts.value=="quake" and selector.loadouts.trigger.disabled and selector.loadouts.items.size()==1,"TF offers only its fixed Quake loadout")
	selector.modes.choose("ig");check(selector.loadouts.value=="doom" and selector.loadouts.trigger.disabled,"Instagib keeps its fixed Doom arsenal")
	g.match_mode.kind="tf";panel.refresh();check(not panel.call_loadout.visible,"Loadout-only action is hidden in a fixed-loadout match")
	panel.hide();g.hud.hide();root.size=Vector2i(1200,720);root.content_scale_size=root.size
	g.lobby.build();g.lobby.prepare();g.lobby.until=g.clock+45
	var lobby=load("res://deathmatch/modes/lobby_panel.gd").new();lobby.wall=true;root.add_child(lobby);lobby.setup(g)
	var index: int=g.lobby.offered.find(g.lobby.offered.filter(func(row):return row.mode=="dm" and row.rules=="ut99")[0])
	lobby.cards[index].button.pressed.emit();lobby.refresh()
	check(g.lobby.selections.get(1)==index and lobby.cards[index].count.text.contains("YOUR VOTE"),"Lobby card casts a complete loadout vote in one click")
	g.lobby.cast_option(2,g.lobby.ballot_id,index);lobby.refresh()
	check(g.lobby.result().rules=="ut99" and lobby.next_match.text.contains("UT99"),"Lobby displays leading loadout alongside next mode and map")
	await draw("lobby-ut99")
	check(lobby.get_combined_minimum_size().y<=720 and lobby.get_global_rect().end.y<=720,"Lobby voting wall fits its 720-pixel canvas")
	g.active=false;lobby.free();g.free();await process_frame
	print("LOADOUT_VOTE_UI_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
