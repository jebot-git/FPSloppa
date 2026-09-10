extends PanelContainer
var game
var list=preload("res://deathmatch/ui/choice.gd").new()
var files: Array=[]
var status: Label
var record: Button
var actions: GridContainer
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(20))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	var title:=Label.new();title.text="DEMOS";title.add_theme_font_override("font",preload("res://deathmatch/ui/BebasNeue-Regular.ttf"));title.add_theme_font_size_override("font_size",28);column.add_child(title)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	column.add_child(list)
	actions=GridContainer.new();actions.columns=2;actions.add_theme_constant_override("h_separation",8);actions.add_theme_constant_override("v_separation",6);column.add_child(actions)
	record=button(actions,"START / STOP RECORDING",func():
		if game.demos.recording:game.demos.stop_record()
		else:game.demos.start_record()
		refresh())
	button(actions,"PLAY SELECTED DEMO",func():
		if not list.value.is_empty():
			if game.demos.open_demo(list.value):hide()
			refresh())
	button(actions,"PAUSE / RESUME",func():game.demos.paused=not game.demos.paused)
	button(actions,"NEXT PLAYER",func():game.demos.next_player())
	for view in ["first","chase","free"]:button(actions,view.to_upper()+" CAMERA",func():game.demos.viewpoint=view)
	button(actions,"SPEED 0.5× / 1× / 2×",func():game.demos.speed=.5 if game.demos.speed>=2 else game.demos.speed*2)
	button(actions,"SEEK −5s",func():game.demos.seek(game.demos.position_seconds-5))
	button(actions,"SEEK +5s",func():game.demos.seek(game.demos.position_seconds+5))
	button(actions,"STOP PLAYBACK",func():game.demos.stop_playback();game.disconnect_game("Demo stopped");refresh())
	var space:=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(space)
	button(column,"BACK",hide)
func button(parent: Node,title: String,action: Callable) -> Button:
	var b:=Button.new();b.text=title;b.custom_minimum_size=Vector2(240,40);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(b);b.pressed.connect(action);return b
func refresh() -> void:
	files.clear()
	for file in DirAccess.get_files_at(game.demos.folder()):
		if file.ends_with(".fpsdemo"):files.append({"id":game.demos.folder()+file,"title":file})
	list.configure(files,"SELECT DEMO")
	status.text=game.demos.message+"\nVoice conversations are not recorded."
	record.disabled=not game.active or game.demos.playing
func open() -> void:refresh();show();get_parent().move_child(self,-1)
