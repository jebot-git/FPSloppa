extends Node
const Channel=preload("res://deathmatch/bot_service/channel.gd")
const State=preload("res://deathmatch/bot_service/state.gd")
const Actions=preload("res://deathmatch/bot_service/actions.gd")
const LEASE_MS:=350
var game
var listener:=TCPServer.new()
var key: PackedByteArray
var channel
var authenticated:=false
var deadline:=0
var next_state:=0
var ticket:=0
var acknowledged_ticket:=0
var tickets: Dictionary={}
var leases: Dictionary={}
var last_sequences: Dictionary={}
var previous_count:=-1
var requested:=-1
var limit:=0
var epoch:=-1
var identity:=""
var accepted:=0
var rejected:=0
var disconnects:=0
var snapshots:=0
var action_count:=0
var started:=0
var sent_total:=0
var received_total:=0
func setup(arena,settings: Dictionary) -> bool:
	game=arena;limit=mini(settings.sv_bot_worker_limit,game.max_clients)
	if settings.sv_bot_worker_port==0:set_process(false);return true
	var path: String=settings.sv_bot_worker_key_file
	if not FileAccess.file_exists(path):push_error("Bot worker key file is missing");return false
	key=FileAccess.get_file_as_bytes(path)
	if key.size()<32 or key.size()>4096:push_error("Bot worker key must contain 32–4096 bytes");return false
	var error:=listener.listen(settings.sv_bot_worker_port,settings.sv_bot_worker_bind)
	if error!=OK:push_error("Cannot listen for bot worker: "+error_string(error));return false
	print("BOT_SERVICE_READY port=",settings.sv_bot_worker_port)
	return true
func status() -> Dictionary:
	return {"enabled":listener.is_listening(),"connected":authenticated,"leased":leases.size(),"requested":requested,"accepted":accepted,"rejected":rejected,"actions":action_count,"disconnects":disconnects,"snapshots":snapshots,"sent_bytes":sent_total+(channel.sent_bytes if channel else 0),"received_bytes":received_total+(channel.received_bytes if channel else 0)}
func neutral(id: int):
	if not game.players.has(id):return
	State.neutral(game.players[id]);game.variant_combat.charging.erase(id)
func release():
	for id in leases:
		neutral(id)
	leases.clear();last_sequences.clear();tickets.clear();acknowledged_ticket=ticket
	if is_instance_valid(game.bots):game.bots.delegated.clear();game.bots.brains.clear()
func disconnect_worker():
	if authenticated:
		release()
		disconnects+=1
		if game.bot_population.count_target==requested:game.bot_population.count_target=previous_count
		print("BOT_WORKER_DISCONNECTED fallback=local")
	if channel:
		sent_total+=channel.sent_bytes;received_total+=channel.received_bytes;channel.close()
	channel=null;authenticated=false;requested=-1
func before_tick():
	if not listener.is_listening():return
	var now:=Time.get_ticks_msec()
	if epoch!=game.map_epoch:
		release();epoch=game.map_epoch;identity=State.identity(game)
	for id in leases.keys():
		if game.players.has(id) and leases[id].serial!=game.players[id].serial:
			# Allow one lease for the worker to see a respawn/refit. Neutral input
			# avoids briefly rebuilding the expensive local planner for every life.
			neutral(id);leases[id]={"serial":game.players[id].serial,"at":now}
		elif not game.players.has(id) or now-leases[id].at>LEASE_MS:
			neutral(id)
			leases.erase(id)
			if is_instance_valid(game.bots):game.bots.brains.erase(id)
	if is_instance_valid(game.bots):game.bots.delegated=leases.duplicate()
func _process(_delta: float):
	var now:=Time.get_ticks_msec()
	if listener.is_connection_available():
		var peer:=listener.take_connection()
		if channel:peer.disconnect_from_host()
		else:
			peer.set_no_delay(true);channel=Channel.new(peer,key);deadline=now+5000
			var nonce:=Crypto.new().generate_random_bytes(32).hex_encode()
			channel.send({"type":"challenge","nonce":nonce,"protocol":State.VERSION});channel.context=nonce
	if not channel:return
	for message in channel.poll():
		if not authenticated:
			if message.get("type")!="hello" or message.get("protocol")!=State.VERSION or not message.get("count") is int or message.count<0 or message.count>limit:channel.close();break
			authenticated=true;previous_count=game.bot_population.count_target;requested=message.count
			game.bot_population.count_target=requested;game.bot_population.maintain();deadline=now+60000;started=now
			print("BOT_WORKER_CONNECTED count=",requested)
		else:
			if message.get("type")=="input":consume(message,now)
			elif message.get("type")=="ack":
				if message.get("ticket") is int and message.ticket<=ticket and message.ticket>acknowledged_ticket:
					acknowledged_ticket=message.ticket;deadline=now+5000
			elif message.get("type")=="loading":deadline=now+60000;acknowledged_ticket=ticket
			else:channel.close()
	if channel.failed or now>deadline:disconnect_worker();return
	if not authenticated or not game.active or game.map_loading or now<next_state or not channel.idle() or ticket-acknowledged_ticket>=2:return
	before_tick();next_state=now+50;ticket+=1;tickets[ticket]={"at":now,"owners":{}}
	for id in game.players:
		if id<0 and tickets[ticket].owners.size()<requested:tickets[ticket].owners[id]=game.players[id].serial
	for old in tickets.keys():
		if now-tickets[old].at>LEASE_MS:tickets.erase(old)
	var data:=State.capture(game,ticket);data.identity=identity;data.owners=tickets[ticket].owners;data.ack=last_sequences.duplicate()
	channel.send(data);snapshots+=1
func consume(message: Dictionary,now: int):
	if message.get("ticket") is int and message.ticket<=ticket:acknowledged_ticket=maxi(acknowledged_ticket,message.ticket)
	if message.get("epoch")!=game.map_epoch or message.get("identity")!=identity or not message.get("ticket") is int or not tickets.has(message.ticket) or now-tickets[message.ticket].at>LEASE_MS or not message.get("seq") is int or not message.get("inputs") is Dictionary or message.inputs.size()>limit or not message.get("actions") is Array or message.actions.size()>512:
		rejected+=1;return
	var valid_ids: Dictionary={}
	for id in message.inputs:
		var row=message.inputs[id]
		if not id is int or id>=0 or not tickets[message.ticket].owners.has(id) or not game.players.has(id) or not row is Dictionary or not State.valid_intent(row) or row.serial!=tickets[message.ticket].owners[id] or row.serial!=game.players[id].serial or message.seq<=last_sequences.get(id,-1):rejected+=1;continue
		State.accept(game,id,row);last_sequences[id]=message.seq;leases[id]={"serial":row.serial,"at":now};valid_ids[id]=true;accepted+=1
	for action in message.actions:
		if not action is Dictionary or not action.get("kind") is String or not action.get("args") is Array or not Actions.valid(action.kind,action.args):rejected+=1;continue
		if not valid_ids.has(action.args[0]):rejected+=1;continue
		Actions.execute(game,action.kind,action.args);action_count+=1
	deadline=now+5000
func _exit_tree():
	if channel:channel.close()
	listener.stop()
