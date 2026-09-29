extends "res://deathmatch/tests/network_runner.gd"
const Codec=preload("res://deathmatch/network/codec.gd")
class Probe extends Node:
	var phase:=""
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func report(label: String):
		if multiplayer.is_server():seen[label]=multiplayer.get_remote_sender_id()
	@rpc("authority","call_local","reliable")
	func stage(label: String):phase=label
var observer: Probe
func stage(label: String):observer.stage.rpc(label)
func run():
	role=OS.get_cmdline_user_args()[0];game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	Fixture.box(game,Fixture.ORIGIN-Vector3.UP,Vector3(1000,2,1000))
	observer=Probe.new();observer.name="TransportProbe";game.add_child(observer)
	if role=="server":await server_case()
	else:await client_case()
	print("TRANSPORT_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func everyone(label: String) -> bool:return ["pilot","passenger","viewer"].all(func(person):return observer.seen.has(person+" "+label))
func server_case():
	game.dedicated=true;game.match_mode.configure({"sv_gametype":"st","capturelimit":100});game.armory.select("tribes");game.lobby.enabled=false;game.selected_map="ctf_raindance";game.start_host("Transport network",28986,100,30,false,"st","tribes")
	check(await wait_for(func():return everyone("ready"),30),"Pilot, passenger and spectator join Raindance")
	if not everyone("ready"):return
	var pilot: int=observer.seen["pilot ready"];var passenger: int=observer.seen["passenger ready"]
	var rules=game.match_mode.tribes;var c=rules.vehicles;var pads=rules.stations()
	var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
	for kind in ["lpc","hpc"]:
		c.reset();rules.energy[0]=10000
		for id in [pilot,passenger]:
			game.players[id].team=0;game.players[id].dead=false;game.players[id].input_blocked=false
			game.fighters[id].position=pads.rows[index].position+Vector3((3 if id==passenger else 0),0,0);game.fighters[id].velocity=Vector3.ZERO;game.players[id].serial+=1
		rules.apply_equipment(pilot,"light",[3,2,0],"energy");rules.apply_equipment(passenger,"heavy",[3,2,0],"energy")
		stage(kind+":purchase")
		check(await wait_for(func():return c.rows.size()==1,6),kind+" remote purchase RPC creates transport")
		if c.rows.is_empty():continue
		var key: int=c.rows.keys()[0];await pause(3.2)
		game.fighters[pilot].position=c.seat_position(c.rows[key],0)+Vector3(0,0,1);game.fighters[pilot].velocity=Vector3.ZERO;game.players[pilot].serial+=1
		stage(kind+":board")
		check(await wait_for(func():return c.piloting(pilot),5),kind+" remote Use assigns pilot")
		if not c.piloting(pilot):continue
		game.fighters[passenger].position=c.seat_position(c.rows[key],1)+Vector3(-1,0,0);game.fighters[passenger].velocity=Vector3.ZERO;game.players[passenger].serial+=1
		stage(kind+":passenger")
		check(await wait_for(func():return c.mounted(passenger),5),kind+" heavy passenger boards via remote Use")
		c.rows[key].position=Fixture.ORIGIN+Vector3.UP*3;c.rows[key].velocity=Vector3.ZERO;c.bodies[key].position=c.rows[key].position
		stage(kind+":flight");await pause(2)
		check(c.rows[key].position.y>Fixture.ORIGIN.y+9,kind+" remote VR stick raises occupied transport without jet button")
		var shots: int=game.players[passenger].shots
		stage(kind+":cruise");await pause(5)
		check(c.rows[key].velocity.length()>24,kind+" remote cruise reaches transport speed")
		check(game.players[pilot].vr_device and game.players[pilot].fly==0 and absf(c.rows[key].velocity.y)<.1,kind+" remote centered stick holds altitude")
		check(game.players[passenger].shots>shots and c.rockets.is_empty(),kind+" passenger personal fire works without pilot rockets")
		check(everyone(kind+" occupied"),kind+" all clients receive both occupants")
		check(everyone(kind+" shot"),kind+" all clients observe passenger projectiles")
		stage(kind+":land");await pause(4)
		check(c.rows[key].position.y<Fixture.ORIGIN.y+1 and c.rows[key].position.y>=Fixture.ORIGIN.y,kind+" remote down stick lands safely")
		stage(kind+":eject")
		check(await wait_for(func():return not c.mounted(passenger),4) and c.piloting(pilot),kind+" passenger jump ejects independently")
		check(await wait_for(func():return everyone(kind+" ejected"),4),kind+" independent seat release replicates")
		await pause(3.1)
		game.fighters[passenger].position=c.seat_position(c.rows[key],1)+Vector3(-1,0,0);game.fighters[passenger].velocity=Vector3.ZERO;game.players[passenger].serial+=1
		stage(kind+":reboard")
		check(await wait_for(func():return c.mounted(passenger),5),kind+" remote passenger reboards after cooldown")
		c.damage(key,0,10000,"IMPACT");stage(kind+":destroyed")
		check(await wait_for(func():return everyone(kind+" destroyed"),4),kind+" destruction removes hull and both seats on every client")
	stage("done");await pause(.3)
func client_case():
	game.start_join("Transport "+role,"127.0.0.1",28986,role=="viewer")
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,30),"Client joins transport test")
	game.set_physics_process(false);game.set_process(false);observer.report.rpc_id(1,role+" ready")
	var sent: Dictionary={};var seq:=1000;var previous:="";var elapsed:=0.0;var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		await physics_frame
		var s: Dictionary=game.local_state();var c=game.match_mode.tribes.vehicles;var parts: PackedStringArray=observer.phase.split(":")
		if s.is_empty() or parts.size()!=2:continue
		var kind: String=parts[0];var phase: String=parts[1]
		if observer.phase!=previous:previous=observer.phase;elapsed=0
		elapsed+=1.0/60
		var occupied: bool=c.rows.values().any(func(r):return r.pilot!=0 and r.get("passengers",[]).any(func(id):return id!=0))
		var observations:={"occupied":occupied,"shot":phase=="cruise" and not game.projectiles.is_empty(),"ejected":phase=="eject" and not occupied,"destroyed":phase=="destroyed" and c.rows.is_empty()}
		for label in observations:
			var tag: String=kind+" "+label
			if observations[label] and not sent.has(tag):sent[tag]=true;observer.report.rpc_id(1,role+" "+tag)
		if role=="viewer":continue
		if role=="pilot" and phase=="purchase" and elapsed>.3 and not sent.has(previous):sent[previous]=true;game.match_mode.tribes.buy_vehicle(kind)
		if ((role=="pilot" and phase=="board") or (role=="passenger" and phase in ["passenger","reboard"])) and elapsed>.3 and not sent.has(previous):sent[previous]=true;game._use_request.rpc_id(1)
		seq+=1
		var command:={"seq":seq,"map_epoch":game.map_epoch,"input_life":s.serial,"move":Vector2(0,-1) if role=="pilot" and phase=="cruise" else Vector2.ZERO,"yaw":PI/2 if role=="passenger" else 0.0,"pitch":0.0,"fire":phase=="cruise","weapon":0 if role=="passenger" else s.weapon,"slow":false,"respawn":false,"jump":role=="passenger" and phase=="eject","jetpack":false,"fly":1.0 if phase=="flight" else -1.0 if phase=="land" else 0.0,"input_blocked":false}
		if role=="pilot":command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
		if seq%2==0:game._input_packet.rpc_id(1,Codec.pack(command))
	check(observer.phase=="done","Network scenario completes")
	for kind in ["lpc","hpc"]:check(["occupied","shot","ejected","destroyed"].all(func(tag):return sent.has(kind+" "+tag)),kind+" complete lifecycle observed")
