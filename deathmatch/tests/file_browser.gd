extends SceneTree
const Browser=preload("res://deathmatch/ui/file_browser.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
 print("PASS " if value else "FAIL ",label)
 if not value:failures.append(label)
func run() -> void:
 var base:="/tmp/fpsloppa-browser-fixture"
 DirAccess.make_dir_recursive_absolute(base+"/nested/deeper")
 for name in ["MODEL.VRM","map.bsp","ignored.txt"]:FileAccess.open(base+"/"+name,FileAccess.WRITE).close()
 for i in 90:FileAccess.open(base+"/nested/model%03d.vrm"%i,FileAccess.WRITE).close()
 var b:=Browser.new();root.add_child(b);b.setup("vrm","IMPORT VRM");b.open();b.navigate(base)
 await process_frame;await process_frame
 check(b.rows.size()==2 and b.rows[0].folder and b.rows[1].title=="MODEL.VRM","Directories remain navigable with case-insensitive VRM filtering")
 b.entries.get_child(0).pressed.emit()
 check(b.current_dir==base+"/nested" and b.visible,"Single trigger click opens a folder and keeps browser open")
 check(b.rows.size()==91 and b.entries.get_child_count()==80,"Large folders paginate with bounded button count")
 b.next.pressed.emit();check(b.page==1 and b.entries.get_child_count()==11,"Next page exposes remaining files")
 b.up.pressed.emit();check(b.current_dir==base and b.page==0,"UP returns to parent folder and resets pagination")
 b.entries.get_child(1).pressed.emit();check(b.visible and not b.accept_button.disabled,"File click selects without dismissing browser")
 var selected: Array=[];b.file_selected.connect(func(path):selected.append(path));b.accept_button.pressed.emit()
 check(not b.visible and selected==[base+"/MODEL.VRM"],"Explicit import emits one full path")
 b.open();b.navigate(base+"/missing");check(b.current_dir==base and b.feedback.text.begins_with("Cannot open"),"Unreadable folder preserves navigable current location")
 b.show_locations();check(not b.rows.is_empty() and b.rows.any(func(row):return row.path=="/"),"Locations exposes filesystem root and accessible folders")
 check(Browser.parent_folder("C:/")=="C:/" and Browser.parent_folder("/")=="/" and Browser.parent_folder("C:/Users")=="C:/","Drive/root navigation cannot fall into an invalid parent")
 b.navigate(base+"/nested");await process_frame;await process_frame
 b.scroll.vr_mode_override=true
 var point: Vector2=b.scroll.get_global_rect().get_center()
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=point;b.scroll._input(press)
 var motion:=InputEventMouseMotion.new();motion.position=point-Vector2(0,100);b.scroll._input(motion)
 check(b.scroll.dragging and b.scroll.scroll_vertical>0,"VR trigger dragging scrolls the file list")
 var old: String=b.current_dir;b.entries.get_child(0).pressed.emit();check(b.current_dir==old,"Dragging cannot accidentally open a folder")
 b.free()
 var bsp:=Browser.new();root.add_child(bsp);bsp.setup("bsp","IMPORT BSP");bsp.open();bsp.navigate(base)
 check(bsp.rows.size()==2 and bsp.rows[1].title=="map.bsp","BSP browser shares directory navigation and correct filter")
 bsp.free();await process_frame;await process_frame
 print("FILE_BROWSER_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
