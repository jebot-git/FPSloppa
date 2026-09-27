extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	var d=g.demos;var tracked: bool=OS.get_cmdline_user_args().has("--tracked")
	check(d.open_demo("res://test-results/classic-de/utility-vr-network.fpsdemo" if tracked else "res://test-results/classic-de/utility-network.fpsdemo"),"Production parser opens grenade recording")
	if not d.playing:g.free();quit(1);return
	var seen: Dictionary={};var smoke_time:=0.0;var sample: Dictionary={}
	for offset in d.offsets:
		d.input.seek(offset);var f: Dictionary=d.read_frame();d.apply_frame(f,false)
		var u=g.match_mode.defusal.utility
		for p in u.flying.values():seen[p.kind]=true
		if not u.clouds.is_empty():seen.smoke=true;smoke_time=f.time
		if not u.flashes.is_empty():seen.flash=true
		if f.events.any(func(e):return e[0]=="_de_grenade_fx"):seen.fx=true;sample=f.duplicate(true)
	check(seen.has(0) and seen.has(1) and seen.has(2),"All three projectile kinds survive playback")
	check(seen.has("smoke") and seen.has("flash") and seen.has("fx"),"Smoke, flashes and burst events survive playback")
	d.seek(smoke_time);check(not g.match_mode.defusal.utility.clouds.is_empty(),"Seeking restores active smoke")
	d.seek(0);check(g.match_mode.defusal.utility.clouds.is_empty(),"Backward seek clears future effects")
	var bad: Dictionary=sample.duplicate(true);bad.events=[["_de_grenade_fx",[Vector3.ZERO,99]]]
	check(not d.valid_frame(bad),"Replay rejects unknown grenade burst kind")
	bad=sample.duplicate(true);bad.snapshot[10].defusal.utility.shots=[[1,0,1,Vector3(INF,0,0),Vector3.ZERO,0,false]]
	check(not d.valid_frame(bad),"Replay rejects invalid utility positions")
	var result:={"checks":checks,"frames":d.offsets.size(),"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/classic-de/utility-vr-demo.json" if tracked else "res://test-results/classic-de/utility-demo.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("UTILITY_DEMO_RESULT ",JSON.stringify(result))
	d.stop_playback();g.free();quit(0 if failures.is_empty() else 1)
