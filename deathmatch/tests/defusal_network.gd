extends "res://deathmatch/tests/network_runner.gd"
const Codec=preload("res://deathmatch/network/codec.gd")
class Probe extends Node:
	@rpc("authority","call_remote","reliable")
	func face(yaw: float):get_parent().local_yaw=yaw;get_parent().local_pitch=0.0
	var phase:=""
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func report(label: String):
		if multiplayer.is_server():seen[label]=true
	@rpc("authority","call_local","reliable")
	func stage(label: String):phase=label
var observer: Probe
var audio_cues: Array=[]
func stage(value: String):observer.stage.rpc(value)
func position_player(id: int,point: Vector3):
	game.fighters[id].position=point;game.fighters[id].velocity=Vector3.ZERO;game.players[id].yaw=0.0;game.players[id].serial+=1;game.players[id].invulnerable=0
func run():
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.announcer.cue_received.connect(func(cue,target):
		if cue in game.announcer.DE_EVENTS:audio_cues.append([cue,target]))
	observer=Probe.new();observer.name="DefusalProbe";game.add_child(observer)
	if role=="server":await server_case()
	else:await client_case()
	print("DEFUSAL_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func server_case():
	game.dedicated=true;game.bind_address="127.0.0.1";game.selected_map="de_varq_dust2"
	game.match_mode.configure({"sv_gametype":"de","sv_de_prepare":30,"sv_de_winlimit":3});game.votes.enabled=false
	game.start_host("DE network",28982,20,10,false,"de")
	check(await wait_for(func():return observer.seen.has("attacker ready") and observer.seen.has("defender ready"),20),"Both playing clients join")
	if not observer.seen.has("defender ready"):return
	var t: int=game.players.keys().filter(func(id):return game.players[id].name=="attacker")[0]
	var ct: int=game.players.keys().filter(func(id):return game.players[id].name=="defender")[0]
	game.players[t].team=0;game.players[ct].team=1;game._broadcast_roster()
	var de=game.match_mode.defusal;game.match_mode.reset();de.begin_round()
	game.demos.start_record("res://test-results/defusal/network.fpsdemo")
	stage("buy")
	check(await wait_for(func():return de.account(t).cash==150 and de.account(ct).kit,5),"Real clients buy Deagle and cutters through authority")
	check(await wait_for(func():return observer.seen.has("wallet") and observer.seen.has("kit"),3),"Purchases, loadout and wallets replicate to owners")
	check(game.players[t].owned==[0,10] and de.account(ct).cash==600,"No free duplicate purchase and exact CS prices")
	de.phase_end=game.clock+.05;await pause(.15)
	position_player(t,de.sites[0]+Vector3(0,0,.8));game._send_snapshot();stage("plant")
	check(await wait_for(func():return de.planted,8),"Remote arming and site placement plant authoritative bomb")
	stage("planted")
	check(await wait_for(func():return observer.seen.has("viewer ready") and observer.seen.has("late bomb"),15),"Late spectator receives planted bomb, site, fuse and economy")
	game._damage(t,t,1000,"Network death",true)
	await pause(.3);check(de.phase=="live" and game.players[t].dead,"Last attacker death does not end planted round")
	position_player(ct,de.bomb_position+Vector3(0,0,.7));stage("code")
	check(await wait_for(func():return de.phase=="post",7),"Remote eight-digit defusal completes")
	check(de.message=="BOMB DEFUSED" and game.match_mode.scores==[0,1],"Code defusal awards the CT round once")
	check(await wait_for(func():return observer.seen.has("result"),3),"Owner and spectator see replicated result")
	de.phase_end=game.clock;await pause(.15)
	check(de.phase=="prepare" and not game.players[t].dead and de.account(ct).kit,"Next round restores dead player and survivor kit")
	de.phase_end=game.clock;await pause(.1)
	# Updated B cover is angled: derive the facing from actual collision.
	var wall: Dictionary={}
	for x in [-4.0,-2.0,0.0,2.0,4.0]:
		for z in [-4.0,-2.0,0.0,2.0,4.0]:
			var from: Vector3=de.sites[1]+Vector3(x,1.35,z)
			var hit: Dictionary=de.ray_surface(from,from+Vector3.FORWARD*10)
			if hit.is_empty() or absf(hit.normal.y)>.01:continue
			game.fighters[t].position=hit.position+hit.normal*.8-Vector3.UP*1.35
			game.players[t].yaw=atan2(hit.normal.x,hit.normal.z)
			var mount: Dictionary=de.placement(t)
			if not mount.is_empty() and mount.site==1 and mount.pose.basis.z.dot(hit.normal)>.99:wall=hit;break
		if not wall.is_empty():break
	check(not wall.is_empty(),"B site has a supported wall inside the plant zone")
	if wall.is_empty():return
	position_player(t,wall.position+wall.normal*.8-Vector3.UP*1.35)
	game.players[t].yaw=atan2(wall.normal.x,wall.normal.z);observer.face.rpc_id(t,game.players[t].yaw);game._send_snapshot();stage("plant2")
	check(await wait_for(func():return de.planted,8),"Second network round plants on B wall")
	check(de.planted and de.bomb_basis.z.dot(wall.normal)>.99,"Server mounts and replicates outward-facing wall bomb")
	position_player(t,de.sites[1]+Vector3(2.5,0,0))
	position_player(ct,de.bomb_position+wall.normal*.7);stage("cut")
	check(await wait_for(func():return de.phase=="post",6),"Remote purchased cutter interaction completes")
	check(de.cut_mask==7 and game.match_mode.scores==[0,2],"Three wire cuts replicate and score only once")
	check(await wait_for(func():return observer.seen.has("attacker snips") and observer.seen.has("defender snips") and observer.seen.has("viewer snips"),3),"All peers receive exactly three reliable snip events")
	check(audio_cues==[["de_bomb_planted",0],["de_counter_terrorists_win",0],["de_bomb_planted",0],["de_counter_terrorists_win",0]],"Authority emits one global plant and winner cue per round")
	game.demos.stop_record();stage("done");await pause(.3)
func client_case():
	var viewer: bool=role=="viewer"
	game.start_join(role,"127.0.0.1",28982,viewer)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,20),"Client enters supported DE map")
	game.set_physics_process(false);game.set_process(false)
	var recording_path:="res://test-results/defusal/network-"+role+".fpsdemo"
	DirAccess.remove_absolute(recording_path);game.demos.start_record(recording_path)
	var snip_total:=0
	observer.report.rpc_id(1,role+" ready")
	var sent: Dictionary={};var seq:=1000;var next_action:=0.0;var previous:=""
	var deadline:=Time.get_ticks_msec()+50000
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		await physics_frame;game.clock+=1.0/Engine.physics_ticks_per_second
		var de=game.match_mode.defusal;var mine: int=game.multiplayer.get_unique_id();var s: Dictionary=game.local_state()
		if s.is_empty():continue
		if de.cut_mask==7 and not sent.has("cut_seen"):sent["cut_seen"]=Time.get_ticks_msec()
		if de.cut_mask==7 and Time.get_ticks_msec()-sent.get("cut_seen",Time.get_ticks_msec())>400 and not sent.has("snips"):
			game.demos.stop_record()
			var stream:=FileAccess.open(recording_path,FileAccess.READ);stream.get_buffer(8)
			while stream.get_position()+4<stream.get_length():
				var frame: Dictionary=bytes_to_var(stream.get_buffer(stream.get_32()))
				if not game.demos.valid_frame(frame):check(false,"Recorded network frame validates")
				snip_total+=frame.events.filter(func(e):return e[0]=="_de_tool_snip").size()
			stream.close();sent["snips"]=true
			if snip_total==3:observer.report.rpc_id(1,role+" snips")
		if viewer:
			if de.planted and de.accounts.size()>=2 and not sent.has("late bomb"):
				sent["late bomb"]=true;observer.report.rpc_id(1,"late bomb")
			if de.phase=="post" and not sent.has("result"):sent["result"]=true;observer.report.rpc_id(1,"result")
			continue
		seq+=1
		game._input_packet.rpc_id(1,Codec.pack({"seq":seq,"map_epoch":game.map_epoch,"input_life":s.serial,"move":Vector2.ZERO,"yaw":game.local_yaw,"pitch":game.local_pitch,"fire":false,"weapon":s.weapon,"slow":false,"respawn":true}))
		if previous!=observer.phase:previous=observer.phase;next_action=game.clock+.25
		if game.clock<next_action:continue
		next_action=game.clock+.25
		if observer.phase=="buy":
			if role=="attacker" and de.account(mine).cash==800:de.send("buy",10)
			if role=="defender" and not de.account(mine).kit:de.send("buy",102)
			if role=="attacker" and de.account(mine).cash==150 and not sent.has("wallet"):sent["wallet"]=true;observer.report.rpc_id(1,"wallet");de.send("buy",10)
			if role=="defender" and de.account(mine).kit and not sent.has("kit"):sent["kit"]=true;observer.report.rpc_id(1,"kit")
		if role=="attacker" and observer.phase in ["plant","plant2"] and not de.planted and de.carrier==mine:
			if not de.held:game._use_request.rpc_id(1)
			elif de.armed_until>game.clock:game._use_request.rpc_id(1)
			else:de.send("digit",de.arm_code[mini(de.arm_index,3)])
		if role=="defender" and observer.phase=="code" and de.phase=="live" and de.planted:de.send("digit",de.defuse_code[mini(de.defuse_index,7)])
		if role=="defender" and observer.phase=="cut" and de.phase=="live" and de.planted:
			if not de.account(mine).tool:game._use_request.rpc_id(1)
			else:
				for wire in 3:
					if de.cut_mask&(1<<wire)==0:de.send("cut",wire);break
	check(observer.phase=="done","Network scenario completes")
	check(game.armory.effective()=="cs16" and game.match_mode.kind=="de","DE and forced arsenal survive both network rounds")
	check(snip_total==3,"Three remote wire cuts produce three replayable snips")
	check(audio_cues.count(["de_counter_terrorists_win",0])==2,"Both round results reach "+role+" globally, including after death")
	check(audio_cues.count(["de_bomb_planted",0])==(1 if viewer else 2),"Plant confirmation reaches "+role+" without replaying past plants for a late viewer")
	game.demos.stop_record()
	if viewer:check(sent.has("late bomb") and sent.has("result"),"Late viewer observes objective and outcome")
