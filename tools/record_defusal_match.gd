extends SceneTree
## Record an unmodified, real-time 6v6 bot match through the production demo writer.
var game
var output_dir: String
var started_ms: int
var rounds: Array=[]
func _initialize():run.call_deferred()
func run():
	output_dir="res://recordings/de-6v6-"+Time.get_datetime_string_from_system().replace(":","-")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.dedicated=true;game.bind_address="127.0.0.1";game.max_clients=16
	game.bot_population.count_target=12;game.match_mode.configure({"sv_gametype":"de"})
	game.selected_map="de_dust2_rebuilt";game.lobby.enabled=false
	game.start_host("DE 6v6 recording",28986,20,60,false,"de")
	if not game.active:push_error("Could not start recording server");quit(1);return
	game.set_physics_process(false)
	while not game.bots.ready_to_walk or not game.bots.navigation.ready():await physics_frame
	assert(game.players.size()==12)
	for team in [0,1]:assert(game.players.values().filter(func(s):return s.team==team and not s.spectator).size()==6)
	assert(game.demos.start_record(output_dir+"/match.fpsdemo"))
	started_ms=Time.get_ticks_msec();game.set_physics_process(true)
	var last_phase:=""
	while game.match_mode.defusal.phase!="finished" and Time.get_ticks_msec()-started_ms<5400000:
		var de=game.match_mode.defusal
		var phase: String="%d:%s"%[de.round_id,de.phase]
		if phase!=last_phase:
			last_phase=phase
			var row:={"time":snappedf(game.clock-game.demos.started,.01),"round":de.round_id,"phase":de.phase,"attacking":de.attacking,"scores":game.match_mode.scores.duplicate(),"reason":de.message}
			rounds.append(row);print("DE_RECORD_PROGRESS ",JSON.stringify(row));receipt(false)
		await create_timer(.5).timeout
	var completed: bool=game.match_mode.defusal.phase=="finished"
	game._send_snapshot();game.demos.stop_record();receipt(completed)
	print("DE_RECORD_RESULT ",ProjectSettings.globalize_path(output_dir)," completed=",completed)
	game.disconnect_game();game.free();quit(0 if completed else 1)
func receipt(completed: bool):
	var stats: Array=[]
	for id in game.players:
		var s: Dictionary=game.players[id]
		stats.append({"id":id,"name":s.name,"team":s.team,"kills":s.kills,"deaths":s.deaths})
	var teams: Array=[0,0];var spectators:=0
	for s in game.players.values():
		if s.spectator:spectators+=1
		elif s.team in [0,1]:teams[s.team]+=1
	var data:={"completed":completed,"map":game.current_map,"mode":"de","players":teams[0]+teams[1],"teams":teams,"spectators":spectators,"real_time":true,"time_scale":Engine.time_scale,"seconds":snappedf(game.clock-game.demos.started,.01),"wall_seconds":(Time.get_ticks_msec()-started_ms)/1000.0,"scores":game.match_mode.scores.duplicate(),"rounds":rounds,"stats":stats,"demo":"match.fpsdemo","protocol":game.PROTOCOL}
	FileAccess.open(output_dir+"/match.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
