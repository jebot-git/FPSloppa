extends SceneTree
const Launcher=preload("res://deathmatch/launcher/launcher.gd")
const P=preload("res://deathmatch/launcher/update_policy.gd")
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:push_error(message);quit(1);assert(ok,message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var ui:=Launcher.new();root.add_child(ui);ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var updater: Node=ui.updater
	updater.http.cancel_request();updater.phase="checking"
	check(not updater.managed,"source checkout is not managed")
	updater.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"tag_name":"9.0v","draft":false,"prerelease":false,"assets":[]}).to_utf8_buffer())
	check(not updater.outdated,"source checkout not gated")
	updater.cache_path="/tmp/fpsloppa-update-tests/ui-cache.json"
	updater.managed=true;updater.installed={"version":"0.21v"};updater.phase="checking"
	updater.completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"tag_name":"0.22v","draft":false,"prerelease":false,"assets":[]}).to_utf8_buffer())
	check(updater.outdated,"newer release gates play even without downloadable asset")
	check(ui.update_button.visible,"update replaces play")
	if OS.get_cmdline_user_args().has("--visual"):
		updater.release.url="https://github.com/jebot-git/FPSloppa/releases/download/0.22v/FPSloppa-0.22v-Linux.zip";updater.message="Update available: 0.22v";ui.render_update()
		for i in 5:await process_frame
		root.get_texture().get_image().save_png("res://test-results/launcher-update/update-ui.png")
	for control in ui.play_controls:check(not control.visible,"every play/connect button hidden")
	ui.launch_connection("",7777,false,false);check(ui.notice.text.contains("Update the client"),"programmatic launch guarded")
	updater.phase="checking";updater.completed(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())
	check(updater.outdated,"failed recheck keeps known update requirement")
	updater.phase="downloading";updater.cancel();check(updater.outdated and updater.phase=="idle","cancel keeps update requirement")
	updater.managed=false;updater.outdated=false;updater.phase="checking"
	updater.completed(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())
	for control in ui.play_controls:check(control.visible,"offline without known update permits play")
	ui.queue_free();await process_frame
	print("Launcher update UI: ",checks," checks passed");quit()
