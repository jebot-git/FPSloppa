extends Node
class PreviewService extends Node:
	var library
	var offered:=""
var picker
func _ready() -> void:
	get_tree().root.gui_embed_subwindows=false
	var library:=preload("res://deathmatch/avatars/library.gd").new();add_child(library)
	var service:=PreviewService.new();service.library=library;add_child(service)
	picker=preload("res://deathmatch/avatars/picker.gd").new();add_child(picker);picker.setup(service);picker.refresh();picker.popup_centered();picker.select_model(library.selected)
	var args:=OS.get_cmdline_user_args()
	if args.has("--fixture"):
		await picker.import_skin_package("res://test-results/ut99/SoldierSkinsDictator.utx")
		assert(picker.skin_model.value=="Soldier")
		assert(picker.skin_recognition.confidence=="likely")
		await RenderingServer.frame_post_draw
		picker.get_texture().get_image().save_png("res://test-results/ut99/utx-picker-options.png")
		picker.skin_model.choose("SGirl")
		assert(picker.skin_status.text.contains("Manual override: SGirl"))
		picker.skin_model.choose("Soldier");picker.skin_group.choose("dics");picker.skin_face.choose("dics4putin")
		await picker.finish_skin_import()
		await get_tree().create_timer(2).timeout
		await RenderingServer.frame_post_draw
		picker.get_texture().get_image().save_png("res://test-results/ut99/utx-picker-imported.png")
		print("UTX_PICKER_PREVIEW ",picker.current," ",library.entries[picker.current].title)
		if args.has("--capture"):get_tree().quit()
