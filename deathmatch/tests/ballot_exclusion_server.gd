extends SceneTree
func _initialize():run.call_deferred()
func run():
	var path:="/tmp/fps-ballot-server-%d.cfg"%OS.get_process_id()
	FileAccess.open(path,FileAccess.WRITE).store_string('set net_ip "127.0.0.1"\nset sv_voice 0\nset sv_log_level off\nset sv_gametypes "dm ig"\nset sv_ballot_exclude_modes "IG"\nset sv_maplist "qsrc_dm1 qsrc_dm6"\n')
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.set_process(false);g.set_physics_process(false)
	g._start_dedicated(PackedStringArray(["--config",path,"--port","0"]))
	var ok: bool=g.active and g.dedicated and g.lobby.excluded_modes==["ig"] and g.votes.allowed_modes==["dm","ig"]
	g._end_round()
	ok=ok and not g.lobby.offered.is_empty() and g.lobby.offered.all(func(row):return row.mode=="dm") and g.votes.match_choices().any(func(row):return row.mode=="ig")
	ok=ok and g.rcon.execute("status").ballot_exclude_modes==["ig"]
	print("BALLOT_EXCLUSION_SERVER ",ok)
	g.disconnect_game();g.free();DirAccess.remove_absolute(path);quit(0 if ok else 1)
