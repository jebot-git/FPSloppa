extends SceneTree
const State=preload("res://tools/district_sim/state.gd")
const Wire=preload("res://tools/district_sim/wire.gd")
const BASE="res://maps/Benchmark1km/"
var game
var zone:=0
var wire
var running:=false
var subscribed:=false
var sequence:=0
var tick:=0
var started:=0
var last_stats:=0
var last_snapshot:=0
var transfers: Dictionary={}
var escrow: Dictionary={}
var ticks: Array=[]
var totals: Dictionary={}
var movement: Dictionary={}
var previous: Dictionary={}
var shots: Dictionary={}
var last_shots: Dictionary={}
var peak_projectiles:=0
var boundary_projectiles:=0
var snapshot_count:=0
var local_ids: Array=[]
var options: Dictionary
class Metrics extends "res://deathmatch/server/log.gd":
	var events: Dictionary={}
	func record(event: String,_data: Dictionary={},_detail: int=1) -> void:events[event]=int(events.get(event,0))+1
var metrics
func _initialize():run.call_deferred()
func run() -> void:
	options=JSON.parse_string(OS.get_cmdline_user_args()[0]);zone=int(options.zone);seed(7129+zone)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.dedicated=true;game.armory.select("quake");game.match_mode.configure({"sv_gametype":"dm"})
	game.map_catalog.append({"id":"prototype_km1","title":"District %d"%zone,"path":BASE+"prototype_km1.bsp","scene":BASE+"zones.scn","sha256":FileAccess.get_sha256(BASE+"prototype_km1.bsp"),"modes":["dm"]})
	game.selected_map="prototype_km1";game.start_host("District",0,100,60,true,"dm","quake");game.dedicated=false;game.frag_limit=100000
	if not game.active:quit(1);return
	# Retain static world geometry/navigation; only this district owns dynamic state.
	game.spawn_points=game.spawn_points.filter(func(p):return State.district(p)==zone);game.spawn_yaws.resize(game.spawn_points.size());game.spawn_yaws.fill(0.0)
	game.pickups=game.pickups.filter(func(p):return State.district(p.position)==zone)
	for id in game.players.keys():game._peer_left(id)
	if is_instance_valid(game.bots):game.bots.free()
	game.bots=preload("res://tools/district_sim/bots.gd").new();game.add_child(game.bots);game.bots.setup(game)
	var deadline:=Time.get_ticks_msec()+30000
	while not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("District navigation timed out");quit(1);return
		await physics_frame
	for index in 4:
		var id: int=-1-zone*4-index;game._add_player(id,"Bot %d"%-id);game.fighters[id].position=game.spawn_points[index];game.fighters[id].velocity=Vector3.ZERO
		game.players[id].owned=[0,2,3,4,5,6,7,8];game.players[id].ammo=[200,100,100,100];game.players[id].weapon=[3,5,7,8][index]
		movement[id]=0.0;previous[id]=game.fighters[id].position;shots[id]=0;last_shots[id]=game.players[id].shots
	var old=game.server_log;metrics=Metrics.new();metrics.game=game;game.add_child(metrics);game.server_log=metrics;old.queue_free()
	var socket:=StreamPeerTCP.new();socket.connect_to_host("127.0.0.1",int(options.port));wire=Wire.new(socket)
	deadline=Time.get_ticks_msec()+10000
	while socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
		socket.poll();await process_frame
		if Time.get_ticks_msec()>deadline:quit(2);return
	wire.send({"kind":"ready","zone":zone,"pid":OS.get_process_id(),"ids":game.players.keys(),"spawns":game.spawn_points.size(),"pickups":game.pickups.size()})
	while true:
		await physics_frame
		for message in wire.poll():command(message)
		if wire.failed or socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:quit(2);return
		if not running:continue
		var began:=Time.get_ticks_usec();game._physics_process(1.0/60);ticks.append((Time.get_ticks_usec()-began)/1000.0);tick+=1;peak_projectiles=maxi(peak_projectiles,game.projectiles.size())
		for id in game.players.keys():
			var actor=game.fighters[id];var target:=State.district(actor.position)
			if previous.has(id) and actor.position.distance_to(previous[id])<2:movement[id]=movement.get(id,0.0)+actor.position.distance_to(previous[id])
			previous[id]=actor.position;shots[id]=shots.get(id,0)+maxi(0,game.players[id].shots-last_shots.get(id,game.players[id].shots));last_shots[id]=game.players[id].shots
			if target!=zone and not game.players[id].dead:offer(id,target)
		# Inter-district ballistics are intentionally blocked in this isolated prototype.
		for id in game.projectiles.keys():
			if State.district(game.projectiles[id].position)!=zone:boundary_projectiles+=1;game._projectile_end(id,game.projectiles[id].position,game.projectiles[id].weapon)
		var now:=Time.get_ticks_msec()
		if subscribed and now-last_snapshot>=50:send_snapshot();last_snapshot=now
		if now-last_stats>=1000:send_stats();last_stats=now
