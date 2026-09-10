extends PanelContainer
var game
var list: OptionButton
var files: Array=[]
var status: Label
var record: Button
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new();add_child(column)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	record=button(column,"START / STOP RECORDING",func():
		if game.demos.recording:game.demos.stop_record()
		else:game.demos.start_record()
		refresh())
	list=OptionButton.new();list.custom_minimum_size.y=56;column.add_child(list)
	button(column,"PLAY SELECTED DEMO",func():
		if list.selected>=0 and list.selected<files.size():
			if game.demos.open_demo(files[list.selected]):hide()
			refresh())
	button(column,"PAUSE / RESUME",func():game.demos.paused=not game.demos.paused)
	button(column,"NEXT PLAYER",func():game.demos.next_player())
	for view in ["first","chase","free"]:button(column,view.to_upper()+" CAMERA",func():game.demos.viewpoint=view)
	button(column,"SPEED 0.5× / 1× / 2×",func():game.demos.speed=.5 if game.demos.speed>=2 else game.demos.speed*2)
	button(column,"SEEK −5s",func():game.demos.seek(game.demos.position_seconds-5))
	button(column,"SEEK +5s",func():game.demos.seek(game.demos.position_seconds+5))
	button(column,"STOP PLAYBACK",func():game.demos.stop_playback();game.disconnect_game("Demo stopped");refresh())
	button(column,"BACK",hide)
func button(parent: Node,title: String,action: Callable) -> Button:
	var b:=Button.new();b.text=title;b.custom_minimum_size.y=44;parent.add_child(b);b.pressed.connect(action);return b
func refresh() -> void:
	files.clear();list.clear()
	for file in DirAccess.get_files_at(game.demos.folder()):
		if file.ends_with(".fpsdemo"):files.append(game.demos.folder()+file);list.add_item(file)
	status.text="DEMOS · "+game.demos.message+"\nPlayback: Tab changes player, C changes camera, Space pauses, arrows seek. Voice conversations are not recorded."
	record.disabled=not game.active or game.demos.playing
func open() -> void:refresh();show();get_parent().move_child(self,-1)
