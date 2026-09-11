extends SceneTree
var g
var failures: Array=[]
func _initialize():call_deferred('run')
func check(ok: bool,label: String) -> void:
	print('PASS ' if ok else 'FAIL ',label)
	if not ok:failures.append(label)
func wait_for(condition: Callable) -> bool:
	var until:=Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<until:
		if condition.call():return true
		await create_timer(.02).timeout
	return false
func run():
	var server:=OS.get_cmdline_user_args().has('server')
	g=load('res://deathmatch/arena.tscn').instantiate();root.add_child(g)
	var heard: Array=[]
	g.announcer.cue_received.connect(func(cue,_target):heard.append(cue))
	if server:
		g.dedicated=true;g.announcer.policy(false);g.start_host('Announcer test',28917,20,10,false)
		check(await wait_for(func():return g.players.size()==1),'Announcer policy client joins real ENet server')
		g.announcer.receive.rpc('first_blood',0)
		await create_timer(.5).timeout
		g.announcer.policy(true);g.announcer.policy.rpc(true);g.announcer.receive.rpc('double_kill',0)
		await create_timer(.7).timeout
		g.announcer.policy(false);g.announcer.policy.rpc(false)
		check(g._rotate_map('lqdm2'),'Disabled announcer server rotates maps')
		check(await wait_for(func():return g.players.size()==1),'Client finishes joining rotated map')
		g.announcer.receive.rpc('rampage',0)
		await create_timer(1).timeout
		check(g.announcer.streams.is_empty() and g.announcer.player==null,'Dedicated server remains free of announcer audio allocation')
	else:
		g.start_join('Policy listener','127.0.0.1',28917)
		check(await wait_for(func():return g.active),'Client joins with initial disabled policy')
		await create_timer(.1).timeout
		check(not g.announcer.allowed and heard.is_empty(),'Disabled policy suppresses initial announcements on client')
		check(await wait_for(func():return heard.has('double_kill')),'Reliable authorized announcement reaches remote client')
		check(await wait_for(func():return g.active and g.current_map=='lqdm2'),'Client enters rotated map')
		await create_timer(.3).timeout
		check(not g.announcer.allowed and heard==['double_kill'],'Disabled policy survives rotation and rejects subsequent announcements')
	print('ANNOUNCER_NETWORK_RESULT ',JSON.stringify(failures))
	g.disconnect_game();g.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
