extends Node
## One process per match: shared map, navigation, team tactics and native bot AI.
const Channel=preload("res://deathmatch/bot_service/channel.gd")
const State=preload("res://deathmatch/bot_service/state.gd")
var game
var socket: StreamPeerTCP
var channel
var key: PackedByteArray
var host:="127.0.0.1"
var port:=7780
var count:=8
var reconnect_at:=0
var connected_at:=0
var latest: Dictionary={}
var needs_world:=true
var last_state:=0
var receipt:=0
var sent_receipt:=0
var sequence:=0
var actions: Array=[]
var accumulator:=0.0
var identity:=""
var ready_at:=0
var ticks:=0
var ai_usec:=0
var maximum_ai_usec:=0
var authenticated:=false
var output:=""
var pending_actions: Dictionary={}
func setup(arena,args: PackedStringArray):
	game=arena;host=game._arg_value(args,"--bot-host",host);port=game._arg_int(args,"--bot-port",port);count=game._arg_int(args,"--bot-count",count)
	output=game._arg_value(args,"--bot-stats","")
	var path: String=game._arg_value(args,"--bot-key-file","")
	if not FileAccess.file_exists(path):push_error("Bot worker key file is missing");get_tree().quit(2);return
	key=FileAccess.get_file_as_bytes(path)
	if key.size()<32 or key.size()>4096 or count<0 or count>32:push_error("Invalid bot worker key/count");get_tree().quit(2);return
	game.set_process(false);game.bot_population.target=0;game.bot_population.count_target=0
func before_tick():pass
func disconnect_worker():
	if channel:channel.close()
	channel=null;authenticated=false;needs_world=true;latest={};receipt=0;sent_receipt=0;actions.clear();pending_actions.clear();reconnect_at=Time.get_ticks_msec()+2000
	if socket:socket.disconnect_from_host()
	socket=null
	print("BOT_WORKER_RECONNECT")
func _process(_delta: float):
	var now:=Time.get_ticks_msec()
	if not socket:
		if now<reconnect_at:return
		socket=StreamPeerTCP.new();connected_at=now
		if socket.connect_to_host(host,port)!=OK:disconnect_worker()
		return
	socket.poll()
	if not channel:
		if socket.get_status()==StreamPeerTCP.STATUS_CONNECTED:
			socket.set_no_delay(true);channel=Channel.new(socket,key)
		elif now-connected_at>5000 or socket.get_status()==StreamPeerTCP.STATUS_ERROR:disconnect_worker()
		return
	for message in channel.poll():
		if not authenticated:
			if message.get("type")!="challenge" or message.get("protocol")!=State.VERSION or not message.get("nonce") is String:channel.close();break
			channel.context=message.nonce
			channel.send({"type":"hello","protocol":State.VERSION,"count":count});authenticated=true;last_state=now
		elif message.get("type")=="state":latest=message;last_state=now;receipt=message.ticket
		else:channel.close()
	if channel.failed or now-last_state>60000:disconnect_worker();return
	if authenticated and receipt>sent_receipt and channel.idle():
		channel.send({"type":"ack","ticket":receipt});sent_receipt=receipt;channel.flush()
func load_world(data: Dictionary) -> bool:
	# Rebuild all bot memories and the query world at every map epoch, including restart.
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	for f in game.fighters.values():f.free()
	game.fighters.clear();game.players.clear();game.active=false;game.current_map=""
	game.armory.select(data.weapons);game.match_mode.configure({"sv_gametype":data.mode});game.selected_map=data.map
	game.start_host("Bot query world",0,20,10,true)
	if not game.active:return false
	identity=State.identity(game)
	if identity!=data.identity:push_error("Bot worker map/navigation assets mismatch");return false
	State.apply(game,data)
	game.bots=load("res://deathmatch/bots.gd").new();game.add_child(game.bots);game.bots.setup(game)
	# Map scripts may have autonomous tick callbacks. Only explicitly mirrored state
	# and the AI are allowed to advance in this process.
	disable_ticks(game)
	needs_world=false;set_process(true);set_physics_process(true);ready_at=Engine.get_physics_frames()+3
	print("BOT_WORKER_MAP map=",data.map," epoch=",data.epoch," bots=",count)
	return true
func disable_ticks(node: Node):
	if node==self:return
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():disable_ticks(child)
func _physics_process(delta: float):
	if not authenticated or latest.is_empty() or not channel or not channel.idle():return
	if Time.get_ticks_msec()-last_state>250:return
	accumulator+=delta
	if accumulator<1.0/30:return
	accumulator=fmod(accumulator,1.0/30)
	var data: Dictionary=latest
	if needs_world or not game.active or game.map_epoch!=data.epoch or game.current_map!=data.map or identity!=data.identity:
		channel.send({"type":"loading"});channel.flush()
		if not load_world(data):get_tree().quit(2)
		return
	if Engine.get_physics_frames()<ready_at:return
	State.apply(game,data)
	for id in pending_actions.keys():
		var pending: Dictionary=pending_actions[id]
		if data.ack.get(id,0)>=pending.seq:pending_actions.erase(id)
		elif data.clock-pending.at>.35:
			# A command can expire during a slow cold navigation query. Reset decisions
			# that optimistically consumed an action so purchases are retried.
			game.bots.brains.erase(id);game.match_mode.defusal.bot_times.erase(id);pending_actions.erase(id)
	game.bots.delegated.clear()
	for id in game.players:
		if id<0 and not data.owners.has(id):game.bots.delegated[id]=true
	actions.clear()
	var began:=Time.get_ticks_usec()
	if not data.paused:game.bots.tick(1.0/30)
	else:
		for id in data.owners:State.neutral(game.players[id])
	var elapsed:=Time.get_ticks_usec()-began
	ticks+=1;ai_usec+=elapsed;maximum_ai_usec=maxi(maximum_ai_usec,elapsed)
	var inputs: Dictionary={}
	for id in game.players:
		if id in data.owners:
			inputs[id]=State.intent(game.players[id]);inputs[id].serial=data.owners[id]
	sequence+=1
	for action in actions:
		var id: int=action.args[0]
		if not pending_actions.has(id):pending_actions[id]={"seq":sequence,"at":data.clock}
	channel.send({"type":"input","epoch":data.epoch,"identity":identity,"ticket":data.ticket,"seq":sequence,"inputs":inputs,"actions":actions})
	if ticks%150==0:
		var stats: Dictionary={"map":data.map,"ticks":ticks,"ai_mean_ms":ai_usec/float(ticks)/1000,"ai_max_ms":maximum_ai_usec/1000.0,"sent_bytes":channel.sent_bytes,"received_bytes":channel.received_bytes}
		print("BOT_WORKER_STATS ",JSON.stringify(stats))
		if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(stats,"  "))
func _exit_tree():
	if channel:channel.close()
