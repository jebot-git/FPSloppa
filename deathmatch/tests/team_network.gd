extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(test: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.025).timeout
	return false
func run():
	var role:=OS.get_cmdline_user_args()[0]
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	if role=="server":
		g.dedicated=true;g.match_mode.configure({"sv_gametype":"ctf"});g.start_host("Teams",28772,10,10,false)
		check(await wait_for(func():return g.players.size()==3),"Two players and observer admitted")
		if g.players.size()==3:
			g.set_physics_process(false)
			var red:=0;var blue:=0
			for id in g.players:
				if g.players[id].team==0:red=id
				elif g.players[id].team==1:blue=id
			check(red!=0 and blue!=0,"Server assigns balanced opposing teams")
			g.match_mode.bases=[Fixture.point(-8,0),Fixture.point(8,0)]
			for i in range(2):g.match_mode.return_flag(i)
			g.fighters[red].position=Fixture.point(8,0);g.fighters[blue].position=Fixture.point(0,12)
			g.match_mode.tick(.1);g._send_snapshot();await create_timer(1).timeout
			g.fighters[red].position=Fixture.point(-8,0);g.match_mode.tick(.1);g._send_snapshot();await create_timer(1).timeout
			g.match_mode.configure({"sv_gametype":"koth","hilllimit":3});g.match_mode.reset();g.match_mode.hill=Fixture.point()
			g.fighters[red].position=Fixture.point();g.match_mode.tick(1);g._send_snapshot();await create_timer(1).timeout
			g.fighters[blue].position=Fixture.point(1,0);g.match_mode.tick(2);g._send_snapshot();await create_timer(1).timeout
			g.match_mode.configure({"sv_gametype":"tdm"});g.match_mode.reset();g.frag_limit=1;g.players[blue].invulnerable=0
			g._damage(blue,red,1000,"test",true);g._send_snapshot();await create_timer(2).timeout
	else:
		g.start_join(role,"127.0.0.1",28772,role=="observer")
		check(await wait_for(func():return g.active and not g.local_state().is_empty()),"Client joins server")
		check(g.local_state().team==(-1 if role=="observer" else g.local_state().team) and (role=="observer" or g.local_state().team in [0,1]),"Replicated team / spectator identity")
		check(await wait_for(func():return g.match_mode.kind=="ctf" and g.match_mode.flags.size()==2 and g.match_mode.flags[1].carrier!=0),"Flag carrier and objective positions replicate")
		check(await wait_for(func():return g.match_mode.scores==[1,0]),"Capture score replicates")
		check(await wait_for(func():return g.match_mode.kind=="koth" and g.match_mode.hill_owner==0 and g.match_mode.scores==[1,0]),"Hill ownership and score replicate")
		check(await wait_for(func():return g.match_mode.hill_owner==-2),"Contested hill replicates")
		check(await wait_for(func():return g.match_mode.kind=="tdm" and g.intermission>0 and g.round_message.begins_with("RED WINS")),"TDM team winner and intermission replicate")
	print("TEAM_NETWORK_RESULT ",role," ",JSON.stringify(failures));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
