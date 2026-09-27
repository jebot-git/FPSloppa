extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Bot DE",0,20,10,true,"de");g.set_process(false);g.set_physics_process(false)
	var ai=g.bots;var de=g.match_mode.defusal
	var until:=Time.get_ticks_msec()+15000
	while (not ai.ready_to_walk or not ai.navigation.ready()) and Time.get_ticks_msec()<until:await physics_frame
	await physics_frame;await physics_frame
	check(ai.ready_to_walk,"Dust2 navigation finishes baking for practice bots")
	de.tick(0);de.credit(-2,8000);de.credit(-1,8000)
	de.bot_input(-2);de.bot_input(-1)
	check(g.players[-2].owned.has(6) and g.players[-1].owned.has(7),"Bots buy role-appropriate AK and M4")
	check(de.account(-1).kit and g.players[-1].armor==100,"Defender bot buys cutters and armor")
	var cash: int=de.account(-1).cash;de.bot_input(-1);check(de.account(-1).cash==cash,"Bot purchase plan runs once per preparation")
	g.clock=de.phase_end;de.tick(0);de.carrier=-2
	var rows: Array=[];ai.mode_goals(-2,ai.brains[-2],rows)
	check(rows.any(func(row):return row.key=="de:plant"),"Carrier plans a bomb-site objective")
	for i in 2:
		var path: PackedVector3Array=ai.navigation.path(g.fighters[-2].position,de.sites[i],true)
		check(path.size()>1 and path[path.size()-1].distance_to(de.sites[i])<2,"Attacker navigation reaches site "+str(i))
	g.fighters[-2].position=de.sites[de.round_id%2]+Vector3(0,0,.7);g.players[-2].yaw=0.0
	for i in 6:g.clock+=.7;de.bot_input(-2)
	check(de.planted and de.planted_site==1,"Bot enters arming sequence and plants on B floor")
	rows.clear();ai.mode_goals(-1,ai.brains[-1],rows)
	check(rows.any(func(row):return row.key=="de:defuse"),"CT switches to planted-bomb objective")
	g.fighters[-1].position=de.bomb_position+Vector3(0,0,.7)
	for i in 3:g.clock+=.7;de.bot_input(-1)
	check(de.phase=="post" and de.cut_mask==7,"Purchased bot cutters finish defusal through shared authority")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/bots.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_BOT_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
