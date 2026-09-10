extends VBoxContainer
signal changed
const Choice=preload("res://deathmatch/ui/choice.gd")
var modes=Choice.new()
var maps=Choice.new()
var options: Array=[]
var names: Dictionary={}
func _init() -> void:
	add_theme_constant_override("separation",8)
	var a:=Label.new();a.text="1  GAME MODE";add_child(a);add_child(modes)
	var b:=Label.new();b.text="2  MAP";add_child(b);add_child(maps)
	modes.trigger.pressed.connect(func():maps.popup.hide())
	maps.trigger.pressed.connect(func():modes.popup.hide())
	modes.selected.connect(func(_value):maps.clear_selection();update_maps();changed.emit())
	maps.selected.connect(func(_value):changed.emit())
func configure(rows: Array,mode_names: Dictionary) -> void:
	if options==rows and names==mode_names:return
	options=rows;names=mode_names
	var modes_list: Array=[]
	for row in options:
		if not modes_list.any(func(item):return item.id==row.mode):modes_list.append({"id":row.mode,"title":row.get("mode_title",names.get(row.mode,row.mode.to_upper()))})
	modes.configure(modes_list,"SELECT MODE")
	update_maps()
func update_maps() -> void:
	var maps_list: Array=[]
	for row in options:
		if row.mode==modes.value:maps_list.append({"id":row.map,"title":row.get("title",row.map)})
	maps.configure(maps_list,"SELECT MAP" if not modes.value.is_empty() else "SELECT A MODE FIRST")
func ready_to_vote() -> bool:return not modes.value.is_empty() and not maps.value.is_empty()
