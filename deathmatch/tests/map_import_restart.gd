extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
var failures: Array=[]
var checks: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--asset-root"):push_error("Use an isolated --asset-root");quit(2);return
	var source:=Maps.Paths.root()+"/ig_restart.bsp"
	var bytes:=FileAccess.get_file_as_bytes("res://maps/qsrc_dm1.bsp");bytes.append_array(" restart policy fixture".to_utf8_buffer())
	FileAccess.open(source,FileAccess.WRITE).store_buffer(bytes)
	var row:=Maps.import_custom(source)
	if row.has("error"):push_error(row.error);quit(1);return
	FileAccess.open(Maps.Paths.folder("maps")+"ig_maplist.txt",FileAccess.WRITE).store_string("qsrc_dm1\n"+row.id+"\n")
	var config:=Maps.Paths.root()+"/server.cfg"
	FileAccess.open(config,FileAccess.WRITE).store_string('set map qsrc_dm1\nset sv_gametype if\nset sv_gametypes "ig if"\nset sv_voice 0\nset sv_log_level off\n')
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game._start_dedicated(PackedStringArray(["--config",config,"--port","28775"]))
	check(game.active and game.dedicated,"Dedicated server starts IF from persisted import metadata and maplists")
	check(row.id in game.mode_maplists.ig,"IG import retains server maplist membership after startup")
	check(game.mode_maplists["if"]==["qsrc_dm1"] and game.map_rotation==["qsrc_dm1"],"Restart excludes an IG-tagged import from the legacy IF rotation")
	check(game.maps_for_mode("if")==["qsrc_dm1"],"IF votes retain the same filtered rotation")
	FileAccess.open("res://test-results/map-previews/restart.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("MAP_IMPORT_RESTART_RESULT ",JSON.stringify(failures))
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
