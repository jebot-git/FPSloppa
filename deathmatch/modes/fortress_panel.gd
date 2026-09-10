extends PanelContainer
var game
var choice=preload("res://deathmatch/ui/choice.gd").new()
var tool=preload("res://deathmatch/ui/choice.gd").new()
var details: Label
var notice: Label
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);add_child(column)
	var title:=Label.new();title.text="TF · CHOOSE YOUR CLASS";column.add_child(title)
	column.add_child(choice)
	var classes: Array=[]
	for key in game.match_mode.fortress.CLASSES:classes.append({"id":key,"title":game.match_mode.fortress.CLASSES[key].name})
	choice.configure(classes,"SELECT CLASS");choice.choose("soldier")
	choice.selected.connect(func(_value):refresh())
	details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(details)
	column.add_child(tool);tool.configure([{"id":"sentry","title":"ENGINEER: SENTRY"},{"id":"dispenser","title":"ENGINEER: DISPENSER"}],"SELECT BUILD TOOL");tool.choose("sentry")
	choice.trigger.pressed.connect(func():tool.popup.hide());tool.trigger.pressed.connect(func():choice.popup.hide())
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="Changes apply at your next respawn. Use E on desktop or the movement-hand A/X button in VR for your class action. Class badges identify players regardless of avatar.";column.add_child(notice)
	button(column,"QUEUE CLASS FOR NEXT RESPAWN",func():game.match_mode.fortress.choose(choice.value,tool.value);notice.text="Class selection sent. The HUD shows the server-confirmed next class.")
	button(column,"BACK",hide)
func button(parent: Node,text: String,action: Callable) -> void:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=52;b.pressed.connect(action);parent.add_child(b)
func open() -> void:
	var state: Dictionary=game.local_state()
	choice.choose(state.get("tf_next","soldier"));tool.choose(state.get("tf_tool","sentry"))
	get_parent().move_child(self,-1);refresh();show()
func refresh() -> void:
	var key: String=choice.value;var data: Dictionary=game.match_mode.fortress.CLASSES[key]
	details.text="%d HEALTH · %d ARMOR · %.0f%% SPEED\n\n%s"%[data.hp,data.armor,data.speed*100,data.action]
	tool.visible=key=="engineer"
