extends SceneTree
const S=preload("res://deathmatch/launcher/update_store.gd")
class Probe extends "res://deathmatch/launcher/updater.gd":
	var result: Dictionary={}
	func prepared(value: Dictionary) -> void:
		result=value;phase="done";release_lock()
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var probe:=Probe.new();root.add_child(probe)
	probe.http.cancel_request();probe.phase="idle";probe.root="/tmp/fpsloppa-update-tests/http";probe.work=probe.root.path_join(".launcher-update")
	probe.installed=S.read(probe.root.path_join("INSTALL-MANIFEST.json"));probe.managed=true;probe.outdated=true
	probe.release=S.read(probe.root.path_join("release.json"));probe.release.url="http://127.0.0.1:18954/source.zip"
	probe.start();probe.cancel();assert(probe.phase=="idle" and not probe.owns_lock and probe.outdated)
	probe.start()
	for i in 600:
		if not probe.result.is_empty():break
		await create_timer(.05).timeout
	assert(not probe.result.is_empty() and not probe.result.has("error"),str(probe.result))
	assert(FileAccess.file_exists(probe.work.path_join("stage/FPSloppa.pck")))
	assert(not probe.owns_lock)
	probe.queue_free();await process_frame
	print("HTTP download, cancellation, SHA verification and staging passed");quit()
