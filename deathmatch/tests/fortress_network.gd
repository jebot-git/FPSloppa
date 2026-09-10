extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(test: Callable,seconds: float=30) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.05).timeout
	return false
func snapshots(seconds: float) -> void:
	for i in range(int(seconds*10)):g._send_snapshot();await create_timer(.1).timeout
func run() -> void:
	var args:=OS.get_cmdline_user_args();var role: String=args[0];var custom: String=args[1];var hash: String=args[2]
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	if role=="server":
		g.dedicated=true;g.match_mode.configure({"sv_gametype":"tf"});g.start_host("Fortress test",28775,5,10,false)
		check(await wait_for(func():return g.players.size()==2 and g.players.values().all(func(s):return s.get("tf_next","") in ["scout","spy"])),"Both clients choose classes through authenticated RPC")
		if g.players.size()==2:
			g.set_physics_process(false)
			var scout:=0;var spy:=0
			for id in g.players:
				if g.players[id].name=="scout":scout=id
				else:spy=id
			g.players[scout].team=0;g.players[spy].team=1
			g._spawn(scout);g._spawn(spy);g._broadcast_roster()
			check(await wait_for(func():return g.avatars.choices.get(scout,{}).get("hash","")==hash,45),"Server validates newly uploaded custom VRM")
			await snapshots(2)
			g.match_mode.fortress.cooldowns[spy]=0
			check(g.match_mode.fortress.action(spy),"Server activates spy cloak")
			check(g.players[spy].tf_disguise.get("hash","")==hash,"Disguise copies another player's custom VRM hash")
			g.match_mode.fortress.buildings[500]={"owner":scout,"team":0,"position":Fixture.point(),"kind":"sentry","hp":150,"ready":0.0,"next":999.0,"expires":999.0}
			await snapshots(15)
			g.match_mode.fortress.revealed(spy);await snapshots(2)
	else:
		if role=="scout":
			var entry: String=g.avatars.library.register_file(custom,true);check(not entry.is_empty(),"Custom VRM accepted under 25 MB")
			g.avatars.library.selected=hash
		g.start_join(role,"127.0.0.1",28775)
		check(await wait_for(func():return g.active and not g.local_state().is_empty()),"Client joins TF")
		g.match_mode.fortress.choose(role)
		check(await wait_for(func():return g.local_state().get("tf_class","")==role),"Respawn class snapshot arrives")
		check(await wait_for(func():return g.match_mode.fortress.effects.values().any(func(e):return e.kind=="spy") and g.match_mode.fortress.buildings.has(500),45),"Cloak and sentry state replicate")
		check(await wait_for(func():return g.avatars.library.entries.has(hash),45),"Peer receives the custom disguise asset")
		if role=="spy":check(g.match_mode.fortress.display_avatar(g.multiplayer.get_unique_id(),"")==hash,"Spy uses downloaded VRM with its own player state")
		check(await wait_for(func():return g.match_mode.fortress.effects.is_empty(),30),"Reveal replicates")
	print("TF_NETWORK_RESULT ",role," ",JSON.stringify(failures));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
