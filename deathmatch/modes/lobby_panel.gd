extends PanelContainer
## One click per complete match option; the authority owns choices and tallies.
var game
var status: Label
var response: Label
var next_match: Label
var grid: GridContainer
var cards: Array=[]
var wall:=false
var refresh_left:=0.0
func setup(arena: Node) -> void:
	game=arena;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(20))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	status=label(column);status.add_theme_font_size_override("font_size",24)
	response=label(column)
	grid=GridContainer.new();grid.columns=3;grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);column.add_child(grid)
	for index in 9:
		var card:=Button.new();card.toggle_mode=true;card.custom_minimum_size=Vector2(0,132)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_child(card)
		var preview:=TextureRect.new();card.add_child(preview);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);preview.offset_left=4;preview.offset_top=4;preview.offset_right=-4;preview.offset_bottom=-4;preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var shade:=ColorRect.new();card.add_child(shade);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.offset_left=4;shade.offset_top=4;shade.offset_right=-4;shade.offset_bottom=-4;shade.color=Color(0.025,0.035,0.045,.48)
		var content:=VBoxContainer.new();card.add_child(content);content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=14;content.offset_right=-14;content.offset_top=10;content.offset_bottom=-10
		var title:=label(content);title.add_theme_font_size_override("font_size",20);title.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var details:=label(content);details.add_theme_font_size_override("font_size",16)
		var count:=label(content);count.add_theme_font_size_override("font_size",16)
		title.max_lines_visible=2;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		cards.append({"preview":preview,"shade":shade,"button":card,"content":content,"title":title,"details":details,"count":count})
		card.pressed.connect(func():game.lobby.select_option(index);refresh())
	next_match=label(column)
	if not wall:
		var back:=Button.new();back.text="CLOSE";back.custom_minimum_size.y=42;column.add_child(back)
		back.pressed.connect(func():game.menu_open=false;game.hud.show_menu(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if game.is_vr() else Input.MOUSE_MODE_CAPTURED)
	if not wall:hide()
	refresh()
func label(parent: Node) -> Label:
	var item:=Label.new();item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(item);return item
func open() -> void:
	preload("res://deathmatch/ui/choice.gd").close_all(get_tree())
	show();get_parent().move_child(self,-1);refresh()
func _process(delta: float) -> void:
	refresh_left-=delta
	if visible and refresh_left<=0:refresh();refresh_left=.1
func refresh() -> void:
	var data: Dictionary=game.lobby.snapshot() if game.multiplayer.is_server() and not game.demos.playing else game.lobby.view
	if data.is_empty():hide();return
	var options: Array=data.get("options",[])
	var counts: Array=data.get("counts",[])
	var mine: int=game.multiplayer.get_unique_id()
	var selected: int=data.get("selections",{}).get(mine,-1)
	var spectator: bool=game.local_state().get("spectator",true)
	var allowed: bool=data.get("enabled",false) and not spectator and not game.demos.playing
	status.text=("WAITING LOBBY" if data.get("stage","lobby" if game.lobby.active() else "intermission")=="lobby" else "ROUND OVER")+" · NEXT MATCH · %ds"%data.get("seconds",0)
	response.text="Select a match · You can change your vote · Most votes wins · Ties use grid order"
	if spectator:response.text="Spectators can view the ballot but cannot vote."
	elif not data.get("enabled",false):response.text="Player voting is disabled by the server."
	if game.demos.playing:response.text="RECORDED BALLOT" if data.has("id") else "RECORDED LOBBY · legacy voting options"
	for index in cards.size():
		var card: Dictionary=cards[index]
		var compact: bool=size.x<1000
		card.title.add_theme_font_size_override("font_size",16 if compact else 20)
		card.details.add_theme_font_size_override("font_size",14 if compact else 16)
		card.count.add_theme_font_size_override("font_size",14 if compact else 16)
		card.content.add_theme_constant_override("separation",2 if compact else 4)
		card.content.offset_top=8 if compact else 10;card.content.offset_bottom=-card.content.offset_top
		card.button.disabled=not allowed or index>=options.size()
		card.button.set_pressed_no_signal(index==selected)
		card.shade.color=Color(.08,.22,.28,.45) if index==selected else Color(.025,.035,.045,.48)
		if index>=options.size():
			card.preview.texture=null;card.title.text="—";card.details.text="No additional combination";card.count.text="";continue
		var option: Dictionary=options[index]
		card.preview.texture=game.map_previews.texture(option.map,option.get("sha256",""))
		card.title.text="%d  %s"%[index+1,option.get("title",option.map)]
		card.details.text="%s\n%s LOADOUT"%[game.match_mode.NAMES.get(option.mode,option.mode.to_upper()),str(option.get("rules","—")).to_upper()]
		var count: int=counts[index] if index<counts.size() else 0
		card.count.text=("YOUR VOTE · " if selected==index else "")+"%d %s"%[count,"VOTE" if count==1 else "VOTES"]
		card.button.tooltip_text=card.title.text+"\n"+card.details.text
	var chosen: Dictionary=data.get("next",{})
	var title: String=chosen.get("map","—")
	for option in options:
		if option.map==chosen.get("map",""):title=option.get("title",title);break
	next_match.text="LEADING: %s · %s · %s"%[title,str(chosen.get("mode","")).to_upper(),str(chosen.get("rules","")).to_upper()]
