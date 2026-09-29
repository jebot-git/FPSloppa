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
func everyone(tag: String) -> bool:return ["owner","recipient","enemy"].all(func(person):return observer.seen.has(person+" "+tag))
func run():
	role=OS.get_cmdline_user_args()[0];game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=Probe.new();observer.name="TargetingProbe";game.add_child(observer)
	Fixture.box(game,Fixture.ORIGIN-Vector3.UP*.5,Vector3(500,1,500))
	Fixture.box(game,Fixture.ORIGIN+Vector3(0,12,-100),Vector3(60,24,1))
	if role=="server":await server_case()
	else:await client_case()
	print("TARGETING_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func server_case():
	game.dedicated=true;game.match_mode.configure({"sv_gametype":"st","capturelimit":100});game.armory.select("tribes");game.lobby.enabled=false;game.selected_map="ctf_raindance";game.start_host("Targeting network",28989,100,30,false,"st","tribes")
	check(await wait_for(func():return everyone("ready"),30),"Three targeting-test clients join")
	if not everyone("ready"):return
	var owner: int=observer.seen["owner ready"];var recipient: int=observer.seen["recipient ready"];var enemy: int=observer.seen["enemy ready"];var r=game.match_mode.tribes
	for id in [owner,recipient,enemy]:
		var s: Dictionary=game.players[id];s.team=1 if id==enemy else 0;s.dead=false;s.spectator=false;s.serial+=1;s.yaw=0;s.pitch=0
		r.apply_equipment(id,"heavy",[3,4,7],"energy");s.weapon=11 if id==owner else 7;s.tribes_beacons=3
		game.fighters[id].position=Fixture.ORIGIN+Vector3(0 if id==owner else 15 if id==recipient else -15,0,0 if id==owner else 30);game.fighters[id].velocity=Vector3.ZERO
	game._broadcast_roster()
	r.stations().playable_bounds=AABB(Fixture.ORIGIN-Vector3(240,1,240),Vector3(480,200,480))
	await pause(.5);observer.stage.rpc("laser")
	check(await wait_for(func():return r.targeting.lasers.has(owner),4),"Remote trigger input produces authoritative targeter hit")
	check(await wait_for(func():return everyone("laser"),5),"Laser position, team filtering and artillery overlay replicate")
	check(game.fighters[owner].tribes_state.energy<r.definition(owner).energy,"Network targeter consumes energy")
	observer.stage.rpc("release")
	check(await wait_for(func():return r.targeting.lasers.is_empty(),3),"Remote trigger release removes designation")
	check(await wait_for(func():return everyone("release"),4),"Designation removal reaches every client")
	observer.stage.rpc("beacon")
	check(await wait_for(func():return r.targeting.beacons.size()==1,4),"Sequenced field RPC deploys beacon using authority's aim")
	check(await wait_for(func():return everyone("beacon"),5),"Physical beacon and friendly artillery marker replicate")
	check(game.players[owner].tribes_beacons==2 and game.players[enemy].tribes_beacons==3,"Valid deployment consumes one; stale enemy request consumes none")
	if not r.targeting.beacons.is_empty():r.targeting.damage(r.targeting.beacons.keys()[0],enemy,100)
	observer.stage.rpc("destroyed")
	check(await wait_for(func():return everyone("destroyed"),4),"Destroyed beacon and aiming marks disappear on every client")
	observer.stage.rpc("done");await pause(.3)
func client_case():
	game.start_join(role,"127.0.0.1",28989)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,30),"Client joins")
	game.set_process(false);game.set_physics_process(false)
	if not is_instance_valid(game.camera):game.camera=Camera3D.new();game.add_child(game.camera)
	var view=preload("res://deathmatch/tribes/field_view.gd").new();game.add_child(view);view.setup(game.match_mode.tribes)
	observer.report.rpc_id(1,role+" ready")
	var sent: Dictionary={};var sequence:=10000;var until:=Time.get_ticks_msec()+55000;var beacon_at:=0
	while Time.get_ticks_msec()<until and observer.phase!="done":
		await physics_frame
		var r=game.match_mode.tribes;var s: Dictionary=game.local_state();var owner:=0
		for peer in game.players:
			if game.players[peer].name=="owner":owner=peer
		if s.is_empty() or owner==0:continue
		sequence+=1;var phase: String=observer.phase
		var input:={"seq":sequence,"map_epoch":game.map_epoch,"input_life":s.serial,"move":Vector2.ZERO,"yaw":0.0,"pitch":-.8 if role=="owner" and phase=="beacon" else 0.0,"fire":role=="owner" and phase=="laser","weapon":11 if role=="owner" else 7,"slow":false,"respawn":false,"input_blocked":false}
		game._input_packet.rpc_id(1,Codec.pack(input))
		if phase=="beacon":
			if beacon_at==0:beacon_at=Time.get_ticks_msec()+300
			if Time.get_ticks_msec()>beacon_at and not sent.has("request"):
				sent.request=true
				if role=="owner":r.field_request.rpc_id(1,"beacon",game.map_epoch,s.serial,1)
				elif role=="enemy":r.field_request.rpc_id(1,"beacon",game.map_epoch-1,s.serial,1)
		view.next_update=0;view.update()
		var target: Dictionary=r.targeting.lasers.get(owner,{})
		var laser: bool=not target.is_empty() and target.position.distance_to(Fixture.ORIGIN+Vector3(0,1.45,-99.5))<.08
		var marker: bool=view.markers.has("l%d"%owner)
		var aim: bool=view.markers.has("aiml%d"%owner)
		var beacon: bool=r.targeting.beacons.size()==1 and view.nodes.has("b1")
		var observations:={"laser":laser and (marker and (role=="owner" or aim) if role!="enemy" else view.markers.is_empty() and r.targeting.targets(s.team).is_empty()),"release":sent.has("observed laser") and r.targeting.lasers.is_empty() and view.markers.is_empty(),"beacon":beacon and (view.markers.has("b1") if role!="enemy" else view.markers.is_empty()),"destroyed":sent.has("observed beacon") and r.targeting.beacons.is_empty() and view.nodes.is_empty() and view.markers.is_empty()}
		for tag in observations:
			if phase==tag and observations[tag] and not sent.has("observed "+tag):sent["observed "+tag]=true;observer.report.rpc_id(1,role+" "+tag)
	check(observer.phase=="done","Network scenario completes")
	check(["laser","release","beacon","destroyed"].all(func(tag):return sent.has("observed "+tag)),"Client observes team-correct laser/beacon lifecycle")
