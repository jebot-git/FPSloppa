extends PanelContainer
## In-canvas file navigation: single-trigger folders, drag scrolling, explicit import.
signal file_selected(path: String)
var extension:=""
var current_dir:=""
var selected_path:=""
var entries: VBoxContainer
var scroll: ScrollContainer
var path_edit: LineEdit
var feedback: Label
var accept_button: Button
var up: Button
var page:=0
var rows: Array=[]
var previous: Button
var next: Button
var heading: String
const PAGE_SIZE=80
func setup(suffix: String,title: String) -> void:
 extension=suffix.to_lower();heading=title
 theme=preload("res://deathmatch/ui/iron_theme.gd").theme();z_index=100
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(20))
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
 var title_label:=Label.new();title_label.text=title;column.add_child(title_label)
 var toolbar:=HBoxContainer.new();column.add_child(toolbar)
 up=button(toolbar,"UP",func():navigate(parent_folder(current_dir)))
 button(toolbar,"LOCATIONS",show_locations)
 button(toolbar,"REFRESH",func():navigate(current_dir))
 button(toolbar,"CANCEL",hide)
 path_edit=LineEdit.new();path_edit.placeholder_text="Folder or file path";path_edit.custom_minimum_size.y=44;column.add_child(path_edit)
 path_edit.text_submitted.connect(func(path):
  if FileAccess.file_exists(path):select_file(path)
  else:navigate(path))
 scroll=preload("res://deathmatch/ui/drag_scroll.gd").new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
 entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(entries)
 var pages:=HBoxContainer.new();column.add_child(pages)
 previous=button(pages,"PREVIOUS PAGE",func():page-=1;show_page())
 next=button(pages,"NEXT PAGE",func():page+=1;show_page())
 feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.custom_minimum_size.y=42;column.add_child(feedback)
 accept_button=button(column,"SELECT A FILE",confirm)
 hide()
func button(parent: Node,title: String,action: Callable) -> Button:
 var b:=Button.new();b.text=title;b.custom_minimum_size.y=44;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 parent.add_child(b);b.pressed.connect(action);return b
func open() -> void:
 for selector in get_tree().get_nodes_in_group("arena_selectors"):selector.popup.hide()
 show();move_to_front()
 if current_dir.is_empty():show_locations()
 else:navigate(current_dir)
func clear_selection() -> void:
 selected_path="";accept_button.disabled=true;accept_button.text="SELECT A ."+extension.to_upper()+" FILE"
func show_locations() -> void:
 clear_selection();current_dir="";path_edit.text="";up.disabled=true;rows.clear();page=0
 var locations: Array=[{"label":"Home","path":OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")},{"label":"Downloads","path":OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)},{"label":"Game maps","path":preload("res://deathmatch/assets/paths.gd").folder("maps")},{"label":"Game models","path":preload("res://deathmatch/assets/paths.gd").folder("vrm")}]
 for i in DirAccess.get_drive_count():locations.append({"label":DirAccess.get_drive_name(i),"path":DirAccess.get_drive_name(i)})
 if not OS.has_feature("windows"):locations.append({"label":"Filesystem root","path":"/"})
 var seen: Dictionary={}
 for location in locations:
  var path: String=location.path
  if path.ends_with(":"):path+="/"
  if path.is_empty() or seen.has(path) or not DirAccess.dir_exists_absolute(path):continue
  rows.append({"title":location.label,"path":path,"folder":true});seen[path]=true
 show_page()
static func parent_folder(path: String) -> String:
 if path=="/" or path.length()<=3 and path.length()>=2 and path[1]==":":return path
 var parent:=path.get_base_dir()
 return parent+"/" if parent.ends_with(":") else parent
func navigate(path: String) -> void:
 path=path.strip_edges().replace("\\","/").simplify_path()
 if path.is_empty():show_locations();return
 var dir:=DirAccess.open(path)
 if not dir:feedback.text="Cannot open folder: "+error_string(DirAccess.get_open_error());return
 var error:=dir.list_dir_begin()
 if error!=OK:feedback.text="Cannot list folder: "+error_string(error);return
 current_dir=dir.get_current_dir();path_edit.text=current_dir;up.disabled=parent_folder(current_dir)==current_dir
 clear_selection();rows.clear();page=0
 var name:=dir.get_next()
 while not name.is_empty():
  if name not in [".",".."]:
   var folder:=dir.current_is_dir()
   if folder or name.get_extension().to_lower()==extension:rows.append({"title":name,"path":current_dir.path_join(name),"folder":folder})
  name=dir.get_next()
 dir.list_dir_end()
 rows.sort_custom(func(a,b):return a.folder if a.folder!=b.folder else a.title.naturalnocasecmp_to(b.title)<0)
 show_page()
func show_page() -> void:
 for child in entries.get_children():entries.remove_child(child);child.queue_free()
 page=clampi(page,0,maxi(0,(rows.size()-1)/PAGE_SIZE));scroll.scroll_vertical=0
 for index in range(page*PAGE_SIZE,mini(rows.size(),(page+1)*PAGE_SIZE)):
  var row: Dictionary=rows[index]
  var b:=button(entries,("[DIR] " if row.folder else "")+row.title,func():
   if scroll.dragging:return
   if row.folder:navigate(row.path)
   else:select_file(row.path))
  b.tooltip_text=row.path
 previous.disabled=page==0;next.disabled=(page+1)*PAGE_SIZE>=rows.size()
 feedback.text="Single click to open folders. Drag the list to scroll. %d entries · page %d/%d"%[rows.size(),page+1,maxi(1,ceili(float(rows.size())/PAGE_SIZE))] if not rows.is_empty() else "No matching files or folders here. Use UP or LOCATIONS."
func select_file(path: String) -> void:
 if path.get_extension().to_lower()!=extension or not FileAccess.file_exists(path):feedback.text="Select an existing ."+extension+" file.";return
 selected_path=path;feedback.text=path.get_file();accept_button.text="IMPORT "+path.get_file();accept_button.disabled=false
func confirm() -> void:
 if selected_path.is_empty() or not FileAccess.file_exists(selected_path):feedback.text="The selected file is no longer available.";return
 var path:=selected_path;hide();file_selected.emit(path)
