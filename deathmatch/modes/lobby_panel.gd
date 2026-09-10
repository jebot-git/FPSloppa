extends PanelContainer
var game
var selector=preload("res://deathmatch/modes/match_selector.gd").new()
var status: Label
var vote: Button
var wall:=false
func setup(arena: Node) -> void:
	game=arena;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(20))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	column.add_child(selector)
	vote=Button.new();vote.text="VOTE FOR THIS MATCH";vote.custom_minimum_size.y=48;column.add_child(vote)
	vote.pressed.connect(func():
		if selector.ready_to_vote():game.lobby.submit(selector.modes.value,selector.maps.value))
	var help:=Label.new();help.text="One changeable vote per player. Most votes wins.\nChoose a mode, then a map from its server maplist.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(help)
	if not wall:
		var back:=Button.new();back.text="BACK TO LOBBY";back.custom_minimum_size.y=48;column.add_child(back)
		back.pressed.connect(func():hide();game.menu_open=false;game.hud.show_menu(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if game.is_vr() else Input.MOUSE_MODE_CAPTURED)
	refresh()
func open() -> void:show();get_parent().move_child(self,-1);refresh()
func _process(_delta: float) -> void:
	if visible:refresh()
func refresh() -> void:
	if not game.lobby.active():hide();return
	var data: Dictionary=game.lobby.snapshot() if game.multiplayer.is_server() else game.lobby.view
	var real_options: Array=data.get("options",[])
	var options: Array=real_options.duplicate()
	options.append_array(get_meta("drag_test_options",[]))
	selector.configure(options,game.match_mode.NAMES)
	var count:=0
	for option in data.get("options",[]):
		if option.mode==selector.modes.value and option.map==selector.maps.value:count=option.votes
	var saved: Dictionary=data.get("ballots",{}).get(game.multiplayer.get_unique_id(),{})
	status.text="NEXT MATCH · %ds · selected match: %d votes\nYour vote: %s"%[data.get("seconds",0),count,"not submitted" if saved.is_empty() else saved.mode.to_upper()+" / "+saved.map]

	var valid: bool=real_options.any(func(row):return row.mode==selector.modes.value and row.map==selector.maps.value)
	vote.disabled=not selector.ready_to_vote() or not valid or game.local_state().get("spectator",true)
	if selector.ready_to_vote() and not valid:status.text+="\nTEST ENTRY · drag testing only; cannot start a match"