func command(message: Dictionary) -> void:
	match message.kind:
		"start":
			var speed: float=message.speed;Engine.time_scale=speed;Engine.physics_ticks_per_second=int(60*speed);running=true;started=Time.get_ticks_msec()
		"subscribe":subscribed=message.enabled;if subscribed:send_snapshot()
		"walk":
			var id: int=message.id
			if not game.players.has(id):return
			var s: Dictionary=game.players[id];s.dead=false;s.hp=73;s.armor=41;s.ammo=[47,23,11,7];s.owned=[0,2,3,4,5,6,7,8];s.weapon=7;s.invulnerable=game.clock+100;s.cooldown=.23;s.benchmark_stamp=message.stamp
			game.fighters[id].position=message.position;game.fighters[id].velocity=Vector3.ZERO;game.fighters[id].show_alive(true,false);game.bots.crossing[id]=message.target
		"prepare":
			var key: String=message.tx
			if message.get("reject",false):wire.send({"kind":"rejected","tx":key,"zone":zone});return
			if transfers.has(key):wire.send({"kind":"prepared","tx":key,"zone":zone});return
			if game.players.has(message.actor.id):wire.send({"kind":"rejected","tx":key,"zone":zone});return
			transfers[key]={"status":"prepared","actor":message.actor};sequence+=1
			wire.send({"kind":"prepared","tx":key,"zone":zone,"snapshot":State.snapshot(game,zone,sequence)})
		"commit":
			var key: String=message.tx
			if not transfers.has(key):return
			var entry: Dictionary=transfers[key]
			if entry.status=="prepared":
				State.restore(game,entry.actor);last_shots[entry.actor.id]=game.players[entry.actor.id].shots;entry.status="committed"
			var restored:=State.actor(game,entry.actor.id)
			sequence+=1;wire.send({"kind":"committed","tx":key,"zone":zone,"actor":restored,"snapshot":State.snapshot(game,zone,sequence)})
		"release":escrow.erase(message.tx)
		"cancel":
			if transfers.has(message.tx) and transfers[message.tx].status=="prepared":transfers.erase(message.tx)
		"rollback":
			if escrow.has(message.tx):
				var row: Dictionary=escrow[message.tx];var x: float=-500+(zone%4)*250;var z: float=-500+(zone/4)*250
				row.position.x=clampf(row.position.x,x+.5,x+249.5);row.position.z=clampf(row.position.z,z+.5,z+249.5);row.velocity=Vector3.ZERO
				State.restore(game,row);last_shots[row.id]=game.players[row.id].shots;escrow.erase(message.tx)
			wire.send({"kind":"rolled_back","tx":message.tx,"zone":zone})
		"stop":
			running=false;send_stats();wire.send({"kind":"stopped","zone":zone});wire.poll();game.disconnect_game();game.queue_free();quit()
func offer(id: int,target: int) -> void:
	var key: String="%d:%d:%d"%[zone,id,tick];var row:=State.actor(game,id);escrow[key]=row
	# Remove authority before sending. Escrow can restore state until commit.
	game._peer_left(id);game.bots.crossing.erase(id)
	wire.send({"kind":"offer","zone":zone,"target":target,"tx":key,"actor":row})
func send_snapshot() -> void:
	sequence+=1;snapshot_count+=1;wire.send({"kind":"snapshot","zone":zone,"snapshot":State.snapshot(game,zone,sequence)})
func send_stats() -> void:
	var sorted:=ticks.duplicate();sorted.sort();var count:=sorted.size()
	wire.send({"kind":"stats","zone":zone,"clock":tick/60.0,"ticks":tick,"active":game.players.keys(),"escrow":escrow.size(),"p50_ms":sorted[count/2] if count else 0,"p95_ms":sorted[int(count*.95)] if count else 0,"tick_mean_ms":sorted.reduce(func(a,b):return a+b,0.0)/maxi(1,count),"events":metrics.events,"movement":movement,"shots":shots,"snapshots":snapshot_count,"peak_projectiles":peak_projectiles,"boundary_projectiles":boundary_projectiles,"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"wall_seconds":(Time.get_ticks_msec()-started)/1000.0})
