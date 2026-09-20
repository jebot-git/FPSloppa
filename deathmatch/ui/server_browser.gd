extends PanelContainer
## In-canvas controls are shared by desktop and the VR menu surface.
const Protocol=preload("res://deathmatch/server/discovery_protocol.gd")
var game
var interface
var directory
var master: LineEdit
var search: LineEdit
var compatible: CheckButton
var favorites_only: CheckButton
var mode
var sorting
var list: VBoxContainer
var details: Label
var message: Label
var join_button: Button
var spectate_button: Button
var favorite_button: Button
var selected:=""
var manual_address: LineEdit
var manual_game: SpinBox
var manual_query: SpinBox

func setup(arena: Node, hud: Node) -> void:
	game=arena;interface=hud;name="ServerBrowser"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(20))
	directory=preload("res://deathmatch/ui/server_directory.gd").new();add_child(directory)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	interface.text(column,"BROWSE SERVERS",30)
	var master_row:=HBoxContainer.new();column.add_child(master_row)
	interface.text(master_row,"MASTER",15)
	master=LineEdit.new();master.placeholder_text="https://your-master.example";master.text=directory.master_url;master.max_length=512;master.size_flags_horizontal=Control.SIZE_EXPAND_FILL;master_row.add_child(master)
	interface.button(master_row,"REFRESH",refresh).custom_minimum_size.y=44
	var filters:=HBoxContainer.new();column.add_child(filters)
	search=LineEdit.new();search.placeholder_text="Search name or map";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(search);search.text_changed.connect(func(_value):render())
	compatible=CheckButton.new();compatible.text="Compatible";compatible.button_pressed=true;filters.add_child(compatible);compatible.toggled.connect(func(_value):render())
	favorites_only=CheckButton.new();favorites_only.text="Favorites";filters.add_child(favorites_only);favorites_only.toggled.connect(func(_value):render())
	var choices:=HBoxContainer.new();column.add_child(choices)
	mode=preload("res://deathmatch/ui/choice.gd").new();choices.add_child(mode)
	var modes: Array=[{"id":"all","title":"All game modes"}]
	for key in game.match_mode.NAMES:modes.append({"id":key,"title":game.match_mode.NAMES[key]})
	mode.configure(modes,"GAME MODE");mode.choose("all");mode.selected.connect(func(_value):render())
	sorting=preload("res://deathmatch/ui/choice.gd").new();choices.add_child(sorting)
	sorting.configure([{"id":"ping","title":"Sort: ping"},{"id":"players","title":"Sort: humans"},{"id":"name","title":"Sort: name"}],"SORT SERVERS");sorting.choose("ping");sorting.selected.connect(func(_value):render())
	var scroll:=preload("res://deathmatch/ui/drag_scroll.gd").new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	details=interface.text(column,"Select a server to view details.",15);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size.y=64
	var actions:=HBoxContainer.new();column.add_child(actions)
	join_button=interface.button(actions,"JOIN",func():join_selected(false))
	spectate_button=interface.button(actions,"SPECTATE",func():join_selected(true))
	favorite_button=interface.button(actions,"FAVORITE",func():directory.toggle_favorite(selected))
	for button in [join_button,spectate_button,favorite_button]:button.custom_minimum_size.y=44
	var manual:=HBoxContainer.new();column.add_child(manual)
	manual_address=LineEdit.new();manual_address.placeholder_text="Favorite IPv4 / IPv6 address";manual_address.size_flags_horizontal=Control.SIZE_EXPAND_FILL;manual.add_child(manual_address)
	interface.text(manual,"GAME",14);manual_game=port_box(manual,7777)
	interface.text(manual,"QUERY",14);manual_query=port_box(manual,7779)
	interface.button(manual,"ADD",func():
		var key: String=directory.add_favorite(manual_address.text,int(manual_game.value),int(manual_query.value))
		if not key.is_empty():selected=key;directory.refresh();render()).custom_minimum_size.y=44
	message=interface.text(column,"",14);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=40
	interface.button(column,"BACK",close).custom_minimum_size.y=44
	directory.changed.connect(render);directory.notice.connect(func(value):message.text=value)
	hide();render()

func port_box(parent: Node, value: int) -> SpinBox:
	var field:=SpinBox.new();field.min_value=1024;field.max_value=65535;field.value=value;parent.add_child(field);return field

