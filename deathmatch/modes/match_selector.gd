extends VBoxContainer
signal changed
const Choice=preload("res://deathmatch/ui/choice.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
var modes=Choice.new()
var maps=Choice.new()
var loadouts=Choice.new()
var preferred:="doom"
var loadout_label:Label
var options: Array=[]
var names: Dictionary={}
func _init() -> void:
	add_theme_constant_override("separation",8)
	var a:=Label.new();a.text="1  GAME MODE";add_child(a);add_child(modes)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);add_child(row)
	var map_column:=VBoxContainer.new();map_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_column.size_flags_stretch_ratio=1.5;row.add_child(map_column)
	var b:=Label.new();b.text="2  MAP";map_column.add_child(b);map_column.add_child(maps)
	var loadout_column:=VBoxContainer.new();loadout_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(loadout_column)
	loadout_label=Label.new();loadout_label.text="3  LOADOUT";loadout_column.add_child(loadout_label);loadout_column.add_child(loadouts)
	for choice in [modes,maps,loadouts]:choice.trigger.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	modes.trigger.pressed.connect(func():maps.popup.hide())
	maps.trigger.pressed.connect(func():modes.popup.hide())
	modes.selected.connect(func(_value):maps.clear_selection();update_maps();update_loadouts();changed.emit())
	maps.selected.connect(func(_value):changed.emit())
	loadouts.selected.connect(func(value):
		if Rules.selectable(modes.value):preferred=value
		changed.emit())
func configure(rows: Array,mode_names: Dictionary,initial_rules:String="") -> void:
	if options==rows and names==mode_names:return
	if options.is_empty() and initial_rules in Rules.IDS:preferred=initial_rules
	options=rows;names=mode_names
	var modes_list: Array=[]
	for row in options:
		if not modes_list.any(func(item):return item.id==row.mode):modes_list.append({"id":row.mode,"title":row.get("mode_title",names.get(row.mode,row.mode.to_upper()))})
	modes.configure(modes_list,"SELECT MODE")
	update_maps()
	update_loadouts()
func update_maps() -> void:
	var maps_list: Array=[]
	for row in options:
		if row.mode==modes.value:maps_list.append({"id":row.map,"title":row.get("title",row.map)})
	maps.configure(maps_list,"SELECT MAP" if not modes.value.is_empty() else "SELECT A MODE FIRST")
func update_loadouts() -> void:
	var rows:Array=[];var required:=Rules.required(modes.value)
	for rule in Rules.IDS:
		if Rules.selectable(modes.value) or rule==required:rows.append({"id":rule,"title":rule.to_upper()})
	loadouts.configure(rows,"SELECT MODE FIRST")
	loadouts.choose(preferred if required.is_empty() else required)
	loadouts.trigger.disabled=not Rules.selectable(modes.value)
	loadout_label.text="3  LOADOUT" if required.is_empty() else "3  FIXED LOADOUT"
func ready_to_vote() -> bool:return not modes.value.is_empty() and not maps.value.is_empty() and not loadouts.value.is_empty()
func value() -> String:return modes.value+"|"+maps.value+"|"+loadouts.value
