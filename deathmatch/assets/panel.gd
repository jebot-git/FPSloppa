extends PanelContainer
const Paths=preload("res://deathmatch/assets/paths.gd")
const IO=preload("res://deathmatch/network/disk_worker.gd")
var disk=IO.new()
var game
var notice: Label
var download: Button
var busy:=false
func setup(arena: Node) -> void:
	add_child(disk)
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",18);add_child(column)
	var title:=Label.new();title.text="MAPS AND PLAYER MODELS";column.add_child(title)
	var paths:=Label.new();paths.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;paths.text="Drop BSP maps and VRM models into these folders, then rescan:\n\n"+Paths.folder("maps")+"\n"+Paths.folder("vrm");column.add_child(paths)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="Models must be at most 25 MB. Host maps download automatically when joining. Standalone APKs include the base files automatically.";column.add_child(notice)
	download=button(column,"REPAIR INCLUDED MAPS AND MODELS",install)
	download.visible=FileAccess.file_exists("res://deathmatch/assets/offline-base.zip")
	button(column,"RESCAN FOLDERS",rescan)
	button(column,"BACK",func():if not busy:hide())
func button(parent: Node,label: String,action: Callable) -> Button:
	var b:=Button.new();b.text=label;b.custom_minimum_size.y=52;b.pressed.connect(action);parent.add_child(b);return b
func open() -> void:
	get_parent().move_child(self,-1);show()
func manifest() -> Dictionary:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/assets/base_manifest.json"))
	return data if data is Dictionary else {}
func install() -> void:
	if busy or game.active:notice.text="Leave the match before installing or rescanning assets.";return
	var archive:="res://deathmatch/assets/offline-base.zip"
	if not FileAccess.file_exists(archive):notice.text="Restore maps/ and vrm/ from your FPSloppa release archive.";return
	busy=true;download.disabled=true;notice.text="Verifying and installing included assets…"
	if not disk.submit(install_archive.bind(manifest(),archive,Paths.root()),func(message):
		finish(message)
		if message=="Base assets installed.":rescan()):
		finish("Asset installation queue is full.")

static func install_archive(data: Dictionary,archive: String,directory: String) -> String:
	return preload("res://deathmatch/assets/base_install.gd").install(data,archive,directory)
func finish(message: String) -> void:
	busy=false;download.disabled=false;notice.text=message
func rescan() -> void:
	if busy or game.active:notice.text="Leave the match before rescanning assets.";return
	game.map_catalog=game.Maps.catalog();game.hud.refresh_maps()
	if not game.map_catalog.is_empty():game.selected_map=game.map_catalog[0].id
	game.avatars.library.reload()
	notice.text="Found %d maps and %d models."%[game.map_catalog.size(),game.avatars.library.entries.size()]
