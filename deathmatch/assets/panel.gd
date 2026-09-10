extends PanelContainer
const Paths=preload("res://deathmatch/assets/paths.gd")
var game
var notice: Label
var download: Button
var request: HTTPRequest
var busy:=false
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",18);add_child(column)
	var title:=Label.new();title.text="MAPS AND PLAYER MODELS";column.add_child(title)
	var paths:=Label.new();paths.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;paths.text="Drop BSP maps and VRM models into these folders, then rescan:\n\n"+Paths.folder("maps")+"\n"+Paths.folder("vrm");column.add_child(paths)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="Models must be at most 25 MB. Host maps download automatically when joining. Base files are separate from the game package.";column.add_child(notice)
	download=button(column,"DOWNLOAD BASE MAPS AND MODELS",install)
	button(column,"RESCAN FOLDERS",rescan)
	button(column,"BACK",func():if not busy:hide())
	request=HTTPRequest.new();request.use_threads=true;request.body_size_limit=150_000_000;add_child(request);request.request_completed.connect(completed)
func button(parent: Node,label: String,action: Callable) -> Button:
	var b:=Button.new();b.text=label;b.custom_minimum_size.y=52;b.pressed.connect(action);parent.add_child(b);return b
func open() -> void:
	get_parent().move_child(self,-1);show()
func manifest() -> Dictionary:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/assets/base_manifest.json"))
	return data if data is Dictionary else {}
func install() -> void:
	if busy or game.active:notice.text="Leave the match before installing or rescanning assets.";return
	var data:=manifest()
	if data.is_empty():notice.text="Base download is not configured. Copy maps/ and vrm/ from the release archive.";return
	request.download_file=Paths.root().path_join(".base-assets.download")
	busy=true;download.disabled=true;notice.text="Downloading base assets…"
	var error:=request.request(data.url)
	if error!=OK:finish("Download could not start: "+error_string(error))
func _process(_delta: float) -> void:
	if busy and request.get_http_client_status()!=HTTPClient.STATUS_DISCONNECTED:
		notice.text="Downloading base assets: %.1f MB"%(request.get_downloaded_bytes()/1000000.0)
func completed(result: int,code: int,_headers: PackedStringArray,_body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:finish("Download failed (%d / %d). Retry or copy the release asset folders."%[result,code]);return
	var data:=manifest();var archive:=request.download_file
	if FileAccess.get_sha256(archive)!=data.sha256:finish("Asset archive checksum mismatch.");return
	var zip:=ZIPReader.new()
	if zip.open(archive)!=OK:finish("Cannot open asset archive.");return
	for row in data.files:
		var dest:=Paths.root().path_join(row.path)
		# Preserve existing player/admin edits. Only install missing base files.
		if FileAccess.file_exists(dest):continue
		var bytes:=zip.read_file(row.path)
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
		if bytes.size()!=row.size or hash.finish().hex_encode()!=row.sha256:zip.close();finish("Invalid asset: "+row.path);return
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var file:=FileAccess.open(dest,FileAccess.WRITE)
		if not file:zip.close();finish("Cannot write to "+dest);return
		file.store_buffer(bytes);file.close();notice.text="Installed "+row.path
		await get_tree().process_frame
	zip.close();finish("Base assets installed.");rescan()
func finish(message: String) -> void:
	busy=false;download.disabled=false;notice.text=message
	if FileAccess.file_exists(request.download_file):DirAccess.remove_absolute(request.download_file)
func rescan() -> void:
	if busy or game.active:notice.text="Leave the match before rescanning assets.";return
	game.map_catalog=game.Maps.catalog();game.hud.map_choice.clear()
	for row in game.map_catalog:game.hud.map_choice.add_item(row.title)
	if not game.map_catalog.is_empty():game.selected_map=game.map_catalog[0].id
	game.avatars.library.reload()
	notice.text="Found %d maps and %d models."%[game.map_catalog.size(),game.avatars.library.entries.size()]
