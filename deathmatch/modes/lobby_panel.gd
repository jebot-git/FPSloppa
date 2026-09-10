extends PanelContainer
var game
var list: OptionButton
var status: Label
var vote: Button
var choices: Array=[]
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new();add_child(column)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	list=OptionButton.new();list.custom_minimum_size.y=64;column.add_child(list)
	vote=Button.new();vote.text="VOTE FOR THIS MATCH";vote.custom_minimum_size.y=64;column.add_child(vote)
	vote.pressed.connect(func():
		if list.selected>=0 and list.selected<choices.size():game.lobby.submit(choices[list.selected].mode,choices[list.selected].map))
	var back:=Button.new();back.text="BACK TO LOBBY";back.custom_minimum_size.y=64;column.add_child(back)
	back.pressed.connect(func():hide();game.menu_open=false;game.hud.show_menu(false))
func open() -> void:show();get_parent().move_child(self,-1);refresh()
func _process(_delta: float) -> void:
	if visible:refresh()
func refresh() -> void:
	var data: Dictionary=game.lobby.snapshot() if game.multiplayer.is_server() else game.lobby.view
	if not game.lobby.active():hide();return
	var options: Array=data.get("options",[])
	if list.item_count!=options.size():
		list.clear()
		for option in options:list.add_item(option.mode.to_upper()+" · "+option.map)
	choices=options
	for i in options.size():list.set_item_text(i,options[i].mode.to_upper()+" · "+options[i].map+" · "+str(options[i].votes)+" votes")
	status.text="WAITING LOBBY · %ds\nMove around and talk. Each player has one changeable vote. Most votes wins; ties prefer the next rotation map."%data.get("seconds",0)
	vote.disabled=choices.is_empty() or game.local_state().get("spectator",true)
