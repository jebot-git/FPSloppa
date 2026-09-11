extends SceneTree
const IO=preload("res://deathmatch/network/disk_worker.gd")
const Assets=preload("res://deathmatch/assets/panel.gd")
var failures: Array=[]
var results: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_join("Hostname check","localhost",29987)
	var deadline:=Time.get_ticks_msec()+3000
	while not game.multiplayer.multiplayer_peer is ENetMultiplayerPeer and Time.get_ticks_msec()<deadline:await process_frame
	check(game.multiplayer.multiplayer_peer is ENetMultiplayerPeer and game.loading.blocking,"Queued hostname resolution starts an ENet connection without blocking the scene")
	game.disconnect_game("Lookup test done")
	check(not game.loading.blocking and not game.multiplayer.multiplayer_peer is ENetMultiplayerPeer,"Cancelling the connection clears its join state")
	game.free()
	var directory:="/tmp/fpsloppa-install-%d"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var archive:=directory+"/assets.zip"
	var zip:=ZIPPacker.new();zip.open(archive);zip.start_file("maps/test.txt");zip.write_file("asset fixture".to_utf8_buffer());zip.close_file();zip.close()
	var manifest:={"sha256":FileAccess.get_sha256(archive),"files":[{"path":"maps/test.txt","size":13,"sha256":"asset fixture".sha256_text()}]}
	var disk:=IO.new();root.add_child(disk)
	disk.submit(Assets.install_archive.bind(manifest,archive,directory),func(result):results.append(result))
	while results.is_empty():await process_frame
	check(results[0]=="Base assets installed." and FileAccess.get_file_as_string(directory+"/maps/test.txt")=="asset fixture","Worker verifies and extracts a base-asset archive")
	IO.text_file(directory+"/maps/test.txt","local edit")
	results.clear();disk.submit(Assets.install_archive.bind(manifest,archive,directory),func(result):results.append(result))
	while results.is_empty():await process_frame
	check(FileAccess.get_file_as_string(directory+"/maps/test.txt")=="local edit","Background installation preserves existing local edits")
	manifest.sha256="0".repeat(64)
	results.clear();disk.submit(Assets.install_archive.bind(manifest,archive,directory),func(result):results.append(result))
	while results.is_empty():await process_frame
	check(results[0]=="Asset archive checksum mismatch.","Corrupt archive is rejected before extraction")
	disk.track(archive);disk.track(directory+"/maps/test.txt");disk.free()
	DirAccess.remove_absolute(directory+"/maps");DirAccess.remove_absolute(directory)
	print("NETWORK_WORKERS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
