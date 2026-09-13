extends SceneTree
var failures: Array=[]
var results: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	seed(7129)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var maps: Array=[{"map":"qsrc_dm1","mode":"dm"},{"map":"qsrc_dm2","mode":"tdm"},{"map":"tf_vesper","mode":"tf"},{"map":"as_hislop","mode":"as"}]
	for row in maps:
		game.selected_map=row.map;game.start_host("AI traversal",0,100,60,true,row.mode)
		if not game.active or game.current_map!=row.map:failures.append("Unable to load "+row.map);continue
		var travelled: Dictionary={};var previous: Dictionary={};var goals: Dictionary={};var jumps:=0;var shots:=0;var max_tick_us:=0
		for id in [-1,-2,-3]:travelled[id]=0.0;previous[id]=game.fighters[id].position
		for frame in 900:
			await physics_frame
			for id in [-1,-2,-3]:
				var point: Vector3=game.fighters[id].position
				var distance: float=point.distance_to(previous[id]);previous[id]=point
				if distance<1:travelled[id]+=distance
				if game.players[id].jump:jumps+=1
				if game.players[id].fire:shots+=1
				if game.bots.brains.has(id):goals[game.bots.brains[id].goal_kind]=true
			if frame%120==0:
				var before:=Time.get_ticks_usec();game.bots.tick(0.0);max_tick_us=maxi(max_tick_us,Time.get_ticks_usec()-before)
		for id in travelled:
			if travelled[id]<8:failures.append("%s bot %s travelled only %.2fm"%[row.map,id,travelled[id]])
		if row.mode=="as" and not goals.has("checkpoint") and not goals.has("objective") and not goals.has("destroy"):failures.append("Assault attackers never pursued an objective")
		if row.mode=="tf" and not goals.has("objective") and not goals.has("capture"):failures.append("TF bots never pursued flags")
		var report: Dictionary={"map":row.map,"mode":row.mode,"metres":travelled,"goals":goals.keys(),"jump_inputs":jumps,"fire_inputs":shots,"links":game.bots.navigation.links.size(),"sample_tick_us":max_tick_us}
		results.append(report);print("BOT_TRAVERSAL ",JSON.stringify(report))
		game.disconnect_game();await physics_frame
	var file:=FileAccess.open("res://test-results/bot-traversal.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"results":results,"failures":failures},"  "))
	game.free();print("BOT_TRAVERSAL_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
