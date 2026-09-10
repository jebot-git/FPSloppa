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
		g.dedicated=true;g.match_mode.configure({"sv_gametype":"ft"});g.start_host("Special modes",28773,10,10,false)
		check(await wait_for(func():return g.players.size()==2),"Both clients admitted")
		if g.players.size()==2:
			g.set_physics_process(false)
			var red: int=g.players.keys()[0];var blue: int=g.players.keys()[1]
			g.players[red].team=0;g.players[blue].team=1
			g.players[blue].invulnerable=0;g._damage(blue,red,1000,"SHOTGUN");g.match_mode.tick(.01);g._send_snapshot();await create_timer(1.5).timeout
			check(g.match_mode.special.frozen.has(blue),"Network inputs cannot thaw frozen player")
			for mode in ["cc","ig"]:
				g.match_mode.configure({"sv_gametype":mode});g.match_mode.reset()
				for id in g.players:g.players[id].team=-1;g._spawn(id)
				g._send_snapshot();await create_timer(1.5).timeout
	else:
		g.start_join(role,"127.0.0.1",28773)
		check(await wait_for(func():return g.active and not g.local_state().is_empty()),"Client joins")
		check(await wait_for(func():return g.match_mode.kind=="ft" and g.match_mode.special.frozen.size()==1 and g.match_mode.scores==[1,0]),"Freeze, round score and pause replicate")
		check(g.match_mode.special.blocked(g.multiplayer.get_unique_id()),"Client observes freeze-round movement block")
		check(await wait_for(func():return g.match_mode.kind=="cc" and g.local_state().owned==[1]),"Chainsaw-only loadout replicates")
		check(await wait_for(func():return g.match_mode.kind=="ig" and g.local_state().owned==[9]),"Railgun-only loadout replicates")
	print("SPECIAL_NETWORK_RESULT ",role," ",JSON.stringify(failures));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
