extends "res://deathmatch/tests/network_runner.gd"
const Codec=preload("res://deathmatch/network/codec.gd")
class Probe extends Node:
	var phase:=""
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func report(label: String):
		if multiplayer.is_server():seen[label]=true
	@rpc("authority","call_local","reliable")
	func stage(label: String):phase=label
var observer: Probe
func stage(value: String):observer.stage.rpc(value)
func position_player(id: int,point: Vector3):
	game.fighters[id].position=point;game.fighters[id].velocity=Vector3.ZERO
	game.players[id].yaw=0.0;game.players[id].serial+=1;game.players[id].invulnerable=0
func run():
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=Probe.new();observer.name="RecoveryProbe";game.add_child(observer)
	if role=="server":await server_case()
	else:await client_case()
	FileAccess.open("res://test-results/defusal/bomb-recovery-network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures},"  "))
	print("DE_RECOVERY_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();await process_frame;quit(0 if failures.is_empty() else 1)
func server_case():
	game.dedicated=true;game.bind_address="127.0.0.1";game.selected_map="de_varq_dust2";game.bot_population.count_target=0
	game.match_mode.configure({"sv_gametype":"de","sv_de_prepare":30});game.votes.enabled=false;game.lobby.enabled=false
	game.start_host("DE bomb recovery",28981,20,10,false,"de")
	check(await wait_for(func():return ["carrier","rescuer","defender"].all(func(name):return observer.seen.has(name+" ready")),20),"Three remote players join the recovery test")
	if game.players.size()!=3:return
	var ids: Dictionary={}
	for id in game.players:ids[game.players[id].name]=id;game.players[id].team=1 if game.players[id].name=="defender" else 0
	game._broadcast_roster();game.match_mode.reset();var de=game.match_mode.defusal;de.begin_round()
	de.credit(ids.carrier,10000);de.credit(ids.rescuer,10000);de.buy(ids.carrier,6);de.buy(ids.rescuer,5)
	de.phase_end=game.clock;await pause(.15);de.carrier=ids.carrier;de.held=true
	var point: Vector3=de.sites[0]+Vector3(0,0,.8)
	position_player(ids.carrier,point);position_player(ids.rescuer,point+Vector3(.65,0,0));position_player(ids.defender,point+Vector3(3,0,0))
	# The clients can still have the initial pistol selected during setup. Equip
	# the purchased primaries immediately before damage to exercise overlapping drops.
	check(game.players[ids.carrier].owned.has(6) and game.players[ids.rescuer].owned.has(5),"Both terrorists own purchased primaries")
	game.players[ids.carrier].weapon=6;game.players[ids.rescuer].weapon=5
	game._damage(ids.carrier,ids.defender,1000,"Network recovery death",true)
	check(game.players[ids.carrier].dead and de.carrier==0 and de.nearby_weapon(ids.rescuer)>=0,"Fatal damage drops bomb and overlapping primary weapon")
	game._send_snapshot();stage("dropped")
	check(await wait_for(func():return ["carrier","rescuer","defender"].all(func(name):return observer.seen.has(name+" saw drop")),5),"All remote players receive death and dropped-bomb state")
	position_player(ids.defender,de.bomb_position+Vector3(0,-.2,.35));game._send_snapshot();stage("ct_pickup")
	check(await wait_for(func():return observer.seen.has("ct_pickup attempted"),5),"Remote CT sends Use while within bomb pickup range")
	await pause(.5)
	check(de.carrier==0 and not de.held,"Server rejects remote CT bomb pickup")
	stage("recover")
	check(await wait_for(func():return de.carrier==ids.rescuer,5),"Remote terrorist recovers bomb through Use RPC")
	check(game.players[ids.rescuer].weapon==5 and not game.players[ids.rescuer].owned.has(6),"Overlapping gun does not intercept remote recovery")
	check(await wait_for(func():return ["carrier","rescuer","defender"].all(func(name):return observer.seen.has(name+" saw recovery")),5),"New bomb ownership replicates to teammates, dead carrier and opponent")
	position_player(ids.rescuer,point);game._send_snapshot();stage("plant")
	check(await wait_for(func():return de.planted,8),"Remote survivor arms and plants the recovered bomb")
	check(de.phase=="live" and de.planted_site==0 and de.carrier==0,"Recovery preserves the live round and authoritative plant state")
	de.clear_bomb();de.attacking=1;de.bomb_position=point+Vector3.UP*.2
	position_player(ids.rescuer,point+Vector3(0,0,.35));game._send_snapshot();stage("ct_swapped")
	check(await wait_for(func():return observer.seen.has("ct_swapped attempted"),5),"Former terrorist sends Use as CT after the side swap")
	await pause(.5)
	check(de.carrier==0 and not de.held,"Server rejects remote CT pickup after roles swap")
	stage("done");await pause(.4)
func client_case():
	game.start_join(role,"127.0.0.1",28981)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,20),"Client joins DE")
	game.set_physics_process(false);game.set_process(false);observer.report.rpc_id(1,role+" ready")
	var sent: Dictionary={};var seq:=1000;var next_action:=0.0;var deadline:=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		await physics_frame;game.clock+=1.0/Engine.physics_ticks_per_second
		var de=game.match_mode.defusal;var mine: int=game.multiplayer.get_unique_id();var s: Dictionary=game.local_state()
		if s.is_empty():continue
		seq+=1;game._input_packet.rpc_id(1,Codec.pack({"seq":seq,"map_epoch":game.map_epoch,"input_life":s.serial,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":s.weapon,"slow":false,"respawn":false}))
		if observer.phase=="dropped" and de.carrier==0 and game.players.values().any(func(p):return p.name=="carrier" and p.dead) and not sent.has("drop"):
			sent.drop=true;observer.report.rpc_id(1,role+" saw drop")
		if observer.phase=="recover" and de.carrier!=0 and game.players.get(de.carrier,{}).get("name","")=="rescuer" and not sent.has("recovery"):
			sent.recovery=true;observer.report.rpc_id(1,role+" saw recovery")
		if (observer.phase=="ct_pickup" and role=="defender" or observer.phase=="ct_swapped" and role=="rescuer") and not sent.has(observer.phase):
			game._use_request.rpc_id(1);sent[observer.phase]=true;observer.report.rpc_id(1,observer.phase+" attempted")
		if role!="rescuer" or game.clock<next_action:continue
		next_action=game.clock+.25
		if observer.phase=="recover" and de.carrier==0:game._use_request.rpc_id(1)
		if observer.phase=="plant" and de.carrier==mine and not de.planted:
			if not de.held or de.armed_until>game.clock:game._use_request.rpc_id(1)
			else:de.send("digit",de.arm_code[mini(de.arm_index,3)])
	check(observer.phase=="done" and sent.has("drop") and sent.has("recovery"),"Client observes complete death/recovery/plant scenario")
