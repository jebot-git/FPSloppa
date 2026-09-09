extends PanelContainer
var game
var summary: Label
var mode_row: HBoxContainer
var mode_choices: OptionButton
var call_mode: Button
var choices: OptionButton
var yes: Button
var no: Button
var red: Button
var blue: Button
var balance: Button
var call_map: Button
var notice: Label
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(24))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	var title:=Label.new();title.text="TEAMS & PLAYER VOTES";title.add_theme_font_override("font",preload("res://deathmatch/ui/BebasNeue-Regular.ttf"));title.add_theme_font_size_override("font_size",32);column.add_child(title)
	summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(summary)
	var teams:=HBoxContainer.new();column.add_child(teams)
	red=button(teams,"JOIN RED",func():game.votes.switch_team(0));blue=button(teams,"JOIN BLUE",func():game.votes.switch_team(1))
	balance=button(teams,"VOTE TO BALANCE",func():game.votes.propose("balance"))
	var map_row:=HBoxContainer.new();column.add_child(map_row)
	choices=OptionButton.new();choices.custom_minimum_size=Vector2(300,44);choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_row.add_child(choices)
	call_map=button(map_row,"VOTE: MAP",func():
		if choices.selected>=0:game.votes.propose("map",choices.get_item_metadata(choices.selected)))
	mode_row=HBoxContainer.new();column.add_child(mode_row)
	mode_choices=OptionButton.new();mode_choices.custom_minimum_size=Vector2(300,44);mode_choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mode_row.add_child(mode_choices)
	call_mode=button(mode_row,"VOTE: MODE",func():
		if mode_choices.selected>=0:game.votes.propose("mode",mode_choices.get_item_metadata(mode_choices.selected)))
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.y=65;column.add_child(notice)
	var row:=HBoxContainer.new();column.add_child(row);yes=button(row,"VOTE YES",func():game.votes.vote(true));no=button(row,"VOTE NO",func():game.votes.vote(false))
	var help:=Label.new();help.text="Switch to the smaller team, or vote to reshuffle teams.\nVotes need a majority of active players within 25 seconds.\nSpectators cannot vote. Proposals have a 60-second cooldown.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(help)
	var space:=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(space);button(column,"BACK",hide)
func button(parent: Node,title: String,action: Callable) -> Button:
	var b:=Button.new();b.text=title;b.custom_minimum_size=Vector2(100,44);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(b);b.pressed.connect(action);return b
func open() -> void:
	choices.clear()
	var maps: Array=game.votes.choices() if game.multiplayer.is_server() else game.votes.allowed_maps
	for map in maps:
		choices.add_item(map.title);choices.set_item_metadata(choices.item_count-1,map.id)
	mode_choices.clear()
	for mode in game.votes.allowed_modes:
		mode_choices.add_item(game.match_mode.NAMES[mode]);mode_choices.set_item_metadata(mode_choices.item_count-1,mode)
	get_parent().move_child(self,-1);show();refresh()
func _process(_delta: float) -> void:
	if visible:refresh()
func refresh() -> void:
	var s: Dictionary=game.local_state();var team_mode: bool=game.match_mode.team_game()
	summary.text=game.match_mode.status(game.multiplayer.get_unique_id())
	var allowed: bool=game.active and not game.practice and not s.is_empty() and not s.spectator and game.intermission<=0 and not game.map_loading
	var counts: Array=[0,0]
	for player in game.players.values():
		if player.team>=0 and not player.spectator:counts[player.team]+=1
	red.visible=team_mode;blue.visible=team_mode;balance.visible=team_mode
	red.disabled=not allowed or s.get("team",-1)==0 or counts[0]>=counts[1]
	blue.disabled=not allowed or s.get("team",-1)==1 or counts[1]>=counts[0]
	balance.disabled=not allowed or not game.votes.enabled
	mode_row.visible=game.votes.allowed_modes.size()>1
	call_mode.disabled=not allowed or not game.votes.enabled
	call_map.disabled=not allowed or not game.votes.enabled or choices.item_count==0
	var vote: Dictionary=game.votes.snapshot() if game.multiplayer.is_server() else game.votes.view
	var voted: bool=not vote.is_empty() and vote.voted.has(game.multiplayer.get_unique_id())
	yes.disabled=not allowed or vote.is_empty() or voted;no.disabled=yes.disabled
	notice.text="No active vote." if vote.is_empty() else "%s\nYES %d / %d required · NO %d · %ds"%[vote.title,vote.yes,vote.needed,vote.no,vote.seconds]
	if not game.votes.enabled:notice.text="Player voting is disabled by the server."
