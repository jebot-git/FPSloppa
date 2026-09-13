extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func run() -> void:
	seed(7129);Engine.time_scale=3;Engine.physics_ticks_per_second=180
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="as_hislop";game.start_host("AI assault",0,100,60,true,"as")
	game.players[1].spectator=true
	for id in [-1,-2,-3]:game.players[id].team=game.match_mode.assault.attacking;game._spawn(id)
	var furthest_checkpoint:=0;var furthest_stage:=0
	for frame in 7200:
		await physics_frame
		furthest_checkpoint=maxi(furthest_checkpoint,game.match_mode.assault.checkpoint)
		furthest_stage=maxi(furthest_stage,game.match_mode.assault.stage)
		if frame%1800==1799:
			var states: Array=[]
			for id in [-1,-2,-3]:states.append({"id":id,"position":str(game.fighters[id].position),"goal":game.bots.brains[id].goal_key,"stuck":game.bots.brains[id].stuck})
			print("BOT_ASSAULT_PROGRESS ",JSON.stringify({"frame":frame,"checkpoint":furthest_checkpoint,"stage":furthest_stage,"bots":states}))
		if furthest_stage>=1:break
	if furthest_checkpoint<1:failures.append("Attackers never secured a forward spawn")
	if furthest_stage<1:failures.append("Attackers never activated the first console")
	game.disconnect_game();game.free()
	print("BOT_ASSAULT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
