extends PanelContainer
const FONT=preload("res://deathmatch/ui/BebasNeue-Regular.ttf")
const RED=Color("ff9c88")
const BLUE=Color("91caff")
var title: Label
var summary: Label
var observers: Label
var footer: Label
var rows: Array=[]
var headers: Array=[]
func label(parent: Node,width: float,size: int) -> Label:
	var result:=Label.new();parent.add_child(result)
	result.custom_minimum_size=Vector2(width,24)
	result.add_theme_font_override("font",FONT);result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("e9dfca"))
	result.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	result.clip_text=true
	return result
func cells(parent: Node) -> Array:
	var box:=HBoxContainer.new();parent.add_child(box);box.add_theme_constant_override("separation",8)
	var result: Array=[]
	for width in [30,290,116,70,70,70]:result.append(label(box,width,22))
	result[1].size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for i in [0,3,4,5]:result[i].horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	return result
func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left=-420;offset_right=420;offset_top=-288;offset_bottom=288
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var panel:=preload("res://deathmatch/ui/iron_theme.gd").panel(14)
	panel.bg_color=Color("171b21");panel.border_color=Color("af8a50")
	add_theme_stylebox_override("panel",panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",3);add_child(column)
	title=label(column,0,30);summary=label(column,0,19)
	headers=cells(column)
	for i in range(6):headers[i].text=["#","PLAYER","CLASS","FRAGS","DEATHS","PING"][i]
	var roster:=VBoxContainer.new();roster.add_theme_constant_override("separation",0);column.add_child(roster)
	for i in range(16):
		var line:=PanelContainer.new();roster.add_child(line)
		var style:=StyleBoxFlat.new();style.bg_color=Color("202630") if i%2==0 else Color("181e27")
		line.add_theme_stylebox_override("panel",style)
		rows.append({"panel":line,"style":style,"cells":cells(line)})
	observers=label(column,0,17);footer=label(column,0,16)
	hide()
func refresh(game) -> void:
	var team_game: bool=game.match_mode.team_game()
	var tf: bool=game.match_mode.kind=="tf"
	title.text="ROUND COMPLETE · "+game.round_message if game.intermission>0 else "FPSLOPPA · "+game.match_mode.NAMES[game.match_mode.kind]
	summary.text="RED %d  /  BLUE %d   ·   %s"%[game.match_mode.scores[0],game.match_mode.scores[1],game.map_title] if team_game else game.map_title
	var ranked: Array=game.players.values().filter(func(p):return not p.spectator)
	ranked.sort_custom(func(a,b):
		if team_game and a.team!=b.team:return a.team<b.team
		if a.kills!=b.kills:return a.kills>b.kills
		if a.deaths!=b.deaths:return a.deaths<b.deaths
		return a.name.naturalnocasecmp_to(b.name)<0)
	headers[2].visible=tf
	for i in range(16):
		var row: Dictionary=rows[i];row.panel.visible=i<ranked.size()
		if i>=ranked.size():continue
		var player: Dictionary=ranked[i]
		var colour: Color=(RED if player.team==0 else BLUE if player.team==1 else Color("e9dfca")) if team_game else Color("e9dfca")
		row.style.bg_color=Color(colour.r*.12,colour.g*.12,colour.b*.12,.98) if team_game else Color("202630") if i%2==0 else Color("181e27")
		var role: String=player.get("tf_class","soldier")
		var values: Array=[str(i+1),player.name,game.match_mode.fortress.CLASSES.get(role,{}).get("name","UNKNOWN"),str(player.kills),str(player.deaths),str(player.ping)]
		for j in range(6):
			row.cells[j].text=values[j];row.cells[j].add_theme_color_override("font_color",colour)
		row.cells[2].visible=tf
	var spectators: Array=game.players.values().filter(func(p):return p.spectator)
	var names:=PackedStringArray()
	for player in spectators:names.append(player.name)
	observers.text="SPECTATORS (%d): "%spectators.size()+", ".join(names)
	observers.visible=not spectators.is_empty()
	footer.text="HOLD SCORES TO VIEW   ·   %d PLAYERS"%ranked.size()
	if ranked.size()>16:footer.text+="   ·   SHOWING FIRST 16 (HIGHER LIMITS UNSUPPORTED)"
