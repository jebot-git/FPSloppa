extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args();var folder: String=args[0];var ids:=args[1].split(",")
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var results: Array=[];var failures: Array=[]
	for id in ids:
		game.selected_map=id;game.start_host("AD bot test",0,100,60,true,"dm")
		if not game.active:failures.append(id+": start failed");continue
		var previous: Dictionary={};var moved: Dictionary={}
		for peer in [-1,-2,-3]:previous[peer]=game.fighters[peer].position;moved[peer]=0.0
		for tick in 600:
			await physics_frame
			for peer in previous:
				var pos: Vector3=game.fighters[peer].position;var step: float=previous[peer].distance_to(pos)
				if step<1:moved[peer]+=step
				previous[peer]=pos
		var total:=0.0
		for value in moved.values():total+=value
		if total<15:failures.append(id+": insufficient bot movement")
		results.append({"id":id,"ticks":600,"bot_movement_m":moved,"total_m":total});print("AD_BOTS ",JSON.stringify(results.back()))
		game.disconnect_game("Next test");await physics_frame
	var out:=FileAccess.open(folder+"/bots.json",FileAccess.WRITE);out.store_string(JSON.stringify({"maps":results,"failures":failures},"  "));out.close()
	game.free();await process_frame;print("AD_BOTS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
