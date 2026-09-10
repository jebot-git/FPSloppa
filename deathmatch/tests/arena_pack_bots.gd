extends SceneTree
var failures: Array=[]
var results: Array=[]
func _initialize():call_deferred("run")
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://optional-arena-pack/manifest.json"))
	for row: Dictionary in rows:
		game.selected_map=row.id;game.start_host("Map validation",0,100,60,true,row.mode)
		if not game.active:failures.append(row.id+": cannot start practice");continue
		var initial: Dictionary={};var travelled: Dictionary={}
		for id in [-1,-2,-3]:initial[id]=game.fighters[id].position;travelled[id]=0.0
		for tick in 720:
			await physics_frame
			for id in [-1,-2,-3]:
				var now: Vector3=game.fighters[id].position
				var step: float=now.distance_to(initial[id]);initial[id]=now
				# Exclude teleports/respawns from the movement evidence.
				if step<1:travelled[id]+=step
		var total:=0.0
		for id in travelled:total+=travelled[id]
		if total<15:failures.append(row.id+": bots did not traverse enough ground")
		if row.mode in ["cc","ig"]:
			for pickup in game.pickups:
				if pickup.available:failures.append(row.id+": mode pickup modifier failed");break
		if row.mode=="tf":
			for id in game.players:
				if not game.players[id].has("tf_class"):failures.append(row.id+": missing TF class state")
		results.append({"id":row.id,"mode":row.mode,"physics_ticks":720,"bot_travel_m":total,"scores":game.match_mode.scores.duplicate()})
		print("ARENA_BOTS ",JSON.stringify(results.back()))
		game.disconnect_game("Next map");await physics_frame
	var out:=FileAccess.open("res://test-results/arena-pack-bots.json",FileAccess.WRITE);out.store_string(JSON.stringify({"maps":results,"failures":failures},"  "));out.close()
	print("ARENA_BOTS_RESULT ",JSON.stringify(failures));game.free();quit(0 if failures.is_empty() else 1)
