extends PanelContainer
var game
var selector=preload("res://deathmatch/modes/match_selector.gd").new()
var status: Label
var active_vote: Label
var response: Label
var next_match: Label
var vote: Button
var yes: Button
var no: Button
var wall:=false
var refresh_left:=0.0
func setup(arena: Node) -> void:
	game=arena;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(20))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);add_child(column)
	status=label(column)
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",28);column.add_child(columns)
	var propose:=VBoxContainer.new();propose.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(propose)
	label(propose).text="PROPOSE THE NEXT MATCH"
	propose.add_child(selector)
	vote=button(propose,"PROPOSE NEXT MATCH",func():
		if selector.ready_to_vote():game.lobby.submit(selector.modes.value,selector.maps.value))
	label(propose).text="Choose a mode, then a map from its server maplist. A majority must approve the proposal."
	var ballot:=VBoxContainer.new();ballot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ballot.add_theme_constant_override("separation",12);columns.add_child(ballot)
	label(ballot).text="CURRENT VOTE"
	active_vote=label(ballot);active_vote.custom_minimum_size.y=135
	var buttons:=HBoxContainer.new();ballot.add_child(buttons)
	yes=button(buttons,"YES",func():game.votes.vote(true));yes.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	no=button(buttons,"NO",func():game.votes.vote(false));no.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	response=label(ballot);response.custom_minimum_size.y=66
	next_match=label(column)
	if not wall:button(column,"BACK TO LOBBY",func():hide();game.menu_open=false;game.hud.show_menu(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if game.is_vr() else Input.MOUSE_MODE_CAPTURED)
	selector.changed.connect(refresh);refresh()
func label(parent: Node) -> Label:
	var item:=Label.new();item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(item);return item
func button(parent: Node,text: String,action: Callable) -> Button:
	var item:=Button.new();item.text=text;item.custom_minimum_size.y=54;parent.add_child(item);item.pressed.connect(action);return item
func open() -> void:show();get_parent().move_child(self,-1);refresh()
func _process(delta: float) -> void:
	refresh_left-=delta
	if visible and refresh_left<=0:refresh();refresh_left=.1
func refresh() -> void:
	if not game.lobby.active():hide();return
	var data: Dictionary=game.lobby.snapshot() if game.multiplayer.is_server() else game.lobby.view
	var real_options: Array=data.get("options",[])
	var options: Array=real_options.duplicate();options.append_array(get_meta("drag_test_options",[]))
	selector.configure(options,game.match_mode.NAMES)
	var ballot: Dictionary=game.votes.snapshot() if game.multiplayer.is_server() else game.votes.view
	var mine: int=game.multiplayer.get_unique_id()
	var spectator: bool=game.local_state().get("spectator",true)
	status.text="WAITING LOBBY · NEXT MATCH IN %ds"%data.get("seconds",0)
	active_vote.text="No vote in progress.\nPropose a mode and map on the left." if ballot.is_empty() else "%s\nYES %d / %d needed · NO %d\n%d seconds remaining"%[ballot.title,ballot.yes,ballot.needed,ballot.no,ballot.seconds]
	var voted: bool=mine in ballot.get("voted",[])
	var eligible: bool=mine in ballot.get("eligible",[])
	yes.disabled=ballot.is_empty() or voted or spectator or not eligible;no.disabled=yes.disabled
	response.text="" if ballot.is_empty() else "Spectators cannot vote." if spectator else ("You voted YES." if ballot.get("responses",{}).get(mine,false) else "You voted NO.") if voted else "You joined after this vote started." if not eligible else "Choose YES or NO. One response per player."
	var chosen: Dictionary=data.get("next",{})
	next_match.text="NEXT: %s / %s · %s\n%s"%[chosen.get("mode","?").to_upper(),chosen.get("map","?"),"VOTE APPROVED" if data.get("confirmed",false) else "ROTATION DEFAULT",data.get("result","")]
	var valid: bool=real_options.any(func(row):return row.mode==selector.modes.value and row.map==selector.maps.value)
	vote.disabled=not game.votes.enabled or not selector.ready_to_vote() or not valid or spectator or not ballot.is_empty() or data.get("proposal_wait",0.0)>0
	if ballot.is_empty() and data.get("proposal_wait",0.0)>0:response.text="New proposal available in %ds"%ceili(data.proposal_wait)
	if selector.ready_to_vote() and not valid:status.text+="\nTEST ENTRY · drag testing only"
