extends Control
## Desktop shell for the existing browser, asset services, and local music catalog.
const Directory=preload("res://deathmatch/ui/server_directory.gd")
const Paths=preload("res://deathmatch/assets/paths.gd")
const Profile=preload("res://deathmatch/profile.gd")
const Processes=preload("res://deathmatch/launcher/process.gd")
const Lists=preload("res://deathmatch/launcher/playlists.gd")
const Names=preload("res://deathmatch/ui/name_style.gd")
const Avatars=preload("res://deathmatch/launcher/avatar_catalog.gd")
const GOLD=Color("dfb46d")
var updater: Node
var play_controls: Array[Button]=[]
var update_button: Button
var update_notice: Label
var update_progress: ProgressBar
var update_cancel: Button
var update_check: Button
var release_notes: Button
var directory: Node
var servers: Tree
var selected:=""
var search: LineEdit
var only_favorites: CheckBox
var master: LineEdit
var player_name: LineEdit
var clan_tag: LineEdit
var identity_preview: RichTextLabel
var color_target: LineEdit
var avatar_choice: OptionButton
var avatar_status: Label
var avatar_disk: Node
var scanning_avatars:=false
var vr_join_button: Button
var direct_address: LineEdit
var direct_port: SpinBox
var details: Label
var notice: Label
var progress: ProgressBar
var query_progress: ProgressBar
var cancel_button: Button
var join_button: Button
var spectate_button: Button
var preload_button: Button
var favorite_button: Button
var submit_button: Button
var asset_target: Label
var file_list: ItemList
var files: Array[String]=[]
var playlist_list: ItemList
var tracks: Array[String]=[]
var track_titles: Array[String]=[]
var scope: OptionButton
var target: OptionButton
var climax: CheckBox
var saved_lists: OptionButton
var playlist_path: Label
var tabs: TabContainer
var dialog: FileDialog
var dialog_kind:=""
var job_path:=""
var job_pid:=-1
var job_started:=0
var refresh_elapsed:=0.0
var poll_elapsed:=0.0
var protocol:=""
var map_ids: Array[String]=[]
var busy_buttons: Array[Button]=[]

