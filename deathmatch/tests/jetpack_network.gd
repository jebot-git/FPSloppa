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
func stage(label: String):observer.stage.rpc(label)
func relocate(id: int):
	var s: Dictionary=game.players[id];var a=game.fighters[id]
	s.serial+=1;s.move=Vector2.ZERO;s.jump=false;s.invulnerable=0
	a.position=Fixture.point();a.velocity=Vector3.ZERO;a.blast_velocity=Vector2.ZERO;a.reset_view();a.reset_jetpack();a.jump_held=false
func run():
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	Fixture.box(game,Fixture.ORIGIN-Vector3.UP*.5,Vector3(200,1,200))
	observer=Probe.new();observer.name="JetpackProbe";game.add_child(observer)
	await physics_frame
	if role=="server":await server_case()
	else:await client_case()
	print("JETPACK_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func server_case():
	game.dedicated=true;game.bind_address="127.0.0.1";game.match_mode.configure({"sv_gametype":"ig","sv_jetpacks":1});game.votes.enabled=false
	game.start_host("Jetpack network",28981,100,10,false,"ig")
	check(await wait_for(func():return observer.seen.has("pilot ready"),20),"Pilot joins enabled Instagib server")
	if not observer.seen.has("pilot ready"):return
	var id: int=game.players.keys().filter(func(key):return not game.players[key].spectator)[0]
	var s: Dictionary=game.players[id];var a=game.fighters[id]
	relocate(id);stage("forge");await pause(.5)
	check(not s.get("jetpack",false) and not a.jetpack_enabled,"Unowned remote jetpack command is denied")
	var p: Dictionary=game.pickups.filter(func(item):return item.kind=="jetpack")[0]
	a.position=p.position;game._collect(id);stage("owned")
	check(await wait_for(func():return observer.seen.has("owned"),4),"Collected jetpack and missing pickup replicate")
	check(is_equal_approx(p.respawn-game.clock,game.pickup_respawn_delay({"kind":"health","item":100})) or p.respawn>game.clock+29,"Network pickup uses megahealth deadline")
	relocate(id);stage("boost")
	check(await wait_for(func():return a.jetpack_state.mode==1,3),"Repeated double-tap event survives dropped press packets")
	check(await wait_for(func():return observer.seen.has("predicted boost") and observer.seen.has("replicated boost"),3),"Owner predicts and reconciles the accepted boost")
	check(await wait_for(func():return observer.seen.has("viewer ready"),10),"Late spectator joins while pickup is unavailable")
	check(await wait_for(func():return observer.seen.has("late ownership"),3),"Late join restores layout, pickup absence and pilot ownership")
	check(await wait_for(func():return a.jetpack_state.mode==0,5),"Remote boost lands through shared collision physics")
	check(a.jetpack_state.cooldown>0,"Landing retains the eight-second activation cooldown")
	relocate(id);stage("hover")
	check(await wait_for(func():return a.jetpack_state.mode==2,3),"Dedicated jetpack button starts remote hover after a lost press packet")
	check(await wait_for(func():return observer.seen.has("replicated hover") and observer.seen.has("viewer flight"),3),"Hover and backpack state reach owner and spectator")
	await pause(2.3);relocate(id);stage("menu")
	await pause(.6);check(a.jetpack_state.activation==0,"Blocked menu input cannot start a jetpack")
	game._damage(id,id,1000,"Network test",true);stage("dead")
	check(await wait_for(func():return observer.seen.has("dead"),3),"Death removes ownership on the client")
	game._spawn(id);stage("respawn")
	check(await wait_for(func():return observer.seen.has("respawn"),3),"Respawn keeps fixed arsenal and requires another pickup")
	game.match_mode.jetpacks=false;game.jetpacks.rebuild();stage("disabled")
	check(await wait_for(func():return observer.seen.has("disabled"),3),"Disabled server option removes client pickup layout")
	game.match_mode.kind="ctf";game.match_mode.jetpacks=true;game.match_mode.reset();stage("ctf")
	check(await wait_for(func():return observer.seen.has("ctf"),3),"Mode transition replicates two CTF base pickups without duplicates")
	stage("done");await pause(.3)
func client_case():
	var viewer:=role=="viewer"
	game.start_join("Jet viewer" if viewer else "Jet pilot","127.0.0.1",28981,viewer)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,20),"Client enters the match")
	game.set_physics_process(false);game.set_process(false)
	observer.report.rpc_id(1,"viewer ready" if viewer else "pilot ready")
	var reported: Dictionary={};var seq:=1000;var last_phase:="";var age:=0.0;var accumulated:=0.0;var max_packet:=0
	var deadline:=Time.get_ticks_msec()+40000
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		await physics_frame
		var dt:=1.0/Engine.physics_ticks_per_second;game.clock+=dt
		var phase:=observer.phase
		if phase!=last_phase:age=0.0;last_phase=phase
		else:age+=dt
		var mine: int=game.multiplayer.get_unique_id();var s: Dictionary=game.local_state()
		if s.is_empty() or not game.fighters.has(mine):continue
		var a=game.fighters[mine]
		var packs: Array=game.pickups.filter(func(item):return item.kind=="jetpack")
		var pilot_ids: Array=game.players.keys().filter(func(key):return not game.players[key].spectator)
		if viewer:
			if not pilot_ids.is_empty():
				var pilot: int=pilot_ids[0]
				if game.players[pilot].get("jetpack",false) and packs.size()==1 and not packs[0].available and not reported.has("late ownership"):
					reported["late ownership"]=true;observer.report.rpc_id(1,"late ownership")
				if game.fighters[pilot].jetpack_state.mode==2 and not reported.has("viewer flight"):
					reported["viewer flight"]=true;observer.report.rpc_id(1,"viewer flight")
			continue
		var jump: bool=phase in ["boost","menu"] and (age<.045 or age>.13 and age<.18)
		var jetpack: bool=phase in ["hover","menu"] and age<.045
		var blocked:=phase=="menu"
		var move:=Vector2(0,-1) if phase=="boost" else Vector2.ZERO
		seq+=1
		var command:={"seq":seq,"map_epoch":game.map_epoch,"move":move,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":s.weapon,"slow":false,"respawn":false,"jump":jump,"jetpack":jetpack,"input_blocked":blocked}
		game.input_delivery.sample(command,s.serial,game.clock)
		accumulated+=dt
		if accumulated>=1.0/30:
			accumulated=0;var wire:=command.duplicate();game.input_delivery.annotate(wire,game.clock)
			if phase=="forge":wire.jetpack=true;wire.jetpack_event=1
			var packet:=Codec.pack(wire);max_packet=maxi(max_packet,packet.size())
			# Deliberately lose raw jump presses in the moving boost case.
			if (phase!="boost" or not jump) and (phase!="hover" or not jetpack):game._input_packet.rpc_id(1,packet)
		if not s.dead and not s.spectator:
			a.configure_jetpack(game.jetpacks.enabled() and s.get("jetpack",false),blocked)
			a.jetpack_requested=game.input_delivery.jet_triggered
			a.simulate(move,0,false,dt,jump)
			a.prediction.remember(seq,a.position,a.velocity,a.collision_height,a.jetpack_state if a.jetpack_enabled else {})
		var facts:={"owned":s.get("jetpack",false) and packs.size()==1 and not packs[0].available,"predicted boost":phase=="boost" and a.jetpack_state.mode==1,"replicated boost":phase=="boost" and game.input_delivery.jet_pending==0 and a.jetpack_state.mode==1 and age>.3,"replicated hover":phase=="hover" and a.jetpack_state.mode==2 and age>.3,"dead":phase=="dead" and s.dead and not s.get("jetpack",false),"respawn":phase=="respawn" and not s.dead and not s.get("jetpack",false) and s.owned==[9],"disabled":phase=="disabled" and packs.is_empty() and not game.match_mode.jetpacks,"ctf":phase=="ctf" and game.match_mode.kind=="ctf" and packs.size()==2}
		for label in facts:
			if facts[label] and not reported.has(label):reported[label]=true;observer.report.rpc_id(1,label)
	check(observer.phase=="done","Network scenario completes")
	if not viewer:
		check(max_packet<=1100,"Jetpack input fits the production packet limit")
		check(audit_facts(reported),"Owner observes pickup, predicted/accepted flight, death and mode lifecycle")
	else:check(reported.has("late ownership") and reported.has("viewer flight"),"Late spectator observes owned backpack and in-flight state")
func audit_facts(reported: Dictionary) -> bool:
	return ["owned","predicted boost","replicated boost","replicated hover","dead","respawn","disabled","ctf"].all(func(key):return reported.has(key))
