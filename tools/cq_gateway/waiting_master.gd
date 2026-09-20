extends SceneTree
## Test-only capacity fixtures: logical residents reserve friendly districts.
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Capacity=preload("res://deathmatch/conquest/capacity.gd")
var game
var failures: Array=[]
func _initialize():run.call_deferred()
func until(predicate: Callable,seconds: float=30) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		await create_timer(.05).timeout
	failures.append("Timed out waiting for fixture state");return false
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var g=game.district_gateway
	if not await until(func():return g.owners.size()==1 and g.owners.values()[0].phase=="active"):finish();return
	var direct:=OS.get_cmdline_user_args().has("--direct-respawn")
	var id: int=g.owners.keys()[0];var serial: int=game.players[id].serial
	if game.players[id].team!=0:failures.append("Fixture expects red initial client");finish();return
	game.match_mode.conquest.rules.owners.fill(1)
	for zone in [1,15]:
		game.match_mode.conquest.rules.owners[zone]=0
		for i in (0 if direct else 16):g.owners[-1000-zone*16-i]={"zone":zone,"generation":1,"phase":"active","ack":true,"last_seq":-1,"baseline":false}
	game.match_mode.conquest.rules.revision+=1
	await create_timer(1).timeout;game._suicide_for(id)
	if direct:
		if not await until(func():return g.owners[id].phase=="active" and g.owners[id].zone==1):finish();return
		if game.players[id].dead or game.players[id].serial<=serial:failures.append("Remote respawn did not restore actor")
		print("CQ_WAITING_MASTER ",JSON.stringify({"failures":failures,"direct_respawn":true,"zone":g.owners[id].zone}))
		await create_timer(8).timeout;finish();return
	if not await until(func():return g.owners[id].phase=="spawn_wait"):finish();return
	var inputs: int=g.stats.inputs
	await create_timer(4).timeout
	if g.stats.inputs!=inputs:failures.append("Waiting client still forwards battle inputs")
	if Capacity.counts(g.owners)[0]!=0:failures.append("Waiting client retains source slot")
	if not g.workers[0].snapshot.actors.is_empty():failures.append("Waiting actor remains in source simulation")
	if game.players[id].team!=0 or not game.players[id].dead:failures.append("Waiting state lost identity or death")
	g.owners.erase(-1000-16)
	if not await until(func():return g.owners[id].phase=="active" and g.owners[id].zone==1):finish();return
	if game.players[id].dead or game.players[id].serial<=serial:failures.append("Deployment did not create a new live spawn")
	if Capacity.counts(g.owners)[1]!=16:failures.append("Deployment did not reserve the freed slot")
	print("CQ_WAITING_MASTER ",JSON.stringify({"failures":failures,"occupancy":Capacity.counts(g.owners),"phase":g.owners[id].phase,"zone":g.owners[id].zone}))
	await create_timer(8).timeout;finish()
func finish():
	if not failures.is_empty():print("CQ_WAITING_MASTER ",JSON.stringify({"failures":failures}))
	game.disconnect_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
