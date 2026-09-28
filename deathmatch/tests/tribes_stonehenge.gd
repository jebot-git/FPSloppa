extends SceneTree
const T=preload("res://deathmatch/movement/tribes.gd")
var g
var failures: Array=[]
var checks:=0
var routes: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_stonehenge";g.start_host("Tribes terrain",0,100,30,true,"st","tribes")
	check(g.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"Practice remains offline when bots are disabled")
	if OS.get_cmdline_user_args().has("--no-bots"):
		check(g.players.size()==1 and not is_instance_valid(g.bots),"Empty practice starts without bot actors or AI")
	g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.set_process(false);g.bots.set_physics_process(false)
	for id in g.players:
		if id!=1:g.players[id].spectator=true;g.fighters[id].show_alive(false,false)
	await physics_frame;await physics_frame
	var a=g.fighters[1]
	check(g.active and g.current_map=="ctf_stonehenge" and a.tribes_enabled,"Stonehenge CTF spawns the Tribes movement profile")
	check(not g.jetpacks.enabled() and not a.jetpack_enabled,"Intrinsic jets do not use the arena pickup system")
	check(g.players[1].owned==[0,2,3,9,10,11] and g.players[1].tribes_pack=="none","Tribes CTF spawns Light with blaster, chaingun and disc, without a purchased pack")
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Stonehenge/probes.json"))
	var space=g.get_world_3d().direct_space_state
	for route in source.routes:
		# Enter representative route segments, then follow gravity for three
		# seconds. This tests the compiled terrain, not an idealized heightmap.
		for fraction in [.25,.5,.75]:
			var index:=int((route.samples.size()-2)*fraction)
			var p:=Vector3(route.samples[index][0],route.samples[index][1],route.samples[index][2])
			var next:=Vector3(route.samples[index+1][0],route.samples[index+1][1],route.samples[index+1][2])
			var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*150,p-Vector3.UP*10,1))
			if hit.is_empty():check(false,"Route has terrain");continue
			for speed in [30.,60.,100.]:
				a.reset_tribes();a.position=hit.position+Vector3.UP*.03;a.velocity=(next-p).normalized()*speed;a.ski_held=true
				var begin: Vector3=a.position;var maximum: float=speed;var below:=0;var samples:=0
				for tick in 180:
					a.simulate(Vector2.ZERO,0,false,1.0/60)
					maximum=maxf(maximum,a.velocity.length());samples+=1
					if not a.position.is_finite() or not a.velocity.is_finite():below+=1;break
					# A downward ray must find terrain below the capsule; terrain
					# triangles, walls and landings all use actual production collision.
					var under: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(a.position+Vector3.UP*.30,a.position-Vector3.UP*400,1))
					if under.is_empty() or under.position.y>a.position.y+.15:below+=1
				var row:={"route":route.name,"fraction":fraction,"entry_m_s":speed,"max_m_s":maximum,"distance_m":a.position.distance_to(begin),"bad_contacts":below,"samples":samples}
				routes.append(row)
				check(below==0 and maximum<speed+61,"%s %.2f at %d m/s stays above terrain with bounded energy"%[route.name,fraction,speed])
	# Test flag passage within one tick, with both endpoints outside its radius.
	for team in [0,1]:
		g.players[1].team=team;g.players[1].dead=false
		for flag in [0,1]:g.match_mode.return_flag(flag)
		var base: Vector3=g.match_mode.bases[1-team]
		a.position=base+Vector3(2,0,0);a.travel_path=[base-Vector3(2,0,0),a.position]
		g.match_mode.tick(.016)
		check(g.match_mode.flags[1-team].carrier==1,"Swept ski passage takes team %d enemy flag"%team)
		var before: int=g.match_mode.scores[team];base=g.match_mode.bases[team]
		a.position=base+Vector3(2,0,0);a.travel_path=[base-Vector3(2,0,0),a.position];g.match_mode.tick(.016)
		check(g.match_mode.scores[team]==before+1,"Swept ski passage captures for team %d"%team)
	a.jet_held=true;a.tribes_state.energy=20;g._spawn(1)
	check(a.tribes_state.energy==60 and not a.jet_held and a.velocity==Vector3.ZERO,"Respawn resets intrinsic energy, input and momentum")
	for mode in ["de","tf","tb","as","ig","if","cc"]:
		g.match_mode.kind=mode;g.armory.select("tribes")
		check(g.armory.effective()!="tribes","Fixed mode %s keeps its established loadout"%mode)
	g.match_mode.kind="ctf";g.armory.select("tribes")
	var result:={"checks":checks,"failures":failures,"routes":routes}
	FileAccess.open("res://test-results/tribes/stonehenge.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TRIBES_STONEHENGE ",JSON.stringify({"checks":checks,"failures":failures,"routes":routes.size()}))
	g.disconnect_game();g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
