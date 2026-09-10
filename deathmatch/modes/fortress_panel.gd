extends PanelContainer
var game
var choice: OptionButton
var tool: OptionButton
var details: Label
var notice: Label
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);add_child(column)
	var title:=Label.new();title.text="TF · CHOOSE YOUR CLASS";column.add_child(title)
	choice=OptionButton.new();choice.custom_minimum_size.y=52;column.add_child(choice)
	for key in game.match_mode.fortress.CLASSES:
		choice.add_item(game.match_mode.fortress.CLASSES[key].name);choice.set_item_metadata(choice.item_count-1,key)
	choice.item_selected.connect(func(_index):refresh())
	details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(details)
	tool=OptionButton.new();tool.custom_minimum_size.y=52;tool.add_item("ENGINEER: SENTRY");tool.add_item("ENGINEER: DISPENSER");column.add_child(tool)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="Changes apply at your next respawn. Use E on desktop or the movement-hand A/X button in VR for your class action. Class badges identify players regardless of avatar.";column.add_child(notice)
	button(column,"QUEUE CLASS FOR NEXT RESPAWN",func():game.match_mode.fortress.choose(str(choice.get_selected_metadata()),"sentry" if tool.selected==0 else "dispenser");notice.text="Class selection sent. The HUD shows the server-confirmed next class.")
	button(column,"BACK",hide)
func button(parent: Node,text: String,action: Callable) -> void:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=52;b.pressed.connect(action);parent.add_child(b)
func open() -> void:
	var state: Dictionary=game.local_state()
	for index in choice.item_count:
		if choice.get_item_metadata(index)==state.get("tf_next","soldier"):choice.select(index)
	tool.select(0 if state.get("tf_tool","sentry")=="sentry" else 1)
	get_parent().move_child(self,-1);refresh();show()
func refresh() -> void:
	var key: String=choice.get_selected_metadata();var data: Dictionary=game.match_mode.fortress.CLASSES[key]
	details.text="%d HEALTH · %d ARMOR · %.0f%% SPEED\n\n%s"%[data.hp,data.armor,data.speed*100,data.action]
	tool.visible=key=="engineer"