func open() -> void:
	if game.active or game.loading.blocking:return
	get_parent().move_child(self,-1);show();refresh()

func close() -> void:
	directory.cancel();preload("res://deathmatch/ui/choice.gd").close_all(get_tree());hide()

func refresh() -> void:
	if directory.set_master(master.text):directory.refresh()

func visible_rows() -> Array:
	var entries: Array=[]
	for key in directory.rows:
		var row: Dictionary=directory.rows[key]
		if favorites_only.button_pressed and not directory.favorites.has(key):continue
		if compatible.button_pressed and row.has("protocol") and row.protocol!=game.PROTOCOL:continue
		if mode.value!="all" and row.get("mode","")!=mode.value:continue
		var query:=search.text.strip_edges().to_lower()
		if not query.is_empty() and not (str(row.get("name",row.address))+" "+str(row.get("map_title",""))+" "+str(row.get("map",""))).to_lower().contains(query):continue
		entries.append({"key":key,"row":row})
	entries.sort_custom(func(a,b):
		if a.row.get("online",false)!=b.row.get("online",false):return a.row.get("online",false)
		if sorting.value=="ping" and a.row.get("ping_ms",99999)!=b.row.get("ping_ms",99999):return a.row.get("ping_ms",99999)<b.row.get("ping_ms",99999)
		if sorting.value=="players" and a.row.get("humans",0)!=b.row.get("humans",0):return a.row.get("humans",0)>b.row.get("humans",0)
		return str(a.row.get("name",a.row.address)).naturalnocasecmp_to(str(b.row.get("name",b.row.address)))<0)
	return entries

func render() -> void:
	if not list:return
	for child in list.get_children():list.remove_child(child);child.queue_free()
	var entries:=visible_rows()
	if not entries.any(func(entry):return entry.key==selected):selected=""
	if entries.is_empty():interface.text(list,"No matching servers. Add a favorite or refresh the directory.",17)
	for entry in entries:
		var row: Dictionary=entry.row
		var online: bool=row.get("online",false)
		var title: String=("★ " if directory.favorites.has(entry.key) else "")+str(row.get("name",row.address))
		var ping: String="%d ms"%int(row.ping_ms) if online else "No query reply"
		var summary: String="%s · %s · %s · %d humans + %d bots · %d open"%[row.get("map_title","Unknown map"),str(row.get("mode","?")).to_upper(),str(row.get("weapon_rules","?")).to_upper(),int(row.get("humans",0)),int(row.get("bots",0)),int(row.get("open_slots",0))] if row.has("protocol") else "Status unavailable · direct joining is available"
		var button: Button=interface.button(list,title+"   |   "+ping+"\n"+summary,func():selected=entry.key;render())
		button.custom_minimum_size.y=64;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.clip_text=true;button.toggle_mode=true;button.button_pressed=entry.key==selected
	update_details()

func update_details() -> void:
	var row: Dictionary=directory.rows.get(selected,{})
	var mismatch: bool=not row.is_empty() and row.has("protocol") and row.protocol!=game.PROTOCOL
	var full: bool=row.get("online",false) and int(row.get("open_slots",0))==0
	join_button.disabled=row.is_empty() or mismatch or full
	spectate_button.disabled=join_button.disabled
	favorite_button.disabled=row.is_empty()
	favorite_button.text="REMOVE FAVORITE" if directory.favorites.has(selected) else "FAVORITE"
	if row.is_empty():details.text="Select a server to view details.";return
	details.text="%s:%d · query %d · %s\n"%["["+row.address+"]" if ":" in row.address else row.address,int(row.game_port),int(row.query_port),"Version mismatch" if mismatch else "Full" if full else str(row.get("state","Status unknown"))]
	if row.has("protocol"):
		details.text+="Build %s · %s · %d spectators · %d reserved · %d total slots\n"%[row.version,row.protocol,int(row.spectators),int(row.reserved),int(row.capacity)]
	details.text+="Ping measures the query port. Joining confirms gameplay access."

func join_selected(spectator: bool) -> void:
	update_details()
	if join_button.disabled or game.active or game.loading.blocking:return
	var row: Dictionary=directory.rows[selected]
	interface.address_field.text=row.address;interface.port_field.value=int(row.game_port);interface.spectator_choice.button_pressed=spectator
	interface.save_preferences();close()
	game.start_join(interface.name_field.text,row.address,int(row.game_port),spectator)