func _ready() -> void:
	get_window().title="FPSloppa · Desktop launcher"
	get_window().min_size=Vector2i(960,760)
	get_window().size=Vector2i(1180,880)
	get_tree().auto_accept_quit=false
	protocol=load("res://deathmatch/arena.gd").PROTOCOL
	theme=make_theme()
	var background:=TextureRect.new();background.texture=load("res://deathmatch/launcher/title.png")
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade:=ColorRect.new();shade.color=Color(0.035,0.045,0.06,.80);add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var margin:=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,26)
	var column:=VBoxContainer.new();margin.add_child(column);column.add_theme_constant_override("separation",14)
	var header:=HBoxContainer.new();column.add_child(header)
	var brand:=VBoxContainer.new();header.add_child(brand);brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(brand,"SLOP / LAUNCH CONTROL",38,GOLD)
	label(brand,"YOUR SERVERS. YOUR MAPS. YOUR SOUNDTRACK.",13,Color("bbc1c7"))
	var play:=VBoxContainer.new();header.add_child(play)
	var vr_play:=button(play,"PLAY IN VR",func():launch_game(false,false,true));primary(vr_play);play_controls.append(vr_play)
	var desktop_play:=button(play,"Play on desktop",func():launch_game(false,false,false));play_controls.append(desktop_play);desktop_play.flat=true;desktop_play.custom_minimum_size.y=26
	update_button=button(play,"UPDATE",start_update);primary(update_button);update_button.visible=false
	var updates:=HBoxContainer.new();column.add_child(updates)
	update_notice=label(updates,"Checking for updates…",13);update_notice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;update_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	release_notes=button(updates,"RELEASE NOTES",func():OS.shell_open(str(updater.release.get("notes","https://github.com/jebot-git/FPSloppa/releases"))))
	update_check=button(updates,"CHECK UPDATES",func():updater.check())
	update_cancel=button(updates,"CANCEL DOWNLOAD",func():updater.cancel());update_cancel.visible=false
	update_progress=ProgressBar.new();update_progress.custom_minimum_size.y=7;update_progress.show_percentage=false;column.add_child(update_progress);update_progress.visible=false
	var identity:=HBoxContainer.new();column.add_child(identity);label(identity,"NAME",13,GOLD)
	player_name=LineEdit.new();player_name.text=Profile.load_name();player_name.max_length=Names.INPUT_LIMIT;player_name.custom_minimum_size.x=210;identity.add_child(player_name)
	player_name.tooltip_text="18 visible characters; ^0–^7 change colour. ^^ displays a caret."
	label(identity,"CLAN",13,GOLD);clan_tag=LineEdit.new();clan_tag.text=Profile.load_clan();clan_tag.max_length=Names.INPUT_LIMIT;clan_tag.custom_minimum_size.x=125;identity.add_child(clan_tag)
	clan_tag.tooltip_text="Optional clan tag: 8 visible characters. Colours are supported."
	color_target=player_name
	for edit in [player_name,clan_tag]:
		edit.focus_entered.connect(func():color_target=edit)
		edit.text_changed.connect(func(_value):preview_identity())
	var colours:=MenuButton.new();colours.text="COLOURS";identity.add_child(colours)
	for i in 8:colours.get_popup().add_item("^%d  %s"%[i,Names.TITLES[i]],i)
	colours.get_popup().id_pressed.connect(func(i):color_target.insert_text_at_caret("^"+str(i));preview_identity())
	identity_preview=Names.rich_label(100,32,18);identity_preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;identity.add_child(identity_preview);preview_identity()
	var models:=HBoxContainer.new();column.add_child(models);label(models,"AVATAR",13,GOLD)
	avatar_choice=OptionButton.new();avatar_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;models.add_child(avatar_choice)
	avatar_choice.add_item("Scanning installed VRMs…");avatar_choice.disabled=true
	avatar_status=label(models,"",12);button(models,"IMPORT VRM…",func():pick_files("avatar",PackedStringArray(["*.vrm ; VRM avatars"])))
	button(models,"RESCAN",scan_avatars);button(models,"SAVE PROFILE",save_identity)
	button(models,"OPEN ASSETS",func():OS.shell_open(Paths.root())).tooltip_text=Paths.root()
	avatar_disk=preload("res://deathmatch/network/disk_worker.gd").new();add_child(avatar_disk)

	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	build_servers(page("Servers"));build_assets(page("Maps & avatars"));build_music(page("Music playlists"))
	var footer:=PanelContainer.new();column.add_child(footer)
	var status_column:=VBoxContainer.new();footer.add_child(status_column)
	var status_row:=HBoxContainer.new();status_column.add_child(status_row)
	notice=label(status_row,"Ready. Add a favourite server or launch the game.",14);notice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cancel_button=button(status_row,"CANCEL",cancel_job);cancel_button.disabled=true
	progress=ProgressBar.new();progress.custom_minimum_size.y=10;progress.show_percentage=false;status_column.add_child(progress)
	dialog=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILES;dialog.use_native_dialog=true;add_child(dialog);dialog.files_selected.connect(files_chosen)
	directory=Directory.new();add_child(directory);master.text=directory.master_url
	directory.changed.connect(render_servers);directory.notice.connect(func(text):if job_pid<0:notice.text=text)
	updater=preload("res://deathmatch/launcher/updater.gd").new();updater.changed.connect(render_update);add_child(updater)
	load_maps();refresh_saved();directory.refresh();scan_avatars()

