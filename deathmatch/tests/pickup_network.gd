extends "res://deathmatch/tests/network_runner.gd"
class PickupProbe extends Node:
	var phase:=""
	var index:=-1
	var available:=false
	var seen: Dictionary={}
	@rpc("authority","call_local","reliable")
	func stage(label: String,item_index: int,value: bool) -> void:
		phase=label;index=item_index;available=value
	@rpc("any_peer","call_remote","reliable")
	func acknowledge(label: String) -> void:
		if multiplayer.is_server():
			if not seen.has(label):seen[label]={}
			seen[label][multiplayer.get_remote_sender_id()]=true
var observer: PickupProbe
func publish(label: String,index: int,available: bool) -> void:
	observer.stage.rpc(label,index,available)
	var deadline:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline and observer.seen.get(label,{}).size()<2:
		game._send_snapshot();await pause(.05)
	check(observer.seen.get(label,{}).size()==2,label+": both clients confirm pickup availability and model visibility")
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=PickupProbe.new();observer.name="PickupProbe";game.add_child(observer)
	game.selected_map="as_frigate"
	if role=="server":
		game.dedicated=true;game.match_mode.configure({"sv_gametype":"as"});game.start_host("AS pickups",28977,20,10,false,"as")
		check(await wait_for(func():return game.players.size()==2 and observer.seen.get("ready",{}).size()==2,30),"Both clients join Assault and prepare pickup models")
		game.set_physics_process(false)
		if game.players.size()==2:
			var collector: int=game.players.keys()[0]
			for kind in ["weapon","ammo","health","armor"]:
				var p: Dictionary=game.pickups.filter(func(row):return row.kind==kind)[0]
				var index: int=game.pickups.find(p)
				for other in game.pickups:other.available=false;other.respawn=INF
				p.available=true;p.respawn=0
				var state: Dictionary=game.players[collector]
				state.hp=1;state.armor=0;state.ammo=[0,0,0,0];state.owned=[2];state.dead=false;state.spectator=false
				game.fighters[collector].position=p.position
				await publish(kind+" available",index,true)
				game._collect(collector)
				await publish(kind+" collected",index,false)
				game.clock=p.respawn-.01;game._respawn_pickups()
				await publish(kind+" before deadline",index,false)
				game.clock=p.respawn;game._respawn_pickups()
				await publish(kind+" respawned",index,true)
				state.hp=1;state.armor=0;state.ammo=[0,0,0,0]
				game._collect(collector)
				await publish(kind+" collected again",index,false)
			game.match_mode.assault.next_leg()
			await publish("role swap",0,true)
		observer.stage.rpc("done",0,true);await pause(.2)
	else:
		game.start_join(role,"127.0.0.1",28977)
		check(await wait_for(func():return game.active and game.match_mode.kind=="as" and game.local_state().get("serial",0)>0,30),"Client enters Assault")
		for p in game.pickups:
			p.node=Node3D.new();game.get_node("Map").add_child(p.node)
		observer.acknowledge.rpc_id(1,"ready")
		var handled:=""
		var deadline:=Time.get_ticks_msec()+35000
		while Time.get_ticks_msec()<deadline and observer.phase!="done":
			await pause(.01)
			if observer.phase.is_empty() or observer.phase==handled or observer.phase=="done":continue
			var label:=observer.phase
			check(await wait_for(func():return game.pickups[observer.index].available==observer.available and game.pickups[observer.index].node.visible==observer.available,4),label+": authoritative availability matches model visibility")
			observer.acknowledge.rpc_id(1,label);handled=label
		check(observer.phase=="done","Pickup replication scenario completes")
	print("PICKUP_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
