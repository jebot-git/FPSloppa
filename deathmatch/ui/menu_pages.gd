extends VBoxContainer
## A short category index with one scrollable page and a fixed navigation footer.
signal page_changed(id: String)
signal closed
var pages: Dictionary={}
var titles: Dictionary={}
var parents: Dictionary={}
var current:="home"
var heading: Label
var body: Control
var back_button: Button
func _init() -> void:
	size_flags_vertical=SIZE_EXPAND_FILL
	size_flags_horizontal=SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	heading=Label.new();heading.add_theme_font_size_override("font_size",28);add_child(heading)
	body=Control.new();body.size_flags_vertical=SIZE_EXPAND_FILL;add_child(body)
	back_button=Button.new();back_button.text="BACK";back_button.custom_minimum_size.y=52;add_child(back_button)
	back_button.pressed.connect(go_back)
func add_page(id: String,title: String,parent: String="home") -> VBoxContainer:
	var scroll=preload("res://deathmatch/ui/drag_scroll.gd").new();scroll.name=id.to_pascal_case()+"Scroll";body.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=VBoxContainer.new();column.size_flags_horizontal=SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",10);scroll.add_child(column)
	pages[id]=column;titles[id]=title;parents[id]=parent;scroll.visible=id==current
	if id==current:heading.text=title
	return column
func link(parent: String,id: String,label: String) -> Button:
	var button:=Button.new();button.text=label+"  ›";button.custom_minimum_size.y=52;button.add_theme_font_size_override("font_size",18);pages[parent].add_child(button)
	button.pressed.connect(navigate.bind(id));return button
func navigate(id: String) -> void:
	if not pages.has(id):return
	preload("res://deathmatch/ui/choice.gd").close_all(get_tree())
	current=id
	for key in pages:
		var scroll=pages[key].get_parent();scroll.cancel_drag();scroll.visible=key==id
		if key==id:scroll.scroll_vertical=0
	heading.text=titles[id] if id=="home" else titles["home"]+" / "+titles[id]
	page_changed.emit(id)
func go_back() -> void:
	if current=="home":closed.emit()
	else:navigate(parents[current])
