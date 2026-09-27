extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frame_at(index: int) -> Dictionary:
	g.demos.input.seek(g.demos.offsets[index]);return g.demos.read_frame()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="qsrc_dm1";g.start_host("Jetpack replay",0,20,10,true,"ig")
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	g.match_mode.jetpacks=true;g.match_mode.reset()
	var path: String="/tmp/fpsloppa-jetpack-"+str(OS.get_process_id())+".fpsdemo"
	check(g.demos.start_record(path),"Production recorder starts")
	g._send_snapshot()
	var p: Dictionary=g.pickups.filter(func(item):return item.kind=="jetpack")[0]
	g.fighters[1].position=p.position;g._collect(1)
	g.fighters[1].jetpack_requested=true;g.fighters[1].simulate(Vector2.RIGHT,0,false,.02)
	g.clock+=1;g._send_snapshot()
	g.fighters[1].jetpack_state.mode=0;g.fighters[1].jetpack_state.cooldown=6.0
	g.clock+=1;g._send_snapshot()
	g.players[1].invulnerable=0;g._damage(1,1,1000,"Replay",true)
	g.clock+=1;g._send_snapshot()
	g._spawn(1);g.clock=p.respawn;g._respawn_pickups();g._send_snapshot()
	g.match_mode.jetpacks=false;g.jetpacks.rebuild();g.clock+=1;g._send_snapshot()
	g.demos.stop_record()
	check(g.demos.open_demo(path),"All new snapshots open through the production demo parser")
	if not g.demos.playing:print(g.demos.message);finish();return
	check(g.demos.offsets.size()==6,"Recording retains all six lifecycle frames")
	var available: Dictionary=frame_at(0);g.demos.apply_frame(available,false)
	check(g.match_mode.jetpacks and g.jetpacks.positions().size()==1,"Replay restores the option and authoritative IG pickup layout")
	for item in g.pickups:
		item.node=Node3D.new();g.get_node("Map").add_child(item.node)
	g.demos.apply_frame(available,false)
	check(g.pickups.all(func(item):return item.node.visible==(item.kind=="jetpack")),"IG replay displays jetpack while keeping ordinary supplies hidden")
	var flying: Dictionary=frame_at(1);g.demos.apply_frame(flying,false)
	check(g.players[1].jetpack and g.fighters[1].jetpack_enabled and g.fighters[1].jetpack_state.mode==1,"Replay restores owned equipment and active flight")
	check(g.pickups.filter(func(item):return item.kind=="jetpack").all(func(item):return not item.available and not item.node.visible),"Collected pickup remains absent in replay")
	g.demos.apply_frame(frame_at(2),false)
	check(g.fighters[1].jetpack_state.mode==0 and is_equal_approx(g.fighters[1].jetpack_state.cooldown,6.0),"Replay restores cooldown")
	g.demos.apply_frame(frame_at(3),false)
	check(not g.players[1].jetpack and not g.fighters[1].jetpack_enabled,"Recorded death removes equipment")
	g.demos.apply_frame(frame_at(4),false)
	check(not g.players[1].dead and not g.players[1].jetpack and g.pickups.filter(func(item):return item.kind=="jetpack")[0].available,"Replay restores respawn without ownership and timed pickup return")
	g.demos.apply_frame(frame_at(5),false)
	check(not g.match_mode.jetpacks and g.jetpacks.positions().is_empty(),"Replay handles disabled configuration")
	g.demos.seek(flying.time)
	check(g.jetpacks.positions().size()==1 and g.fighters[1].jetpack_state.mode==1,"Backward seeking recreates layout and flight")
	var legacy: Dictionary=available.duplicate(true)
	legacy.snapshot[10].erase("jetpacks");legacy.snapshot[10].erase("jetpack_pickups")
	for state in legacy.snapshot[10].locomotion.values():
		for key in ["jetpack","jetpack_owned","jetpack_ack"]:state.erase(key)
	check(g.demos.valid_frame(legacy),"Pre-jetpack recordings remain readable")
	g.demos.apply_frame(legacy,false)
	check(not g.match_mode.jetpacks and g.jetpacks.positions().is_empty() and not g.fighters[1].jetpack_enabled,"Older replay clears equipment from a previous seek")
	for malformed in [{}, {"mode":3}, {"cooldown":NAN}, {"heading":Vector2(INF,0)}, {"activation":-1}, {"time":"invalid"}]:
		var bad: Dictionary=flying.duplicate(true)
		if malformed.is_empty():bad.snapshot[10].locomotion[1].jetpack={}
		else:bad.snapshot[10].locomotion[1].jetpack.merge(malformed,true)
		check(not g.demos.valid_frame(bad),"Parser rejects malformed flight state "+str(malformed))
	var bad_layout: Dictionary=available.duplicate(true);bad_layout.snapshot[10].jetpack_pickups=[Vector3(INF,0,0)]
	check(not g.demos.valid_frame(bad_layout),"Parser rejects non-finite pickup layout")
	g.demos.stop_playback();DirAccess.remove_absolute(path);finish()
func finish():
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/jetpacks/demo.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("JETPACK_DEMO_RESULT ",JSON.stringify(result));g.free();quit(0 if failures.is_empty() else 1)
