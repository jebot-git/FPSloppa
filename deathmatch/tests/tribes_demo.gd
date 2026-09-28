extends SceneTree
var g
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frame_at(index: int) -> Dictionary:
	g.demos.input.seek(g.demos.offsets[index]);return g.demos.read_frame()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_stonehenge";g.start_host("Tribes replay",0,100,30,true,"st","tribes")
	g.set_process(false);g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	g.match_mode.tribes.reset();g.match_mode.tribes.energy=[10000,10000,10000];g._spawn(1)
	await physics_frame;await physics_frame
	var path:="/tmp/fpsloppa-tribes-armour-%d-%d.fpsdemo"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	var started: bool=g.demos.start_record(path)
	check(started,"Production recorder starts")
	if not started:g.disconnect_game();g.free();quit(1);return
	g._send_snapshot()
	var a=g.fighters[1];a.jet_held=true;a.ski_held=true
	for tick in 60:a.simulate(Vector2.ZERO,0,false,1.0/60)
	g.clock+=1;g._send_snapshot()
	a.jet_held=false;a.ski_held=false
	for tick in 30:a.simulate(Vector2.ZERO,0,false,1.0/60)
	g.clock+=.5;g._send_snapshot()
	g._spawn(1);g.clock+=1;g._send_snapshot()
	var rules=g.match_mode.tribes
	a.position=rules.stations().rows.filter(func(r):return r.team==g.players[1].team)[0].position
	check(rules.select_equipment(1,"heavy",rules.Arsenal.defaults("heavy"),"energy",true),"Record a real station refit")
	g.clock+=1;g._send_snapshot()
	a.jet_held=true
	for tick in 60:a.simulate(Vector2.ZERO,0,false,1.0/60)
	g.clock+=1
	g.variant_combat.launch(0,3,a.position+Vector3.UP*10,Vector3.FORWARD,{"fixed_turret":"missile","turret_team":0,"target":1})
	g.variant_combat.launch(0,0,a.position+Vector3.UP*12,Vector3.FORWARD,{"tribes_turret":true,"turret_team":0})
	var payload: Dictionary=rules.recovery.empty_payload();payload.ammo[2]=37
	rules.recovery.create(1,payload,a.position+Vector3.UP,Vector3.ZERO,"ammo")
	rules.targeting.beacons[1]={"team":0,"position":a.position+Vector3(2,0,0),"normal":Vector3.UP,"hp":.1*rules.Arsenal.UNIT}
	rules.stations().assets.rows[4].energy=17.0
	g._send_snapshot();g.demos.stop_record()
	check(g.demos.open_demo(path),"Tribes snapshots pass the production demo parser")
	if g.demos.playing:
		check(g.demos.offsets.size()==6,"All movement and armour lifecycle frames retained")
		var flying:=frame_at(1);g.demos.apply_frame(flying,false)
		check(g.armory.effective()=="tribes" and g.fighters[1].tribes_enabled,"Playback restores movement loadout")
		check(g.fighters[1].tribes_state.jetting and absf(g.fighters[1].tribes_state.energy-43)<.05,"Playback restores consumed energy and active jets")
		g.demos.apply_frame(frame_at(2),false)
		check(not g.fighters[1].tribes_state.jetting and absf(g.fighters[1].tribes_state.energy-47)<.05,"Playback restores recharge and released jets")
		g.demos.apply_frame(frame_at(3),false)
		check(g.fighters[1].tribes_state.energy==60,"Playback restores full respawn energy")
		g.demos.seek(flying.time)
		check(g.fighters[1].tribes_state.jetting,"Backward seek restores jetting")
		g.demos.apply_frame(frame_at(5),false)
		check(g.players[1].tribes_class=="heavy" and g.fighters[1].tribes_state.armour=="heavy" and absf(g.fighters[1].tribes_state.energy-36.625)<.05,"Replay restores heavy armour and class-specific energy use")
		check(g.projectiles.values().any(func(p):return p.definition.get("fixed_turret","")=="missile") and g.projectiles.values().any(func(p):return p.definition.name=="REMOTE TURRET"),"Replay restores fixed and remote turret projectile definitions")
		check(g.match_mode.tribes.energy[0]<10000,"Replay restores shared team-energy spending")
		check(g.match_mode.tribes.recovery.rows.size()==1 and g.match_mode.tribes.recovery.rows.values()[0].payload.ammo[2]==37,"Replay restores remaining dropped ammunition")
		check(g.match_mode.tribes.targeting.beacons.size()==1 and g.match_mode.tribes.stations().assets.rows[4].energy==17,"Replay restores target beacons and depleted equipment shield")
		g.demos.apply_frame(flying,false)
		check(g.match_mode.tribes.recovery.rows.is_empty() and g.match_mode.tribes.targeting.beacons.is_empty(),"Backward seek removes future drops and targets")
		var invalid_economy:=frame_at(5).duplicate(true);invalid_economy.snapshot[10].tribes.energy[0]=-1
		check(not g.demos.valid_frame(invalid_economy),"Demo parser rejects invalid team economy")
		var invalid:=flying.duplicate(true);invalid.snapshot[10].locomotion[1].tribes.energy=INF
		check(not g.demos.valid_frame(invalid),"Demo parser rejects invalid energy")
	print("TRIBES_DEMO ",JSON.stringify({"checks":checks,"failures":failures}))
	g.demos.stop_playback();g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
