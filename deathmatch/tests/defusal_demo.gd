extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	var demo=g.demos
	check(demo.open_demo("res://test-results/defusal/network.fpsdemo"),"Production parser opens real two-round network recording")
	if not demo.playing:print(demo.message);g.free();quit(1);return
	var modes: Dictionary={};var plant_sites: Dictionary={};var kit:=false;var money:=false;var code:=false;var cuts:=false;var sample: Dictionary={};var planted_time:=0.0
	for offset in demo.offsets:
		demo.input.seek(offset);var frame: Dictionary=demo.read_frame();demo.apply_frame(frame,false)
		var de=g.match_mode.defusal;modes[de.phase]=true
		if de.planted:plant_sites[de.planted_site]=true;planted_time=frame.time
		kit=kit or de.accounts.values().any(func(a):return a.kit)
		money=money or de.accounts.values().any(func(a):return a.cash==150)
		code=code or de.defuse_index>0;cuts=cuts or de.cut_mask>0
		if sample.is_empty() and not frame.snapshot[10].defusal.is_empty():sample=frame.duplicate(true)
	check(g.current_map=="de_dust2_rebuilt" and g.armory.effective()=="cs16","Replay restores Dust2 and forced CS arsenal")
	check(modes.has("prepare") and modes.has("live") and modes.has("post"),"Replay preserves preparation, live and round-result phases")
	check(plant_sites.has(0) and plant_sites.has(1),"Replay contains both bomb sites")
	check(kit and money and code and cuts,"Economy, kits, keypad progress and cut wires survive replay")
	demo.seek(planted_time);check(g.match_mode.defusal.planted,"Seeking restores planted bomb")
	demo.seek(0);check(g.match_mode.defusal.phase=="prepare" and not g.match_mode.defusal.planted,"Backward seeking restores earlier preparation")
	for field in ["accounts","arm_code","position","phase","basis"]:
		var bad: Dictionary=sample.duplicate(true);bad.snapshot[10].defusal[field]="invalid"
		check(not demo.valid_frame(bad),"Parser rejects malformed DE "+field)
	demo.apply_frame(sample,false)
	check(g.players.keys().all(func(id):return not g.variant_combat.cs.status(id).is_empty()),"Replay restores CS magazine and action HUD state")
	var legacy: Dictionary=sample.duplicate(true);legacy.snapshot[10].erase("defusal")
	check(demo.valid_frame(legacy),"Optional DE snapshot does not break older recordings")
	var result:={"checks":checks,"frames":demo.offsets.size(),"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/demo.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_DEMO_RESULT ",JSON.stringify(result));demo.stop_playback();g.free();quit(0 if failures.is_empty() else 1)
