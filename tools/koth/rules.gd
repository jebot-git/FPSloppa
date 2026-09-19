extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var cfg=preload("res://deathmatch/server/config.gd").parse('set sv_gametype koth\nset koth_move_points 5\nset hilllimit 100\n')
 check(not cfg.has("error") and not cfg.values.has("koth_move_points"),"Retired score-based movement setting remains ignored")
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
 g.start_host("KOTH rules",0,100,30,true,"koth");g._add_player(2,"Opponent")
 g.players[1].team=0;g.players[2].team=1;g.players[1].dead=false;g.players[2].dead=false
 var mode=g.match_mode;var sites: Array=[Vector3(0,100,0),Vector3(20,100,0),Vector3(0,100,20)]
 mode.hills=sites;mode.hill_index=0;mode.hill=sites[0];mode.hill_remaining=30.;mode.scores=[0,0];mode.hill_limit=1000
 g.fighters[1].position=sites[0];g.fighters[2].position=sites[0]+Vector3.RIGHT*50
 mode.tick(29.5)
 check(mode.scores==[29,0] and mode.hill==sites[0] and is_equal_approx(mode.hill_remaining,.5),"Hill stays put and scores normally until the 30-second boundary")
 check(mode.hill_timer_text()=="HILL 1/3 · MOVES IN 1s","Countdown rounds fractional seconds upward")
 g.fighters[2].position=sites[0];mode.tick(1.)
 check(mode.hill==sites[1] and mode.hill_index==1 and is_equal_approx(mode.hill_remaining,29.5),"Contested hill relocates on time and preserves elapsed remainder")
 check(mode.scores==[29,0] and mode.hill_credit==0 and mode.hill_owner==-1,"Move clears contention and partial capture credit; old hill stops scoring")
 g.fighters[2].position=sites[1];mode.tick(1)
 check(mode.scores==[29,1] and mode.hill_owner==1,"New hill accepts immediate control by the other team")
 g.fighters[1].position=sites[1];mode.tick(2)
 check(mode.scores==[29,1] and mode.hill_owner==-2,"Both teams contest only the active hill")
 g.fighters[1].position=sites[0];g.fighters[2].position=sites[0];mode.tick(26.5)
 check(mode.hill==sites[2] and is_equal_approx(mode.hill_remaining,30),"Empty hill also advances at 30 seconds")
 mode.tick(30)
 check(mode.hill==sites[0] and mode.hill_index==0,"Three distinct sites wrap in a predictable order")
 mode.tick(61)
 check(mode.hill==sites[2] and is_equal_approx(mode.hill_remaining,29) and mode.scores==[29,1],"Long simulation steps cross multiple boundaries without awarding vacant-site points")
 var snapshot=mode.snapshot();var replica=preload("res://deathmatch/modes/match.gd").new();replica.setup(g);replica.receive(snapshot)
 check(replica.hills==sites and replica.hill==sites[2] and replica.hill_index==2 and replica.hill_remaining==29,"Late-join snapshot carries all sites, active position and countdown")
 var legacy=snapshot.duplicate();legacy.erase("hills");legacy.erase("hill_index");legacy.erase("hill_remaining");replica.receive(legacy)
 check(replica.hill==sites[2] and replica.hill_remaining==30,"Old demo snapshots retain their objective without missing-field errors")
 g.intermission=10;var before=mode.hill_remaining;mode.tick(35)
 check(mode.hill_remaining==before,"Intermission freezes hill movement")
 g.intermission=0;mode.reset()
 check(mode.hills.size()>=3 and mode.hill_index==0 and mode.hill_remaining==30,"Round restart restores the first site and full countdown")
 var sounds: Array=[];g.round_clock.round_ended.connect(func():sounds.append(true))
 g._end_round();g._end_round()
 check(sounds.size()==1,"Round end emits exactly one gong even if end is requested twice")
 g._round_end_gong(g.map_epoch-1)
 check(sounds.size()==1,"Stale-map gong events are discarded")
 var stream=load("res://deathmatch/audio/round_gong.wav")
 check(stream is AudioStreamWAV and stream.get_length()>5 and stream.get_length()<6,"Original gong asset loads as a complete non-looping sound")
 await physics_frame
 var original_spawns: Array=g.spawn_points.duplicate()
 g.spawn_points=[original_spawns[0],original_spawns[1]];mode.hills=[original_spawns[0]];mode.hill=original_spawns[0];mode.prepare_hills()
 check(mode.hills.size()>=3,"Two-start custom-map fallback finds a third clear floor")
 g.spawn_points=original_spawns
 g.players.erase(2);g.fighters[2].free();g.fighters.erase(2);g.intermission=0
 g.votes.allowed_modes=["dm","koth"];g.votes.change_mode("dm")
 check(mode.kind=="dm" and not g.current_map.begins_with("koth_"),"Mode vote leaves KOTH-only arena for DM")
 g.votes.change_mode("koth")
 check(mode.kind=="koth" and g.current_map in g.maps_for_mode("koth"),"Mode vote enters a rebuilt KOTH arena")
 FileAccess.open("res://test-results/koth-rotation/rules.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures},"  "))
 g.free();print("KOTH_RULES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
