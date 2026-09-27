extends SceneTree
var g
var options: Dictionary
var phases: Array=[]
var samples: Array=[]
var started:=0
func _initialize():run.call_deferred()
func write_json(name: String,data):
	FileAccess.open(options.output+"/"+name,FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
func run():
	options=JSON.parse_string(OS.get_cmdline_user_args()[0]);seed(int(options.get("seed",7129)))
	g=load("res://deathmatch/arena.tscn").instantiate();g.match_mode.defusal=load("res://tools/defusal/series_rules.gd").new();root.add_child(g)
	g.dedicated=true;g.bind_address="127.0.0.1";g.max_clients=16;g.bot_population.count_target=12
	g.match_mode.configure({"sv_gametype":"de"});g.selected_map=options.map;g.lobby.enabled=false;g.votes.enabled=false
	g.start_host("DE 6v6 · six-round map test",int(options.port),20,60,false,"de");g.set_physics_process(false)
	assert(g.active and g.current_map==options.map)
	while not g.bots.ready_to_walk or not g.bots.navigation.ready():await physics_frame
	assert(g.players.size()==12)
	write_json("server-ready.json",{"map":g.current_map,"port":options.port})
	var deadline:=Time.get_ticks_msec()+120000
	while not FileAccess.file_exists(options.output+"/view-ready.json"):
		if Time.get_ticks_msec()>deadline:push_error("Live view did not become ready");quit(1);return
		g._send_snapshot();await create_timer(.1).timeout
	for team in [0,1]:assert(g.players.values().filter(func(s):return s.team==team and not s.spectator).size()==6)
	assert(g.demos.start_record(options.output+"/match.fpsdemo"));started=Time.get_ticks_msec();g.set_physics_process(true)
	var previous:="";var sampled:=0.0
	while g.match_mode.defusal.phase!="finished" and Time.get_ticks_msec()-started<1800000:
		var de=g.match_mode.defusal;var phase: String="%d:%s"%[de.round_id,de.phase]
		if phase!=previous:
			previous=phase;var row:={"time":g.clock-g.demos.started,"round":de.round_id,"phase":de.phase,"attacking":de.attacking,"scores":g.match_mode.scores.duplicate(),"reason":de.message}
			phases.append(row);print("DE_SERIES_PROGRESS ",JSON.stringify(row));receipt(false)
		if g.clock>=sampled:
			sampled=g.clock+1;var bots: Array=[]
			for id in g.players:
				if id>=0:continue
				var s: Dictionary=g.players[id];var brain: Dictionary=g.bots.brains.get(id,{})
				var weapon: Dictionary=g.variant_combat.cs.state(id)
				bots.append({"id":id,"team":s.team,"dead":s.dead,"position":g.fighters[id].position,"hp":s.hp,"weapon":s.weapon,"goal":brain.get("goal_key",""),"target":brain.get("goal",Vector3.ZERO),"path":brain.get("path",[]).size(),"step":brain.get("step",0),"enemy":brain.get("enemy",0),"fire":s.fire,"shots":s.shots,"clip":weapon.clips.get(s.weapon,0),"reloading":weapon.reloading,"holstered":de.gun_holstered(id)})
			samples.append({"time":g.clock-g.demos.started,"round":de.round_id,"planted":de.planted,"bots":bots})
		await create_timer(.25).timeout
	var completed: bool=g.match_mode.defusal.phase=="finished" and g.match_mode.defusal.round_id==6
	g._send_snapshot();receipt(completed);g.demos.stop_record();g.set_physics_process(false)
	# Keep the live network result on screen while the client closes its video.
	for i in 60:g._send_snapshot();await create_timer(.1).timeout
	write_json("server-done.json",{"completed":completed});g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit(0 if completed else 1)
func receipt(completed: bool):
	var teams: Array=[0,0];var spectators:=0;var stats: Array=[]
	for id in g.players:
		var s: Dictionary=g.players[id]
		if s.spectator:spectators+=1
		else:teams[s.team]+=1;stats.append({"id":id,"name":s.name,"team":s.team,"kills":s.kills,"deaths":s.deaths,"shots":s.shots})
	write_json("match.json",{"completed":completed,"map":g.current_map,"map_sha256":g.map_sha,"mode":"de","teams":teams,"spectators":spectators,"real_time":true,"time_scale":Engine.time_scale,"format":"six rounds, sides swapped after three","seconds":g.clock-g.demos.started,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"scores":g.match_mode.scores.duplicate(),"phases":phases,"stats":stats,"samples":samples,"protocol":g.PROTOCOL})