func make_theme() -> Theme:
	var result:=Theme.new();result.default_font_size=15
	for type in ["Label","Button","LineEdit","CheckBox","OptionButton","Tree","ItemList","TabContainer","PopupMenu","SpinBox"]:
		result.set_color("font_color",type,Color("ede8df"));result.set_color("font_hover_color",type,Color.WHITE);result.set_color("font_pressed_color",type,GOLD)
		result.set_color("font_disabled_color",type,Color("78818d"));result.set_color("font_selected_color",type,Color.WHITE)
	for type in ["Button","LineEdit","OptionButton"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style:=box(Color("293442") if state=="hover" else Color("151e29"),10)
			style.border_color=GOLD if state in ["focus","pressed"] else Color("44515f");style.set_border_width_all(1)
			if state=="focus":style.bg_color=Color.TRANSPARENT
			result.set_stylebox(state,type,style)
	for type in ["PanelContainer","TabContainer","Tree","ItemList","PopupMenu"]:result.set_stylebox("panel",type,box(Color(.045,.065,.085,.93),14))
	for type in ["Tree","ItemList"]:
		result.set_stylebox("selected",type,box(Color("3d4a56"),4));result.set_stylebox("selected_focus",type,box(Color("435362"),4))
	result.set_constant("v_separation","Tree",16);result.set_constant("v_separation","ItemList",12)
	result.set_stylebox("tab_selected","TabContainer",box(Color("384452"),12));result.set_stylebox("tab_unselected","TabContainer",box(Color("141b25"),12))
	result.set_color("font_selected_color","TabContainer",GOLD);result.set_color("font_unselected_color","TabContainer",Color("b6bec8"))
	result.set_stylebox("background","ProgressBar",box(Color("28313b"),0));result.set_stylebox("fill","ProgressBar",box(GOLD,0))
	return result
func primary(item: Button) -> void:
	item.custom_minimum_size=Vector2(230,60);item.add_theme_font_size_override("font_size",24)
	for state in ["normal","hover","pressed"]:item.add_theme_stylebox_override(state,box(GOLD.lightened(.15) if state=="hover" else GOLD.darkened(.15) if state=="pressed" else GOLD,12))
	for state in ["font_color","font_hover_color","font_pressed_color"]:item.add_theme_color_override(state,Color("151b23"))
func box(color: Color,padding: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(4)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_content_margin(side,padding)
	return style
func label(parent: Node,text: String,size: int=15,color: Color=Color("e7e9ec")) -> Label:
	var item:=Label.new();item.text=text;item.add_theme_font_size_override("font_size",size);item.add_theme_color_override("font_color",color);parent.add_child(item);return item
func button(parent: Node,text: String,action: Callable) -> Button:
	var item:=Button.new();item.text=text;item.custom_minimum_size.y=38;parent.add_child(item);item.pressed.connect(action);return item
func page(title: String) -> VBoxContainer:
	var item:=VBoxContainer.new();item.name=title;item.add_theme_constant_override("separation",12);tabs.add_child(item);return item
func field(parent: Node,placeholder: String) -> LineEdit:
	var item:=LineEdit.new();item.placeholder_text=placeholder;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(item);return item
func build_servers(parent: Node) -> void:
	var toolbar:=HBoxContainer.new();parent.add_child(toolbar)
	search=field(toolbar,"Find a server or map…");search.text_changed.connect(func(_s):render_servers())
	only_favorites=CheckBox.new();only_favorites.text="Favourites only";toolbar.add_child(only_favorites);only_favorites.toggled.connect(func(_v):render_servers())
	button(toolbar,"REFRESH",func():directory.refresh())
	servers=Tree.new();servers.columns=6;servers.hide_root=true;servers.column_titles_visible=true;servers.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var titles:=["SERVER","PLAYERS / OPEN","CURRENT MAP","MODE","PING","STATUS"]
	for i in titles.size():servers.set_column_title(i,titles[i])
	servers.set_column_expand_ratio(0,3);servers.set_column_expand_ratio(2,3)
	servers.set_column_custom_minimum_width(1,165);servers.set_column_custom_minimum_width(3,65);servers.set_column_custom_minimum_width(4,65)
	parent.add_child(servers);servers.item_selected.connect(func():selected=str(servers.get_selected().get_metadata(0));update_selection());servers.item_activated.connect(func():launch_game(true,spectate_button.button_pressed,false))
	query_progress=ProgressBar.new();query_progress.custom_minimum_size.y=5;query_progress.show_percentage=false;parent.add_child(query_progress)
	details=label(parent,"Add a favourite by IPv4 or IPv6 address, or connect a master directory.",13,Color("b9c2cd"));details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size.y=42
	var actions:=HBoxContainer.new();parent.add_child(actions)
	join_button=button(actions,"JOIN DESKTOP",func():launch_game(true,spectate_button.button_pressed,false))
	vr_join_button=button(actions,"JOIN VR",func():launch_game(true,spectate_button.button_pressed,true))
	play_controls.append_array([join_button,vr_join_button])
	spectate_button=CheckBox.new();spectate_button.text="Spectate";actions.add_child(spectate_button)
	preload_button=button(actions,"PRELOAD ASSETS",func():server_job("preload"));favorite_button=button(actions,"FAVOURITE",func():directory.toggle_favorite(selected);render_servers())
	var direct:=HBoxContainer.new();parent.add_child(direct)
	direct_address=field(direct,"Direct join: hostname, IPv4 or IPv6")
	var config:=ConfigFile.new()
	if config.load(Profile.config_path())==OK:direct_address.text=str(config.get_value("network","address",""))
	direct_port=SpinBox.new();direct_port.min_value=1;direct_port.max_value=65535;direct_port.value=7777;direct.add_child(direct_port)
	play_controls.append(button(direct,"CONNECT DESKTOP",func():launch_direct(false)));play_controls.append(button(direct,"CONNECT VR",func():launch_direct(true)))
	direct_address.text_submitted.connect(func(_text):launch_direct(false))
	var manual:=HBoxContainer.new();parent.add_child(manual)
	var address:=field(manual,"Favourite IPv4 / IPv6 address")
	label(manual,"GAME",12);var game_port:=SpinBox.new();game_port.min_value=1024;game_port.max_value=65535;game_port.value=7777;manual.add_child(game_port)
	label(manual,"QUERY",12);var query_port:=SpinBox.new();query_port.min_value=1024;query_port.max_value=65535;query_port.value=7779;manual.add_child(query_port)
	button(manual,"ADD",func():
		var key: String=directory.add_favorite(address.text,int(game_port.value),int(query_port.value))
		if not key.is_empty():selected=key;directory.refresh())
	var discovery:=HBoxContainer.new();parent.add_child(discovery)
	master=field(discovery,"Optional HTTPS master directory URL")
	button(discovery,"CONNECT DIRECTORY",func():if directory.set_master(master.text):directory.refresh())
func build_assets(parent: Node) -> void:
	label(parent,"A little preparation. A faster join.",23,GOLD)
	var description:=label(parent,"Import BSP maps and VRM avatars into your local library, or submit them to the selected server.\nPreload fetches the server’s current map and announced avatars using a temporary spectator slot.",14);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	asset_target=label(parent,"Choose a server on the Servers tab.",14,GOLD)
	asset_target.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	file_list=ItemList.new();file_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(file_list)
	var row:=HBoxContainer.new();parent.add_child(row)
	button(row,"ADD BSP / VRM…",func():pick_files("assets",PackedStringArray(["*.bsp ; Quake BSP maps","*.vrm ; VRM avatars"])))
	button(row,"REMOVE",func():
		if not file_list.get_selected_items().is_empty():files.remove_at(file_list.get_selected_items()[0]);render_files())
	var local:=button(row,"IMPORT LOCALLY",func():if not files.is_empty():start_job({"action":"import","files":files.duplicate()}));busy_buttons.append(local)
	submit_button=button(row,"SUBMIT TO SERVER",func():server_job("submit"))
	var hint:=label(parent,"25 MB per file • BSP and self-contained humanoid VRM validation matches the game.\nSubmissions use the normal server connection and its upload policy. VRMs are offered in turn as your temporary avatar.\nChoose your imported avatar from MODEL in the game. Server map submissions can be selected by voting.",13,Color("aeb9c7"));hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func build_music(parent: Node) -> void:
	var row:=HBoxContainer.new();parent.add_child(row)
	saved_lists=OptionButton.new();saved_lists.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(saved_lists)
	button(row,"LOAD",load_playlist)
	button(row,"NEW",func():tracks.clear();track_titles.clear();render_tracks())
	var settings:=HBoxContainer.new();parent.add_child(settings)
	label(settings,"PLAY DURING",12,GOLD);scope=OptionButton.new()
	for name in ["All gameplay","One mode","One map"]:scope.add_item(name)
	settings.add_child(scope);scope.item_selected.connect(func(_i):fill_targets())
	target=OptionButton.new();target.size_flags_horizontal=Control.SIZE_EXPAND_FILL;settings.add_child(target);target.item_selected.connect(func(_i):update_playlist_path())
	climax=CheckBox.new();climax.text="Climax / win_";settings.add_child(climax);climax.toggled.connect(func(_v):update_playlist_path())
	playlist_list=ItemList.new();playlist_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(playlist_list)
	var actions:=HBoxContainer.new();parent.add_child(actions)
	button(actions,"ADD OGG TRACKS…",func():pick_files("music",PackedStringArray(["*.ogg ; Ogg Vorbis audio"])))
	button(actions,"MOVE UP",func():move_track(-1));button(actions,"MOVE DOWN",func():move_track(1))
	button(actions,"REMOVE",func():
		if not playlist_list.get_selected_items().is_empty():
			var i:=playlist_list.get_selected_items()[0];tracks.remove_at(i);track_titles.remove_at(i);render_tracks())
	var save:=button(actions,"SAVE PLAYLIST",save_playlist);busy_buttons.append(save)
	playlist_path=label(parent,"",13,GOLD)
	var hint:=label(parent,"Map playlists override mode playlists, then global music. Climax tracks use the win_ prefix.\nTracks loop in the order above; the launcher writes a local M3U8 and numbered audio copies.\nOther music in the same scope remains part of the game’s playlist. Title and lobby music stay built in.",13,Color("aeb9c7"));hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func load_maps() -> void:
	for name in DirAccess.get_files_at(Paths.folder("maps")):
		if name.get_extension().to_lower()=="bsp":map_ids.append(name.get_basename().to_lower())
	map_ids.sort();fill_targets()
func fill_targets() -> void:
	target.clear();target.disabled=scope.selected==0
	var choices: Array=[]
	if scope.selected==0:choices=["All maps and modes"]
	elif scope.selected==1:choices=Lists.Catalog.MODES.keys()
	else:choices=map_ids
	for id in choices:target.add_item(id)
	update_playlist_path()
func scope_name() -> String:return ["global","mode","map"][scope.selected]
func target_name() -> String:return target.get_item_text(target.selected) if target.selected>=0 and scope.selected!=0 else ""
func update_playlist_path() -> void:
	if playlist_path:playlist_path.text="Saves to bgm/"+Lists.stem(scope_name(),target_name(),climax.button_pressed)+".m3u8"
func pick_files(kind: String,filters: PackedStringArray) -> void:
	dialog_kind=kind;dialog.filters=filters;dialog.popup_centered_ratio(.75)
func files_chosen(paths: PackedStringArray) -> void:
	if dialog_kind=="avatar":
		start_job({"action":"import","files":Array(paths)});return
	for path in paths:
		if dialog_kind=="assets":
			if path not in files:files.append(path)
		elif tracks.size()<256:tracks.append(path);track_titles.append(path.get_file())
	render_files();render_tracks()
func render_files() -> void:
	file_list.clear()
	for path in files:
		var file:=FileAccess.open(path,FileAccess.READ)
		file_list.add_item("%s   /   %.2f MB   /   %s"%[path.get_extension().to_upper(),file.get_length()/1000000.0 if file else 0.0,path.get_file()]);file_list.set_item_tooltip(file_list.item_count-1,path)
	update_selection()
func render_tracks() -> void:
	playlist_list.clear()
	for i in tracks.size():playlist_list.add_item("%02d    %s"%[i+1,track_titles[i]]);playlist_list.set_item_tooltip(i,tracks[i])
func move_track(direction: int) -> void:
	if playlist_list.get_selected_items().is_empty():return
	var from:=playlist_list.get_selected_items()[0];var to:=from+direction
	if to<0 or to>=tracks.size():return
	var path:=tracks[from];var title:=track_titles[from];tracks.remove_at(from);track_titles.remove_at(from);tracks.insert(to,path);track_titles.insert(to,title);render_tracks();playlist_list.select(to)
func refresh_saved() -> void:
	saved_lists.clear();saved_lists.add_item("Saved launcher playlists…")
	for key in Lists.read_index(Paths.root().path_join("bgm")):saved_lists.add_item(key)
func load_playlist() -> void:
	var records:=Lists.read_index(Paths.root().path_join("bgm"));var key:=saved_lists.get_item_text(saved_lists.selected)
	if not records.has(key):return
	var record: Dictionary=records[key];scope.select(["global","mode","map"].find(record.scope));fill_targets()
	for i in target.item_count:
		if target.get_item_text(i)==record.target:target.select(i)
	climax.button_pressed=record.climax;tracks.clear();track_titles.clear()
	for row in record.tracks:tracks.append(row.path);track_titles.append(row.title)
	render_tracks();update_playlist_path()
func save_playlist() -> void:
	if tracks.is_empty():notice.text="Add some Ogg Vorbis tracks first.";return
	start_job({"action":"playlist","scope":scope_name(),"target":target_name(),"climax":climax.button_pressed,"tracks":tracks.duplicate(),"titles":track_titles.duplicate()})
func render_servers() -> void:
	if not directory:return
	servers.clear();var root:=servers.create_item();var entries: Array=directory.rows.keys()
	entries.sort_custom(func(a,b):
		if directory.favorites.has(a)!=directory.favorites.has(b):return directory.favorites.has(a)
		return str(directory.rows[a].get("name",a)).naturalnocasecmp_to(str(directory.rows[b].get("name",b)))<0)
	for key in entries:
		var row: Dictionary=directory.rows[key]
		if only_favorites.button_pressed and not directory.favorites.has(key):continue
		if not search.text.is_empty() and not (str(row.get("name",row.address))+str(row.get("map_title",""))+str(row.get("map",""))).to_lower().contains(search.text.to_lower()):continue
		var item:=servers.create_item(root);item.set_metadata(0,key)
		item.set_text(0,("★  " if directory.favorites.has(key) else "")+str(row.get("name",row.address)))
		var online: bool=row.get("online",false)
		item.set_text(1,"%d + %d bots / %d open"%[int(row.humans),int(row.bots),int(row.open_slots)] if online else "—")
		item.set_text(2,str(row.get("map_title",row.get("map","Unknown"))) if online else "Awaiting query reply")
		item.set_text(3,str(row.get("mode","—")).to_upper() if online else "—")
		item.set_text(4,"%d ms"%int(row.ping_ms) if online else "—")
		item.set_text(5,"Mismatch" if row.has("protocol") and row.protocol!=protocol else ("Full" if int(row.get("open_slots",0))==0 else "Online") if online else "No reply")
		for i in 6:item.set_tooltip_text(i,str(row.address)+":"+str(row.game_port)+" · humans + bots / open human seats")
		if key==selected:item.select(0)
	update_selection()
func update_selection() -> void:
	if updater and update_button:update_button.disabled=updater.phase!="idle" or not updater.release.has("url") or job_pid>0
	if not directory:return
	var row: Dictionary=directory.rows.get(selected,{})
	asset_target.text="Choose a server on the Servers tab." if row.is_empty() else "Submission target: %s · %s:%d"%[str(row.get("name",row.address)),str(row.address),int(row.game_port)]
	var blocked: bool=row.is_empty() or (row.has("protocol") and row.protocol!=protocol) or (row.get("online",false) and int(row.get("open_slots",0))==0)
	join_button.disabled=blocked or update_required();vr_join_button.disabled=blocked or update_required();preload_button.disabled=blocked or job_pid>0
	submit_button.disabled=blocked or files.is_empty() or job_pid>0
	favorite_button.disabled=row.is_empty();favorite_button.text="REMOVE FAVOURITE" if directory.favorites.has(selected) else "FAVOURITE"
	if row.is_empty():details.text="Select a server. Favourites are shared with the in-game browser.";return
	details.text="%s:%d · query %d · %s"%[str(row.address),int(row.game_port),int(row.query_port),str(row.get("state","Status unavailable · direct joining is available"))]
	if row.get("online",false):details.text+="\n%d humans · %d bots · %d spectators · %d reserved · %d capacity · %s / %s"%[int(row.humans),int(row.bots),int(row.spectators),int(row.reserved),int(row.capacity),str(row.weapon_rules).to_upper(),str(row.version)]
func preview_identity() -> void:
	if identity_preview:Names.paint(identity_preview,Names.display(player_name.text,clan_tag.text))
func avatar_hash() -> String:
	if avatar_choice.selected<0 or avatar_choice.get_item_metadata(avatar_choice.selected)==null:return ""
	return str(avatar_choice.get_item_metadata(avatar_choice.selected))
func scan_avatars() -> void:
	if scanning_avatars:return
	scanning_avatars=true;avatar_status.text="Scanning…"
	var previous:=avatar_hash() if avatar_choice.item_count>0 and avatar_choice.get_item_metadata(0)!=null else Avatars.selected()
	avatar_disk.submit(Avatars.scan.bind(Paths.folder("vrm")),func(rows):
		scanning_avatars=false;avatar_choice.clear();avatar_choice.add_item("Use game default / saved avatar");avatar_choice.set_item_metadata(0,"")
		for row in rows:
			avatar_choice.add_item(str(row.title)+" · "+str(row.author));avatar_choice.set_item_metadata(avatar_choice.item_count-1,row.hash)
			if row.hash==previous:avatar_choice.select(avatar_choice.item_count-1)
		avatar_choice.disabled=false;avatar_status.text="%d models"%rows.size())
func save_identity() -> bool:
	player_name.text=Profile.clean(player_name.text,Profile.system_name());clan_tag.text=Names.clean(clan_tag.text,Names.CLAN_LIMIT,"");preview_identity()
	var error:=Profile.save_identity(player_name.text,clan_tag.text,direct_address.text)
	if error==OK:error=Avatars.choose(avatar_hash())
	if error!=OK:notice.text="Could not save player profile: "+error_string(error);return false
	notice.text="Name, clan tag and avatar saved.";return true
func game_arguments(address: String="",port: int=7777,spectator: bool=false) -> PackedStringArray:
	var args:=PackedStringArray(["--name",Profile.clean(player_name.text),"--clan",Names.clean(clan_tag.text,Names.CLAN_LIMIT,"")])
	var hash:=avatar_hash()
	if not hash.is_empty():args.append_array(["--avatar",hash])
	if not address.is_empty():
		args.append_array(["--connect",address,"--port",str(port)])
		if spectator:args.append("--spectate")
	return args
func launch_game(join: bool,spectator: bool,use_vr: bool=false) -> void:
	var address:="";var port:=7777
	if join:
		update_selection()
		if join_button.disabled:return
		var row: Dictionary=directory.rows[selected];address=row.address;port=int(row.game_port)
	launch_connection(address,port,spectator,use_vr)
func launch_direct(use_vr: bool) -> void:
	var endpoint:=Processes.endpoint(direct_address.text,int(direct_port.value))
	if endpoint.has("error"):notice.text=endpoint.error;return
	# Honour a known incompatibility/full status even when typed directly.
	for row in directory.rows.values():
		if row.address==endpoint.address and int(row.game_port)==int(endpoint.port):
			if row.has("protocol") and row.protocol!=protocol:notice.text="This server requires a different game protocol.";return
			if row.get("online",false) and int(row.get("open_slots",0))==0:notice.text="This server is full.";return
	launch_connection(endpoint.address,endpoint.port,spectate_button.button_pressed,use_vr)
func launch_connection(address: String,port: int,spectator: bool,use_vr: bool) -> void:
	if update_required():notice.text="Update the client before playing.";return
	if not address.is_empty():direct_address.text=address
	if not save_identity():return
	var pid:=Processes.launch("res://deathmatch/arena.tscn",game_arguments(address,port,spectator),false,use_vr)
	notice.text=("VR" if use_vr else "Desktop")+" game launched"+(" · connecting to "+address if not address.is_empty() else ".") if pid>0 else "Could not start the game runtime."
func server_job(action: String) -> void:
	update_selection()
	if preload_button.disabled or (action=="submit" and submit_button.disabled):return
	var row: Dictionary=directory.rows[selected]
	start_job({"action":action,"address":row.address,"game_port":row.game_port,"files":files.duplicate() if action=="submit" else []})
func start_job(job: Dictionary) -> void:
	if updater and updater.phase in ["downloading","preparing","handoff"]:notice.text="Finish or cancel the client update first.";return
	if job_pid>0:return
	var folder:=ProjectSettings.globalize_path("user://launcher-jobs");DirAccess.make_dir_recursive_absolute(folder)
	job_path=folder.path_join("%d-%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]);job.heartbeat=true
	if Lists.write_text(job_path,JSON.stringify(job))!=OK:notice.text="Could not save the transfer job.";return
	Lists.write_text(job_path+".heartbeat","alive")
	job_pid=Processes.launch("res://deathmatch/launcher/worker.tscn",PackedStringArray(["--job",job_path]),true)
	if job_pid<=0:notice.text="Could not start the asset worker.";return
	job_started=Time.get_ticks_msec();cancel_button.disabled=false;progress.indeterminate=true;notice.text="Starting…"
	for item in busy_buttons:item.disabled=true
	update_selection()
func cancel_job() -> void:
	if job_pid>0:Lists.write_text(job_path+".cancel","cancel");notice.text="Cancelling…";cancel_button.disabled=true
func job_done(message: String,ok: bool) -> void:
	job_pid=-1;progress.indeterminate=false;progress.value=100 if ok else 0;notice.text=message;cancel_button.disabled=true
	for item in busy_buttons:item.disabled=false
	refresh_saved();map_ids.clear();load_maps();scan_avatars();update_selection()
func _process(delta: float) -> void:
	if not directory:return
	query_progress.indeterminate=directory.fetching or not directory.queue.is_empty() or not directory.probes.is_empty()
	query_progress.value=0 if query_progress.indeterminate else 100
	refresh_elapsed+=delta
	if refresh_elapsed>20:
		refresh_elapsed=0
		if not query_progress.indeterminate:directory.refresh()
	if job_pid<=0:return
	poll_elapsed+=delta
	if poll_elapsed<.2:return
	poll_elapsed=0
	Lists.write_text(job_path+".heartbeat","alive")
	if FileAccess.file_exists(job_path+".status"):
		var state=JSON.parse_string(FileAccess.get_file_as_string(job_path+".status"))
		if state is Dictionary:
			if state.get("state") in ["complete","error"]:job_done(state.message,state.state=="complete");return
			notice.text=str(state.get("message","Working…"));var total:=int(state.get("total",0));progress.indeterminate=total==0
			if total>0:progress.value=100.0*float(state.get("done",0))/total
	if not OS.is_process_running(job_pid):job_done("Asset worker stopped before completing. See the Godot log for details.",false)
	elif Time.get_ticks_msec()-job_started>900000:OS.kill(job_pid);job_done("Operation timed out after 15 minutes.",false)
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		cancel_job();get_tree().quit()

func update_required() -> bool:return updater!=null and updater.outdated
func render_update() -> void:
	for item in play_controls:item.visible=not update_required()
	update_button.visible=update_required();update_button.text="UPDATE TO "+str(updater.release.get("version",""))
	update_button.disabled=updater.phase!="idle" or not updater.release.has("url") or job_pid>0
	update_notice.text=updater.message;update_progress.visible=updater.phase in ["downloading","preparing","handoff"]
	update_progress.indeterminate=updater.phase=="preparing" and updater.fraction<=0
	update_progress.value=updater.fraction*100;update_cancel.visible=updater.phase=="downloading";update_check.disabled=updater.phase!="idle"
	update_selection()
func start_update() -> void:
	if job_pid>0:notice.text="Wait for the asset task to finish before updating.";return
	updater.start()
