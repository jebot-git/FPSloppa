extends "res://deathmatch/tests/network_runner.gd"
const Codec=preload("res://deathmatch/network/codec.gd")
class Probe extends Node:
	var phase:=""
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func report(tag: String):
		if multiplayer.is_server():seen[tag]=multiplayer.get_remote_sender_id()
	@rpc("authority","call_local","reliable")
	func stage(tag: String):phase=tag
var observer: Probe
func stage(tag: String):observer.stage.rpc(tag)
func run():
	role=OS.get_cmdline_user_args()[0];game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=Probe.new();observer.name="CommandProbe";game.add_child(observer)
	Fixture.box(game,Fixture.ORIGIN-Vector3.UP*.5,Vector3(300,1,300))
	if role=="server":await server_case()
	else:await client_case()
	print("COMMAND_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func everyone(tag: String) -> bool:return ["owner","recipient","enemy"].all(func(person):return observer.seen.has(person+" "+tag))
func server_case():
	game.dedicated=true;game.match_mode.configure({"sv_gametype":"st","capturelimit":100});game.armory.select("tribes");game.lobby.enabled=false;game.selected_map="ctf_raindance";game.start_host("Command network",28987,100,30,false,"st","tribes")
	check(await wait_for(func():return everyone("ready"),30),"All three command-test clients join")
	if not everyone("ready"):return
	var owner: int=observer.seen["owner ready"];var recipient: int=observer.seen["recipient ready"];var enemy: int=observer.seen["enemy ready"]
	for id in [owner,recipient,enemy]:
		game.players[id].team=1 if id==enemy else 0;game.players[id].dead=false;game.players[id].spectator=false;game.fighters[id].position=Fixture.ORIGIN+Vector3(30 if id==enemy else 0,0,30);game.fighters[id].velocity=Vector3.ZERO;game.players[id].serial+=1
	var r=game.match_mode.tribes;var d=r.deployables;r.stations().playable_bounds=AABB(Fixture.ORIGIN-Vector3(150,1,150),Vector3(300,60,300))
	for key in [1,2]:
		var kind: String="camera" if key==1 else "turret";d.rows[key]={"kind":kind,"team":0,"owner":owner,"position":Fixture.ORIGIN+Vector3(key*3,0,0),"normal":Vector3.UP,"yaw":0.0,"hp":d.Data.hp(kind),"energy":float(d.Data.KINDS[kind].reserve),"ready":0.0,"aim":Vector3.FORWARD}
	d.sync();await pause(.4);stage("camera")
	check(await wait_for(func():return r.remote.operated(owner)==1,5),"Camera claimed through remote RPC")
	check(await wait_for(func():return d.rows.get(1,{}).get("aim",Vector3.ZERO).x>.3,3),"Remote camera aim reaches authority")
	check(await wait_for(func():return everyone("camera"),4),"Camera operator and aim replicate to all clients")
	check(r.remote.operated(enemy)<0,"Enemy RPC cannot steal camera")
	stage("turret")
	check(await wait_for(func():return r.remote.operated(owner)==2,4),"Turret transfer uses exclusive control RPC")
	check(await wait_for(func():return d.rows.get(2,{}).get("energy",100.0)<56,3),"Remote fire spends deployed turret capacitor")
	check(await wait_for(func():return everyone("turret"),4),"Turret operator and projectiles replicate")
	stage("follow")
	check(await wait_for(func():return r.commander.commanders.get(recipient)==owner,4),"Recipient selects commander through RPC")
	await pause(.2) # Separate user actions respect the authority's request rate limit.
	stage("order")
	check(await wait_for(func():return r.commander.orders.get(recipient,{}).get("status")=="accepted",5),"Order and recipient acknowledgement round trip")
	check(await wait_for(func():return everyone("order"),4),"Acknowledged order replicates")
	check(not r.commander.orders.has(owner),"Enemy RPC cannot issue order to opposing player")
	check(await wait_for(func():return r.remote.operated(owner)<0,3),"Missing aim updates release remote device")
	stage("done");await pause(.4)
func client_case():
	game.start_join(role,"127.0.0.1",28987)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,30),"Client joins")
	game.set_process(false);game.set_physics_process(false);observer.report.rpc_id(1,role+" ready")
	var sent: Dictionary={};var sequence:=10000;var until:=Time.get_ticks_msec()+60000;var order_seq:=1
	while Time.get_ticks_msec()<until and observer.phase!="done":
		await physics_frame
		var r=game.match_mode.tribes;var s: Dictionary=game.local_state();var id: int=game.multiplayer.get_unique_id();var owner:=0;var recipient:=0
		for peer in game.players:
			if game.players[peer].name=="owner":owner=peer
			if game.players[peer].name=="recipient":recipient=peer
		if s.is_empty() or owner==0 or recipient==0:continue
		sequence+=1
		var input:={"seq":sequence,"map_epoch":game.map_epoch,"input_life":s.serial,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":s.weapon,"slow":false,"respawn":false,"input_blocked":false}
		game._input_packet.rpc_id(1,Codec.pack(input))
		var phase: String=observer.phase
		if role=="owner" and phase in ["camera","turret"]:
			var key: int=1 if phase=="camera" else 2
			if not sent.has(phase+" claim"):sent[phase+" claim"]=true;r.remote_control.rpc_id(1,key,game.map_epoch,s.serial)
			if r.remote.operated(id)==key:r.remote_command.rpc_id(1,key,game.map_epoch,s.serial,Vector3(.5,.2,-1).normalized(),key==2)
		if role=="enemy" and phase=="camera" and not sent.has("bad claim"):sent["bad claim"]=true;r.remote_control.rpc_id(1,1,game.map_epoch,s.serial)
		if role=="recipient" and phase=="follow" and not sent.has("follow"):
			sent.follow=true;r.command_request.rpc_id(1,game.map_epoch,s.serial,order_seq,"follow",[owner],Vector3.ZERO);order_seq+=1
		if phase=="order":
			if role in ["owner","enemy"] and not sent.has("issued"):
				sent.issued=true;r.command_request.rpc_id(1,game.map_epoch,s.serial,order_seq,"move",[recipient if role=="owner" else owner],Fixture.ORIGIN+Vector3(10,0,-10));order_seq+=1
			if role=="recipient" and r.commander.orders.get(id,{}).get("status")=="pending" and not sent.has("accepted"):
				sent.accepted=true;r.command_request.rpc_id(1,game.map_epoch,s.serial,order_seq,"accept",[],Vector3.ZERO);order_seq+=1
		var observations:={"camera":r.remote.operated(owner)==1 and r.deployables.rows.get(1,{}).get("aim",Vector3.ZERO).x>.3,"turret":r.remote.operated(owner)==2 and not game.projectiles.is_empty(),"order":r.commander.orders.get(recipient,{}).get("status")=="accepted"}
		for tag in observations:
			if observations[tag] and not sent.has("observed "+tag):sent["observed "+tag]=true;observer.report.rpc_id(1,role+" "+tag)
	check(observer.phase=="done","Network scenario completes")
	check(["camera","turret","order"].all(func(tag):return sent.has("observed "+tag)),"Client observes devices, firing and accepted order")
