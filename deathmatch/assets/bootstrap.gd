extends CanvasLayer
signal finished(result: String)
var xr_label: Label3D
func message(text: String) -> void:
	if xr_label:xr_label.text=text
	print("ASSET_BOOTSTRAP ",text)
func install() -> bool:
	# The full game rig is created after installation. Submit a minimal XR
	# viewport now so first-launch progress/errors are visible in the headset.
	var xr:=XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		var origin:=XROrigin3D.new();add_child(origin)
		var camera:=XRCamera3D.new();origin.add_child(camera);camera.make_current()
		xr_label=Label3D.new();xr_label.pixel_size=.001;xr_label.font_size=42
		xr_label.no_depth_test=true;xr_label.position=Vector3(0,-.05,-1.3);camera.add_child(xr_label)
		get_viewport().use_xr=true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	message("FPSLOPPA\nPreparing maps and models…")
	var background:=ColorRect.new();background.color=Color("11151b");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var column:=VBoxContainer.new();column.set_anchors_and_offsets_preset(Control.PRESET_CENTER);column.position=Vector2(-260,-60);column.size=Vector2(520,120);background.add_child(column)
	var label:=Label.new();label.text="FPSLOPPA · PREPARING MAPS AND MODELS\nInstalling included assets. No download required.";label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(label)
	var progress:=ProgressBar.new();progress.indeterminate=true;progress.custom_minimum_size.y=24;column.add_child(progress)
	var disk=preload("res://deathmatch/network/disk_worker.gd").new();add_child(disk)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/assets/base_manifest.json"))
	if not manifest is Dictionary:label.text="Invalid included asset manifest.";message(label.text);return false
	var accepted: bool=disk.submit(preload("res://deathmatch/assets/base_install.gd").install.bind(manifest,"res://deathmatch/assets/offline-base.zip",preload("res://deathmatch/assets/paths.gd").root()),func(result):finished.emit(result))
	if not accepted:label.text="Cannot start asset installation. Restart the application.";message(label.text);return false
	var result: String=await finished
	message(result)
	if result=="Base assets installed.":return true
	progress.hide();label.text=result+"\nFree some device storage and restart the application."
	return false
