extends SceneTree
var g
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(predicate: Callable,timeout: float=20) -> bool:
	var until:=Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await create_timer(.05).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args();var role:=args[args.find("--role")+1]
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	if role=="server":
		g.dedicated=true;g.lobby.enabled=true;g.lobby.seconds=45;g.votes.allowed_modes=["dm","ig"];g.mode_maplists={"dm":["lqdm1","lqdm2"],"ig":["lqdm2"]};g.map_rotation=["lqdm1","lqdm2"]
		g.selected_map="as_hislop";g.match_mode.kind="as"
		g.start_host("Lobby test",28975,100,30,false)
		check(await wait_for(func():return g.players.size()==1),"Initial client joins match")
		g.lobby.begin()
		check(await wait_for(func():return g.players.size()==2 and not g.map_loading),"Existing and late client enter built-in lobby")
		check(await wait_for(func():return g.lobby.confirmed),"Authenticated majority approves next match")
		check(g.fighters.values().all(func(actor):return actor.position.y<8 and absf(actor.position.x)<11.6 and absf(actor.position.z)<11.6),"AS clients spawn inside lobby after network transition")
		check(g.match_mode.fortress.buildings.is_empty() and g.match_mode.fortress.snapshot().is_empty(),"Server lobby carries no sentries")
		check(g.players.values().all(func(s):return s.hp==100),"Clients remain undamaged in lobby")
		check(g.lobby.result()=={"mode":"ig","map":"lqdm2"},"Mode and map tally agrees")
		g.lobby.until=g.clock
		check(await wait_for(func():return g.current_map=="lqdm2" and g.players.size()==2 and not g.map_loading),"Both clients rejoin selected match")
		await create_timer(2).timeout
	else:
		if role=="late":await create_timer(4).timeout
		g.start_join(role,"127.0.0.1",28975)
		check(await wait_for(func():return g.active and not g.local_state().is_empty()),"Client becomes active")
		check(await wait_for(func():return g.lobby.active() and g.active and not g.local_state().is_empty() and not g.lobby.view.is_empty()),"Lobby snapshot and built-in map arrive")
		check(await wait_for(func():return g.players.size()==2),"Both voters are present before proposal")
		await create_timer(.2).timeout
		check(g.match_mode.fortress.buildings.is_empty() and g.match_mode.fortress.visuals.is_empty(),"Client lobby has no stale replicated sentries")
		g.lobby.submit("ig","lqdm2")
		check(await wait_for(func():return not g.lobby.active() and g.current_map=="lqdm2" and g.active and g.match_mode.kind=="ig"),"Client enters voted IG match")
		await create_timer(.5).timeout
	print("LOBBY_NETWORK_RESULT ",role," ",JSON.stringify(failures));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
