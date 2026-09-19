extends "res://deathmatch/tests/network_runner.gd"
const Corridor=preload("res://tools/ba2/gameplay/fixture.gd")
class ClaimBarrier extends Node:
	var ready_peers: Dictionary={}
	var finished_peers: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func ready_for_claim() -> void:
		if multiplayer.is_server():ready_peers[multiplayer.get_remote_sender_id()]=true
	@rpc("any_peer","call_remote","reliable")
	func finished_checks() -> void:
		if multiplayer.is_server():finished_peers[multiplayer.get_remote_sender_id()]=true
var claim_barrier: ClaimBarrier
func signal_seen(label: String) -> bool:return game.feed.any(func(e):return e.text==label)
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	claim_barrier=ClaimBarrier.new();claim_barrier.name="ClaimBarrier";root.add_child(claim_barrier)
	if role=="server":await authority()
	else:await client()
	print("BA2_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
func authority() -> void:
	game.mode_maplists["tb"]=["qsrc_dm1"];game.dedicated=true;game.match_mode.configure({"sv_gametype":"tb"});game.start_host("BA2 network",27896,100,60,false,"tb")
	check(await wait_for(func():return game.players.size()==2,20),"Two clients join real ENet server")
	if game.players.size()!=2:return
	game.set_physics_process(false);Corridor.build(game);game.match_mode.titanball.preparation_left=60.;game.match_mode.titanball.update_gate()
	var w=game.match_mode.fortress.walkers;var r: Dictionary=w.robots.test
	var ids: Array=game.players.keys()
	for i in ids.size():
		var id: int=ids[i];var s: Dictionary=game.players[id]
		s.dead=false;s.spectator=false;s.team=0;s.weapon=6;s.armor=73;s.tier=1;s.input_blocked=false;s.invulnerable=0.;s.serial+=1;s.last_input=game.clock
		game.fighters[id].position=w.transform(r)*w.LADDER+Vector3(.4*i,0,0);game.fighters[id].jump_held=false
	game._send_snapshot();game._announcement.rpc("BA2_CLAIM")
	check(await wait_for(func():return ids.all(func(id):return claim_barrier.ready_peers.has(id)),12),"Both clients finish map setup and pause automatic input before concurrent claims")
	# The deliberately frozen authority clock also freezes the input token bucket.
	# Let normal join traffic replenish after both clients stop automatic commands.
	game.clock+=.25
	for id in ids:game.players[id].last_input=game.clock
	game._send_snapshot();game._announcement.rpc("BA2_SEND_CLAIM")
	check(await wait_for(func():return ids.all(func(id):return game.players[id].last_seq>=100000),8),"Both authenticated jump commands arrive before one server tick")
	game._server_tick(1./60.)
	check(r.pilot in ids and ids.filter(func(id):return w.mounted(id)).size()==1,"One server tick grants exactly one cockpit reservation")
	var pilot: int=r.pilot
	if pilot==0:return
	game._send_snapshot();game._announcement.rpc("BA2_MOUNTED")
	check(await wait_for(func():return ids.all(func(id):return game.players[id].last_seq>=100001),8),"Clients send weapon-switch attempts after boarding")
	game._server_tick(1./60.)
	check(game.players[pilot].weapon==0 and game.players[pilot].armor==200,"Remote weapon switch is rejected and pilot armour stays 200")
	check(game.round_left==600. and r.distance==0.,"Boarded network robot remains parked during preparation without consuming match time")
	game.match_mode.titanball.advance_time(60.)
	for i in 300:game.clock+=1./60.;w.tick(1./60.)
	r.heat=[87.5,100.];r.overheated=[false,true]
	game._send_snapshot();game._announcement.rpc("BA2_MOVED")
	check(r.speed>.799 and game.fighters[pilot].position.distance_to(w.transform(r)*w.SEAT)<.001,"Authority moves robot and carries remote pilot")
	check(r.exit_lock>0 and not w.leave(pilot),"Authority blocks voluntary exit during the ten-second boarding lock")
	for i in 300:game.clock+=1./60.;w.tick(1./60.)
	await pause(.5);game._announcement.rpc("BA2_EXIT")
	check(await wait_for(func():return game.players[pilot].last_seq>=100002,8),"Pilot sends a fresh authenticated jump edge")
	game._server_tick(1./60.)
	check(r.pilot==0 and game.players[pilot].weapon==6 and game.players[pilot].armor==73,"Jump dismount restores original equipment on authority")
	for i in 300:game.clock+=1./60.;w.tick(1./60.)
	for i in 181:game.clock+=1./60.;w.tick(1./60.)
	game._send_snapshot();game._announcement.rpc("BA2_STOPPED");await pause(.5)
	check(w.ladder_visible(r) and game.fighters[pilot].collision_mask==3,"Network dismount ends in deployed ladder and restored collision")
	game.fighters[pilot].position=w.transform(r)*w.LADDER;game.players[pilot].input_blocked=false
	check(w.try_board(pilot,"test"),"Remote pilot can board again after jump dismount")
	for i in 300:game.clock+=1./60.;w.tick(1./60.)
	game.players[pilot].hp=10;game._damage(pilot,pilot,5000,"TEST",true)
	check(game.players[pilot].dead and r.pilot==0 and game.fighters[pilot].position.y<1.,"Remote pilot death forces physical ejection")
	game._send_snapshot();game._announcement.rpc("BA2_EJECTED");await pause(.5)
	var defender: int=ids.filter(func(id):return id!=pilot)[0]
	game.players[defender].team=1;game.players[defender].dead=false;game.players[defender].hp=100;game.players[defender].invulnerable=0.
	game.fighters[defender].position=w.transform(r)*Vector3(.7,0,0)
	game.match_mode.fortress.buildings[98765]={"owner":defender,"team":1,"position":w.transform(r)*Vector3(-.7,0,0),"kind":"sentry","hp":150,"ready":game.clock,"next":game.clock+3,"expires":game.clock+120}
	game._send_snapshot();game._announcement.rpc("BA2_DEPLOYABLE");await pause(.5)
	await physics_frame;await physics_frame
	w.tick(.1)
	check(game.players[defender].dead and r.speed>0,"Authority crushes a defender during unmanned braking")
	check(game.fighters[defender].gibbed,"Authority marks the crushed defender as gibbed")
	check(not game.match_mode.fortress.buildings.has(98765),"Authority stomp destroys Blue deployable")
	game._send_snapshot();game._announcement.rpc("BA2_CRUSHED");await pause(.5)
	var tb=game.match_mode.titanball
	game.round_left=200.;r.distance=90.;tb.observe("test",r)
	check(tb.cleared==1 and game.round_left==380. and game.time_limit==600.,"Authority grants checkpoint time with immutable base timer")
	game._send_snapshot();game._announcement.rpc("BA2_CHECKPOINT");await pause(.5)
	r.distance=350.;r.speed=0.;tb.observe("test",r)
	check(tb.winner==0 and game.intermission>0,"Server ends the round when the payload reaches the base")
	game._send_snapshot();game._announcement.rpc("BA2_DELIVERED");await pause(.5)
	game._announcement.rpc("BA2_DONE");await pause(.5)
	# Snapshots are unreliable in normal play. Keep broadcasting the final state
	# until both clients have checked it; never close the host after one packet.
	for i in 80:
		if ids.all(func(id):return claim_barrier.finished_peers.has(id)):break
		game._send_snapshot();await pause(.1)
	check(ids.all(func(id):return claim_barrier.finished_peers.has(id)),"Both clients finish before authority shuts down")
func client() -> void:
	game.start_join(role,"127.0.0.1",27896)
	check(await wait_for(func():return game.active and not game.local_state().is_empty(),20),"Client joins and receives own state")
	game.set_physics_process(false)
	var w=game.match_mode.fortress.walkers
	check(await wait_for(func():return signal_seen("BA2_CLAIM") and w.robots.has("test"),10),"Opt-in robot route arrives through match snapshot")
	if not w.robots.has("test"):return
	var state: Array=w.snapshot().duplicate(true);Corridor.build(game);w.receive(state)
	check(game.match_mode.titanball.preparing() and game.match_mode.titanball.gate_ref.get_ref().position.y==0.,"Preparation countdown and closed hangar replicate")
	game.match_mode.titanball.advance_time(60.)
	check(game.match_mode.titanball.preparing(),"Client cannot end preparation early")
	check(game.match_mode.fortress.buildings.values().filter(func(b):return b.get("universal",false)).size()==6,"All universal resupply stations replicate")
	check(game.match_mode.titanball.vantages.size()==24,"Authored high-ground positions replicate with the map state")
	var mine: int=game.multiplayer.get_unique_id()
	check(not w.try_board(mine,"test"),"Client cannot grant itself pilot authority")
	claim_barrier.ready_for_claim.rpc_id(1)
	check(await wait_for(func():return signal_seen("BA2_SEND_CLAIM"),8),"Server releases synchronized claim phase after both clients are ready")
	# Commands and snapshots use unreliable channels. Retry the same sequence
	# while the authority remains frozen; duplicate inputs cannot claim twice.
	for attempt in 60:
		if signal_seen("BA2_MOUNTED"):break
		game._input_command.rpc_id(1,{"map_epoch":game.map_epoch,"seq":100000,"move":Vector2.ZERO,"yaw":PI,"pitch":0.,"fire":false,"weapon":game.local_state().weapon,"slow":false,"respawn":false,"jump":true,"input_life":game.local_state().serial,"jump_event":1})
		await pause(.1)
	check(await wait_for(func():return signal_seen("BA2_MOUNTED") and w.robots.test.pilot!=0,8),"Both clients receive exclusive pilot and retracted ladder")
	var pilot: int=w.robots.test.pilot
	check(game.players[pilot].weapon==0 and game.players[pilot].armor==200,"Both clients see the fist lock and 200 pilot armour")
	game._input_command.rpc_id(1,{"map_epoch":game.map_epoch,"seq":100001,"move":Vector2.ZERO,"yaw":PI,"pitch":0.,"fire":false,"weapon":6,"slow":false,"respawn":false,"jump":false})
	check(not w.ladder_visible(w.robots.test) and not w.robots.test.has("hp"),"Replicated cannons are invulnerable and ladder is hidden")
	check(await wait_for(func():return signal_seen("BA2_MOVED") and w.robots.test.speed>.799,8),"Clients receive authoritative cruise motion")
	check(w.robots.test.heat==[87.5,100.] and w.robots.test.overheated==[false,true],"Two distinct shared pair heat meters and lock states replicate")
	check(not game.match_mode.titanball.preparing() and game.match_mode.titanball.gate_ref.get_ref().position.y==15.,"Hangar opens on clients when preparation ends")
	check(await wait_for(func():return signal_seen("BA2_EXIT"),8),"Dismount phase begins")
	if mine==pilot:game._input_command.rpc_id(1,{"map_epoch":game.map_epoch,"seq":100002,"move":Vector2.ZERO,"yaw":PI,"pitch":0.,"fire":false,"weapon":6,"slow":false,"respawn":false,"jump":true,"input_life":game.local_state().serial,"jump_event":1})
	check(await wait_for(func():return signal_seen("BA2_STOPPED") and w.ladder_visible(w.robots.test),8),"Both replicas settle unmanned with deployed ladder")
	check(game.players[pilot].weapon==6 and game.players[pilot].armor==73,"Both clients receive equipment restored after jump exit")
	check(await wait_for(func():return signal_seen("BA2_EJECTED") and game.players[pilot].dead and w.robots.test.pilot==0,8),"Death and released cockpit replicate to both clients")
	check(game.fighters[pilot].position.y<1. and game.players[pilot].weapon==6 and game.players[pilot].armor==73,"Ejected position and restored equipment replicate")
	var defender: int=game.players.keys().filter(func(id):return id!=pilot)[0]
	check(await wait_for(func():return signal_seen("BA2_DEPLOYABLE") and game.match_mode.fortress.buildings.has(98765),8),"Blue deployable exists on clients before the stomp")
	check(await wait_for(func():return signal_seen("BA2_CRUSHED") and game.players[defender].dead,8),"Crush death and defender state replicate to both clients")
	check(game.fighters[defender].gibbed,"Crush gib state reaches both clients")
	check(not game.match_mode.fortress.buildings.has(98765),"Crushed deployable disappears on both clients")
	check(await wait_for(func():return signal_seen("BA2_CHECKPOINT") and game.match_mode.titanball.cleared==1,8),"Checkpoint completion replicates to both clients")
	check(game.round_left==380. and game.time_limit==600.,"Clients receive the extension and fixed ten-minute base")
	var tb=game.match_mode.titanball
	check(tb.spawns(0)==tb.attacker_spawns[1] and tb.defender_spawns.size()==4,"Forward attacker spawn group and defender base replicate")
	var forged: Dictionary=w.robots.test.duplicate();forged.distance=240.;tb.observe("test",forged)
	check(tb.cleared==1 and game.round_left==380.,"Client cannot grant itself the second extension")
	check(await wait_for(func():return signal_seen("BA2_DELIVERED") and tb.winner==0 and game.intermission>0,8),"Attacker victory and round ending replicate to both clients")
	check(game.round_message.contains("ATTACKERS WIN"),"Clients display payload winner instead of frag score")
	check(await wait_for(func():return signal_seen("BA2_DONE"),8),"Network scenario completes")
	claim_barrier.finished_checks.rpc_id(1);await pause(.2)
