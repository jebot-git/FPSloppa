extends "res://tools/tribes/live_match.gd"
## Trailer footage source: ordinary 8v8 authority, plus two assigned vehicle
## pilots using production purchases, seating and flight inputs. No stat buffs.
class FilmArena extends "res://deathmatch/arena.gd":
	var pilot_jobs: Dictionary={}
	var flight_route: Array=[]
	func _configure_tribes(id: int,command: Dictionary) -> void:
		var c=match_mode.tribes.vehicles
		if pilot_jobs.has(id):
			var job: Dictionary=pilot_jobs[id]
			if not c.rows.has(job.key) or players[id].dead:pilot_jobs.erase(id)
			else:
				var row: Dictionary=c.rows[job.key]
				command.jump=false;command.jet_held=false;command.ski=false;command.move=Vector2.ZERO;command.fire=false;command.input_blocked=false
				if not c.mounted(id) and clock>=row.ready:
					fighters[id].position=c.seat_position(row,0)+row.position.direction_to(row.position+Vector3.RIGHT)*2.7
					c.board(id,job.key,0)
				if c.mounted(id):
					var goal: Vector3=flight_route[job.step]
					var flat:=Vector3(goal.x-row.position.x,0,goal.z-row.position.z)
					if flat.length()<45:job.step=(job.step+1)%flight_route.size()
					command.yaw=atan2(-flat.x,-flat.z);command.move=Vector2(0,-.8);command.vr_device=true
					var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(row.position,row.position-Vector3.UP*400,1,[c.bodies[job.key].get_rid()]))
					var height: float=row.position.y-hit.position.y if not hit.is_empty() else 100.0
					command.fly=clampf((c.definition(row).altitude*.7-height)*.25,-1,1)
					command.fire=row.kind=="scout" and fmod(clock,12)<3
		super._configure_tribes(id,command)
var disc_events: Array=[]
var last_disc: Dictionary={}
func run():
	options=JSON.parse_string(OS.get_cmdline_user_args()[0]);seed(int(options.get("seed",9293)))
	DirAccess.make_dir_recursive_absolute(options.output)
	game=load("res://deathmatch/arena.tscn").instantiate();game.set_script(FilmArena);root.add_child(game)
	game.dedicated=true;game.bind_address="127.0.0.1";game.max_clients=32;game.bot_population.count_target=16
	game.match_mode.configure({"sv_gametype":"st","capturelimit":100});game.selected_map=options.map;game.lobby.enabled=false
	game.start_host("ST cinematic source 8v8",int(options.port),100,15,false,"st")
	if not game.active:push_error("Cinematic source failed to host");quit(1);return
	game.voice_enabled=false;start=game.clock
	var directory: String={"ctf_stonehenge":"Stonehenge","ctf_raindance":"Raindance","ctf_katabatic":"Katabatic"}[options.map]
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/"+directory+"/probes.json"))
	var points: Array=probes.routes[0].samples
	for index in range(0,points.size(),maxi(1,points.size()/8)):
		var a: Array=points[index];game.flight_route.append(Vector3(a[0],a[1],a[2]))
	assert(game.demos.start_record(options.output+"/match.fpsdemo"),game.demos.message)
	var assigned:=false;Engine.time_scale=4;Engine.physics_ticks_per_second=240;Engine.max_physics_steps_per_frame=32
	print("CINEMATIC_SOURCE_READY ",options.map)
	while game.active:
		await physics_frame
		if not assigned and game.players.size()>=16 and game.clock-start>4:
			assigned=true;assign_pilots()
		measure_movement();observe_flags()
		for id in game.bots.brains:
			var brain: Dictionary=game.bots.brains[id];var stamp: float=brain.get("disc_jump_at",0)
			if stamp>float(last_disc.get(id,0)):
				last_disc[id]=stamp
				var actor=game.fighters[id]
				disc_events.append({"seconds":game.clock-start,"bot":id,"position":actor.position,"velocity":actor.velocity,"hp":game.players[id].hp,"carrier":game.match_mode.st.carried(id)>=0})
		if game.clock>=travel_at:travel_at=game.clock+.1;sample_travel()
		if game.clock>=sample_at:sample_at=game.clock+5;sample()
		if capture_deadline.expired(game.clock-start):termination_reason=capture_deadline.reason(game.clock-start);break
		if game.clock-start>=float(options.get("seconds",540)):termination_reason="duration_reached";break
	game.demos.stop_record()
	write("disc-jumps.json",disc_events);write("travel.json",travel_samples);write("samples.json",samples)
	write("result.json",{"seconds":game.clock-start,"scores":game.match_mode.scores,"flag_events":flag_events,"disc_jumps":disc_events,"termination_reason":termination_reason,"teams":[8,8],"vehicle_direction":"One bot per team assigned production vehicle pilot inputs for cinematic coverage"})
	print("CINEMATIC_SOURCE_DONE ",options.map," ",termination_reason," disc_jumps=",disc_events.size())
	game.disconnect_game();game.queue_free();await process_frame;quit()
func assign_pilots():
	var c=game.match_mode.tribes.vehicles;var pads=game.match_mode.tribes.stations()
	for team in [0,1]:
		var ids: Array=game.players.keys().filter(func(id):return id<0 and game.players[id].team==team and not game.players[id].dead)
		if ids.is_empty():continue
		var terminals: Array=range(pads.rows.size()).filter(func(i):return pads.rows[i].team==team and pads.rows[i].kind=="vehicle")
		if terminals.is_empty():continue
		var id: int=ids.back();var index: int=terminals[0]
		game.match_mode.tribes.apply_equipment(id,"light",[3,2,0],"none")
		game.fighters[id].position=pads.rows[index].position
		var kind: String="scout" if team==0 else "hpc" if options.map=="ctf_katabatic" else "lpc"
		if c.purchase(id,game.map_epoch,game.players[id].serial,kind):
			game.pilot_jobs[id]={"key":c.rows.keys().back(),"step":team*game.flight_route.size()/2}
			print("FILM_PILOT ",id," ",kind)
