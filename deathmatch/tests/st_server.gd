extends SceneTree
func _initialize():run.call_deferred()
func run():
	var path:="/tmp/fps-st-server-%d.cfg"%OS.get_process_id()
	FileAccess.open(path,FileAccess.WRITE).store_string('set net_ip "127.0.0.1"\nset sv_voice 0\nset sv_log_level off\nset sv_gametype "st"\nset sv_gametypes "dm st"\nset sv_maplist "qsrc_dm1"\nset sv_ballot_exclude_modes "st"\nset sv_tribes_infinite_energy 1\n')
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.set_process(false);g.set_physics_process(false);g._start_dedicated(PackedStringArray(["--config",path,"--port","0"]))
	var ok: bool=g.active and g.dedicated and g.match_mode.kind=="st" and g.current_map=="ctf_stonehenge" and g.armory.effective()=="tribes" and g.match_mode.tribes.infinite_energy
	ok=ok and g.mode_maplists.st==["ctf_stonehenge"] and g.votes.match_choices().any(func(r):return r.mode=="st" and r.map=="ctf_stonehenge")
	g._end_round();ok=ok and g.lobby.offered.all(func(r):return r.mode=="dm")
	print("ST_SERVER ",ok);g.disconnect_game();g.free();DirAccess.remove_absolute(path);quit(0 if ok else 1)
