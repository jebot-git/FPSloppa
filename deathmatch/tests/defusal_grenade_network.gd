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
var tracked:=false
var observer: Probe
func run():
	role=OS.get_cmdline_user_args()[0];tracked=OS.get_cmdline_user_args().has("--tracked")
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=Probe.new();observer.name="UtilityProbe";game.add_child(observer)
	if role=="server":await server_case()
	else:await client_case()
	print("UTILITY_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func server_case():
	game.dedicated=true;game.bind_address="127.0.0.1";game.selected_map="de_inferno_rebuilt"
	game.match_mode.configure({"sv_gametype":"de","sv_de_prepare":30});game.votes.enabled=false
	game.start_host("Utility network",28987,20,10,false,"de")
	check(await wait_for(func():return observer.seen.has("attacker ready") and observer.seen.has("defender ready"),20),"Two clients join new Inferno map")
	if not observer.seen.has("defender ready"):return
	var t: int=game.players.keys().filter(func(id):return game.players[id].name=="attacker")[0]
	var ct: int=game.players.keys().filter(func(id):return game.players[id].name=="defender")[0]
	game.players[t].team=0;game.players[ct].team=1;game._broadcast_roster()
	var de=game.match_mode.defusal;game.match_mode.reset();de.begin_round();de.credit(t,1000)
	var u=de.utility
	check(game.demos.start_record("res://test-results/classic-de/utility-vr-network.fpsdemo" if tracked else "res://test-results/classic-de/utility-network.fpsdemo"),"Fresh utility recording starts")
	game._send_snapshot();await pause(.3)
	observer.stage.rpc("buy")
	check(await wait_for(func():return u.state(t).counts==[1,2,1],5),"Four grenade purchases reach authority with carry limits")
	check(de.account(t).cash==800,"Authority charges $1000 for full utility")
	check(await wait_for(func():return observer.seen.has("inventory"),3),"Inventory replicates to owner")
	de.phase_end=game.clock;await pause(.15);de.carrier=0;de.held=false
	var home: Vector3=de.starts[0][0]
	for id in [t,ct]:
		game.fighters[id].position=home+Vector3(0,0,-4 if id==ct else 0);game.fighters[id].velocity=Vector3.ZERO
		game.players[id].invulnerable=0;game.players[id].armor=0;game.players[id].hp=100
	game._send_snapshot()
	for kind in 3:
		observer.stage.rpc("throw"+str(kind))
		check(await wait_for(func():return not u.flying.is_empty(),5),"Client hold/release throws kind "+str(kind))
		if u.flying.is_empty():return
		if not tracked:check(observer.seen.has("holding"+str(kind)),"Grenade remains held until client release "+str(kind))
		check(game.players[t].shots==0,"Grenade input does not fire the holstered gun "+str(kind))
		check(u.flying.values()[0].owner==t and u.flying.values()[0].kind==kind,"Authority owns projectile kind "+str(kind))
		await pause(.15)
		check(await wait_for(func():return observer.seen.has("projectile"+str(kind)),1),"Projectile replicates to remote observer "+str(kind))
		var id: int=u.flying.keys()[0];u.flying[id].position=game.fighters[ct].position+Vector3(0,.9,1)
		u.detonate(id)
		if kind==0:check(await wait_for(func():return observer.seen.has("damage"),2),"HE damage replicates")
		if kind==1:check(await wait_for(func():return observer.seen.has("flash"),2),"Flash intensity replicates")
		if kind==2:
			u.clouds[id].age=2
			check(await wait_for(func():return observer.seen.has("smoke"),2),"Smoke cloud replicates")
		observer.stage.rpc("between");await pause(.7)
	check(await wait_for(func():return observer.seen.has("viewer ready") and observer.seen.has("late smoke"),15),"Late spectator receives active smoke and spent inventory")
	check(u.state(t).counts==[0,1,0],"Three throws consume exactly three grenades")
	game.demos.stop_record();observer.stage.rpc("done");await pause(.4)
func client_case():
	var viewer: bool=role=="viewer"
	game.start_join(role,"127.0.0.1",28987,viewer)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,20),"Client loads supported DE map")
	game.set_physics_process(false);game.set_process(false);observer.report.rpc_id(1,role+" ready")
	var seq:=1000;var sent: Dictionary={};var previous:="";var started:=0.0;var buy_at:=0.0;var bought:=0
	var deadline:=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		await physics_frame;game.clock+=1.0/Engine.physics_ticks_per_second
		var de=game.match_mode.defusal;var u=de.utility;var mine: int=game.multiplayer.get_unique_id();var s: Dictionary=game.local_state()
		if s.is_empty():continue
		if previous!=observer.phase:previous=observer.phase;started=game.clock
		var elapsed: float=game.clock-started
		if not viewer:
			seq+=1
			var pressed: bool=role=="attacker" and observer.phase.begins_with("throw") and elapsed>.3 and elapsed<1.1
			var command: Dictionary={"seq":seq,"map_epoch":game.map_epoch,"input_life":s.serial,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":pressed and not tracked,"weapon":s.weapon,"slow":false,"respawn":true}
			if tracked and role=="attacker":command.xr=load("res://deathmatch/vr/poses.gd").neutral();command.physical=true
			game._input_packet.rpc_id(1,Codec.pack(command))
			if tracked and role=="attacker" and observer.phase.begins_with("throw"):
				var physical=game.match_mode.fortress.physical
				for action in ["arm","throw"]:
					var label: String=observer.phase+action
					if elapsed>(.4 if action=="arm" else 1.1) and not sent.has(label):
						sent[label]=true;physical.submit(action,command.xr,Vector3(0,2,-3),seq+10000)

		if role=="attacker":
			if not tracked and observer.phase.begins_with("throw") and elapsed>.9 and u.selected(mine)==int(observer.phase.right(1)):
				var label: String="holding"+observer.phase.right(1)
				if not sent.has(label):sent[label]=true;observer.report.rpc_id(1,label)
			if observer.phase=="buy" and game.clock>=buy_at:
				var counts: Array=u.state(mine).counts
				var item: int=110 if counts[0]<1 else 111 if counts[1]<2 else 112 if counts[2]<1 else -1
				if item>=0:de.send("buy",item)
				buy_at=game.clock+.3
			if u.state(mine).counts==[1,2,1] and not sent.has("inventory"):sent.inventory=true;observer.report.rpc_id(1,"inventory")
			if observer.phase.begins_with("throw") and elapsed>.1 and not sent.has(observer.phase):
				sent[observer.phase]=true;de.send("grenade",int(observer.phase.right(1)))
		if role=="defender":
			for p in u.flying.values():
				var label: String="projectile"+str(p.kind)
				if not sent.has(label):sent[label]=true;observer.report.rpc_id(1,label)
			for label in ["damage","flash","smoke"]:
				var seen: bool=(s.hp<100 if label=="damage" else u.flash_amount(mine)>0 if label=="flash" else not u.clouds.is_empty())
				if seen and not sent.has(label):sent[label]=true;observer.report.rpc_id(1,label)
		if viewer and not u.clouds.is_empty() and u.states.values().any(func(a):return a.counts==[0,1,0]) and not sent.has("late smoke"):
			sent["late smoke"]=true;observer.report.rpc_id(1,"late smoke")
	check(observer.phase=="done","Utility network scenario completes")
	check(game.current_map=="de_inferno_rebuilt","Map identity survives snapshots")
