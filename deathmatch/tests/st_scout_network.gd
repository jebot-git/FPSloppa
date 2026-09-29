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
func run():
	role=OS.get_cmdline_user_args()[0];game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	Fixture.box(game,Fixture.ORIGIN-Vector3.UP,Vector3(700,2,700))
	observer=Probe.new();observer.name="ScoutProbe";game.add_child(observer)
	if role=="server":await server_case()
	else:await client_case()
	print("SCOUT_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func server_case():
	game.dedicated=true;game.match_mode.configure({"sv_gametype":"st","capturelimit":100});game.armory.select("tribes");game.lobby.enabled=false;game.selected_map="ctf_raindance";game.start_host("Scout network",28985,100,30,false,"st","tribes")
	check(await wait_for(func():return observer.seen.has("pilot ready") and observer.seen.has("viewer ready"),25),"Pilot and observer join Raindance")
	if not observer.seen.has("pilot ready"):return
	var id: int=game.players.keys().filter(func(k):return not game.players[k].spectator)[0]
	var rules=game.match_mode.tribes;var c=rules.vehicles;var pads=rules.stations();var s: Dictionary=game.players[id];var actor=game.fighters[id]
	var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==s.team)[0]
	rules.energy[s.team]=10000;actor.position=pads.rows[index].position;actor.velocity=Vector3.ZERO;s.serial+=1
	stage("purchase")
	check(await wait_for(func():return c.rows.size()==1,6),"Remote purchase RPC creates Scout")
	if c.rows.is_empty():return
	var key: int=c.rows.keys()[0];await pause(3.2)
	actor.position=c.frame(c.rows[key])*Vector3(2.7,0,0);actor.velocity=Vector3.ZERO;s.serial+=1;stage("board")
	check(await wait_for(func():return c.mounted(id),5),"Remote Use boards Scout")
	if not c.mounted(id):return
	c.rows[key].position=Fixture.ORIGIN+Vector3.UP*3;c.rows[key].velocity=Vector3.ZERO;c.bodies[key].position=c.rows[key].position
	stage("flight");await pause(2)
	check(c.rows[key].position.y>Fixture.ORIGIN.y+10,"Remote jet inputs lift authoritative hull")
	stage("cruise");await pause(4)
	check(c.rows[key].velocity.length()>40,"Remote cruise reaches flight speed")
	check(observer.seen.has("pilot mounted") and observer.seen.has("viewer mounted"),"Owner and spectator receive occupied vehicle snapshot")
	check(observer.seen.has("pilot rocket") and observer.seen.has("viewer rocket"),"Owner and spectator receive rocket snapshot")
	stage("blocked")
	# Wait for the blocked input to reach authority; a firing packet already
	# in transit remains valid until then and can land on the rocket cadence.
	var blocked_arrived: bool=await wait_for(func():return s.input_blocked,2)
	var rocket_count: int=c.next_rocket;await pause(.8)
	check(blocked_arrived and c.next_rocket==rocket_count,"Blocked remote controls cannot keep firing")
	stage("eject")
	check(await wait_for(func():return not c.mounted(id),4),"Remote jump ejects through normal input delivery")
	check(await wait_for(func():return observer.seen.has("pilot ejected") and observer.seen.has("viewer ejected"),4),"Seat release replicates to both clients")
	c.damage(key,0,10000,"IMPACT");stage("destroyed")
	check(await wait_for(func():return observer.seen.has("pilot destroyed") and observer.seen.has("viewer destroyed"),4),"Hull destruction replicates without orphan vehicle")
	stage("done");await pause(.3)
func client_case():
	var viewer:=role=="viewer";game.start_join("Scout "+role,"127.0.0.1",28985,viewer)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,25),"Client joins Scout test")
	game.set_physics_process(false);game.set_process(false);observer.report.rpc_id(1,role+" ready")
	var sent: Dictionary={};var seq:=1000;var previous:="";var elapsed:=0.0;var deadline:=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		await physics_frame
		var s: Dictionary=game.local_state();var c=game.match_mode.tribes.vehicles;var phase: String=observer.phase
		if s.is_empty():continue
		if phase!=previous:previous=phase;elapsed=0
		elapsed+=1.0/60
		var occupied: bool=c.rows.values().any(func(r):return r.pilot!=0)
		var observations:={"mounted":occupied,"rocket":not c.rockets.is_empty(),"ejected":phase=="eject" and not occupied,"destroyed":phase=="destroyed" and c.rows.is_empty()}
		for label in observations:
			if observations[label] and not sent.has(label):sent[label]=true;observer.report.rpc_id(1,role+" "+label)
		if viewer:continue
		if phase=="purchase" and elapsed>.25 and not sent.has("purchase"):sent.purchase=true;game.match_mode.tribes.buy_scout()
		if phase=="board" and elapsed>.25 and not sent.has("board"):sent.board=true;game._use_request.rpc_id(1)
		seq+=1
		var command:={"seq":seq,"map_epoch":game.map_epoch,"input_life":s.serial,"move":Vector2(0,-1) if phase=="cruise" else Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":phase in ["cruise","blocked"],"weapon":s.weapon,"slow":false,"respawn":false,"jump":phase=="eject","jetpack":phase in ["flight","blocked"],"input_blocked":phase=="blocked"}
		if seq%2==0:game._input_packet.rpc_id(1,Codec.pack(command))
	check(observer.phase=="done","Network scenario completes")
	check(sent.has("mounted") and sent.has("rocket") and sent.has("ejected") and sent.has("destroyed"),"All vehicle transitions observed")
