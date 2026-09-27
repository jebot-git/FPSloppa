extends "res://deathmatch/tests/network_runner.gd"
const Reload=preload("res://deathmatch/counterstrike/reload_state.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
class Observer extends Node:
	var phase:=""
	var expected: Array=[]
	var seen: Dictionary={}
	var request_reload:=false
	@rpc("authority","call_local","reliable")
	func stage(label: String,row: Array):phase=label;expected=row
	@rpc("authority","call_remote","reliable")
	func reload_input():request_reload=true
	@rpc("any_peer","call_remote","reliable")
	func acknowledge(label: String):
		if multiplayer.is_server():seen[label]=true
var observer: Observer
var sequence:=1000
var pose: Dictionary
var packets_fit:=true
func publish(label: String,expected: Array):
	observer.stage.rpc(label,expected)
	var deadline:=Time.get_ticks_msec()+6000
	while Time.get_ticks_msec()<deadline and not observer.seen.has(label):
		if expected.size() in [5,8]:
			game.clock+=.05
			for id in game.players:
				var s: Dictionary=game.players[id];s.cooldown=maxf(0,s.cooldown-.05)
				if not s.fire:s.held=false
				game.variant_combat.cs.tick_input(id,.05)
		game._send_snapshot();await pause(.05)
	check(observer.seen.has(label),"Client acknowledges "+label)
func motion_step(w: int,at: Vector3,grip: bool=false,eject: bool=false,fire: bool=false):
	var row: Array=game.variant_combat.cs.status(game.multiplayer.get_unique_id())
	var carry: bool=row.size()==Reload.ROW_SIZE and row[8] in [1,Reload.REMOVED_MAG]
	pose.left=Transform3D(preload("res://deathmatch/counterstrike/models.gd").ammo_basis(w).inverse() if carry else Basis.IDENTITY,at);pose.offhand_weapon=pose.left
	sequence+=1
	var command:={"seq":sequence,"map_epoch":game.map_epoch,"input_life":game.local_state().serial,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":fire,"reload":eject,"reload_grip":grip,"weapon":w,"slow":false,"respawn":false,"xr":pose,"clips":{w:999},"chambered":true}
	var packet:=Codec.pack(command);packets_fit=packets_fit and packet.size()<=1100
	game._input_packet.rpc_id(1,packet);await pause(.06)
func hand_step(w: int,at: Vector3,grip: bool=false,eject: bool=false,fire: bool=false,seconds: float=.12):
	for i in maxi(2,ceili(seconds/.05)):
		await motion_step(w,at,grip,eject,fire)
func gesture(label: String,w: int):
	var bag:=Reload.pouch(pose).origin;var model:=Reload.model_pose(pose,w);var rack: Vector3=model*Reload.RACK_POINTS[w]
	if label=="M4 grip magazine":
		await hand_step(w,model*Reload.MAG_POINTS[w]);await hand_step(w,model*Reload.MAG_POINTS[w],true)
	elif label=="M4 pull magazine":
		await hand_step(w,model*(Reload.MAG_POINTS[w]+Vector3.DOWN*.14),true)
	elif label=="M4 release magazine":
		await hand_step(w,model*(Reload.MAG_POINTS[w]+Vector3.DOWN*.14))
	elif label=="M4 reinsert magazine":
		await hand_step(w,model*Reload.MAG_POINTS[w],true)
	elif label=="AK bump":
		await hand_step(w,model*(Reload.AK_RELEASE+Vector3.BACK*.23),true)
		for offset in [.16,.09,.02]:await motion_step(w,model*(Reload.AK_RELEASE+Vector3.BACK*offset),true)
	elif label=="MP5 notch":
		await hand_step(w,rack);await hand_step(w,rack,true)
		await hand_step(w,model*(Reload.RACK_POINTS[w]+Vector3.BACK*.065),true,false,false,.2)
		await hand_step(w,model*(Reload.RACK_POINTS[w]+Vector3.BACK*.065+Vector3.UP*.055),true)
		await hand_step(w,model*(Reload.RACK_POINTS[w]+Vector3.BACK*.065+Vector3.UP*.055))
	elif label=="MP5 slap":
		var latch: Vector3=Reload.RACK_POINTS[w]+Vector3.BACK*.065+Vector3.UP*.055
		await hand_step(w,model*(latch+Vector3.UP*.19))
		for offset in [.12,.05,-.02]:await motion_step(w,model*(latch+Vector3.UP*offset))
	elif label.begins_with("AWP bolt"):
		var up: Vector3=Reload.BOLT_PIVOT+Basis(Vector3.BACK,PI/3)*(Reload.RACK_POINTS[9]-Reload.BOLT_PIVOT)
		if label.ends_with("raise"):
			await hand_step(w,rack);await hand_step(w,rack,true);await hand_step(w,model*up,true,false,false,.2)
		elif label.ends_with("pull"):await hand_step(w,model*(up+Vector3.BACK*.10),true,false,false,.2)
		elif label.ends_with("close"):await hand_step(w,model*up,true,false,false,.2)
		elif label.ends_with("lock"):await hand_step(w,rack,true,false,false,.2);await hand_step(w,rack)
	elif label=="USP side flick":
		for i in 3:
			pose.weapon.origin.x+=.08;pose.right=pose.weapon;await motion_step(w,bag)
	elif label=="M3 swing":
		await hand_step(w,rack);await hand_step(w,rack,true)
		pose.pump=true;var hand:=Transform3D(Basis.IDENTITY,rack)
		for direction in [1,-1]:
			for i in 3:
				hand.origin.z+=direction*.085
				var row: Array=game.variant_combat.cs.status(game.multiplayer.get_unique_id())
				pose.weapon=preload("res://deathmatch/vr/pump_hold.gd").weapon(hand,Basis.IDENTITY,float(row[6])/100)
				await motion_step(w,hand.origin,true)
		await hand_step(w,hand.origin,true)
	elif label=="M3 take back":
		pose.erase("pump");pose.weapon=pose.right;await hand_step(w,bag,true,true);await hand_step(w,bag)
	elif label.ends_with("belt"):
		await hand_step(w,model*Reload.BELT_PICKUP);await hand_step(w,model*Reload.BELT_PICKUP,true)
		await hand_step(w,model*Reload.BELT_TRAY,true,false,false,.2);await hand_step(w,model*Reload.BELT_TRAY)
	elif label.ends_with("eject"):
		await hand_step(w,bag);await hand_step(w,bag,false,true);await hand_step(w,bag)
	elif label.ends_with("draw"):await hand_step(w,bag);await hand_step(w,bag,true)
	elif label.ends_with("insert"):
		await hand_step(w,model*Reload.MAG_POINTS[w],true,false,false,.2);await hand_step(w,model*Reload.MAG_POINTS[w])
	elif label.ends_with("rack") or label.ends_with("pump"):
		await hand_step(w,rack);await hand_step(w,rack,true)
		await hand_step(w,model*(Reload.RACK_POINTS[w]+Vector3.BACK*(.105 if w==3 else .065)),true,false,false,.2)
		if w==3:await hand_step(w,rack,true)
		await hand_step(w,rack)
	elif label.ends_with("open") or label.ends_with("close"):
		var amount:=0.0 if label.ends_with("open") else 1.0
		await hand_step(w,model*Reload.cover_point(amount));await hand_step(w,model*Reload.cover_point(amount),true)
		await hand_step(w,model*Reload.cover_point(1-amount),true,false,false,.2);await hand_step(w,model*Reload.cover_point(1-amount))
	elif label.ends_with("shot"):
		await hand_step(w,bag,false,false,true);await hand_step(w,bag)
	else:await hand_step(w,bag)
func run():
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	observer=Observer.new();observer.name="CS16Observer";game.add_child(observer)
	await physics_frame
	if role=="server":
		game.dedicated=true;game.bind_address="127.0.0.1";game.armory.select("cs16");game.start_host("CS16 network",28978,100,10,false,"dm","cs16")
		check(await wait_for(func():return game.players.size()==1 and observer.seen.has("ready"),20),"Remote client joins CS16 server")
		game.set_physics_process(false);game.set_process(false)
		if game.players.size()==1:
			var id: int=game.players.keys()[0];var s: Dictionary=game.players[id];var cs=game.variant_combat.cs
			s.merge({"weapon":2,"owned":range(12),"ammo":[60,64,300,40],"dead":false,"spectator":false,"hp":2000,"invulnerable":0,"cooldown":0.0,"input_blocked":false,"reload":false,"fire":false,"held":false,"alt_fire":false},true)
			cs.state(id).clips[2]=5;await publish("partial magazine",[2,5,false,false])
			observer.reload_input.rpc()
			check(await wait_for(func():return s.get("reload",false),6),"Reload control travels from client to authority")
			cs.tick_input(id,.01)
			check(cs.state(id).clips[2]==5,"Client cannot forge clip count through input")
			await publish("reload started",[2,5,true,false])
			game.clock+=2.8;s.last_input=game.clock;s.reload=false;cs.tick_input(id,.01)
			await publish("reload completed",[2,12,false,false])
			s.weapon=11;s.ammo[0]=100;await publish("P90 slot 11",[11,50,false,false])
			s.weapon=7;s.cooldown=0;s.alt_fire=true;cs.tick_input(id,.01)
			await publish("M4 suppressor",[7,30,false,true])
			var path:="user://cs16-network-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())+".fpsdemo"
			var recording: bool=game.demos.start_record(path)
			check(recording,"CS16 demo recording starts")
			if recording:
				game._send_snapshot();game.demos.stop_record()
				game.demos.input=FileAccess.open(path,FileAccess.READ);game.demos.input.seek(game.demos.MAGIC.length())
				var frame: Dictionary=game.demos.read_frame()
				check(not frame.is_empty() and frame.snapshot[10].weapon_rules=="cs16" and frame.snapshot[10].cs16.has(id) and frame.snapshot[10].cs16[id][4],"Demo retains CS rules, magazine and attachment state")
				game.demos.input.close();game.demos.input=null
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			s.serial+=1;s.weapon=2;s.ammo[0]=60;s.alt_fire=false;await publish("new life",[2,12,false,false])
			s.vr_device=true;s.cooldown=0;s.serial+=1
			await publish("VR ready",[2,12,7,0,0])
			await publish("VR eject",[2,1,5,0,0]);await publish("VR draw",[2,1,5,0,1])
			await publish("VR insert",[2,12,7,0,0]);await publish("VR rack",[2,12,7,0,0])
			check(s.ammo[0]==60,"Remote magazine reload does not create or spend rounds")
			s.serial+=1;s.weapon=3;s.cooldown=0
			await publish("M3 ready",[3,8,7,0,0]);await publish("M3 shot",[3,7,3,0,0]);await publish("M3 pump",[3,7,7,0,0])
			s.serial+=1;s.weapon=8;s.cooldown=0
			await publish("M249 ready",[8,100,135,0,0]);await publish("M249 open",[8,100,135,100,0])
			await publish("M249 eject",[8,0,1,100,0]);await publish("M249 draw",[8,0,1,100,1])
			await publish("M249 insert",[8,100,3,100,0]);await publish("M249 belt",[8,100,131,100,0]);await publish("M249 close",[8,100,131,0,0]);await publish("M249 rack",[8,100,135,0,0])
			check(s.ammo[2]==300,"Remote ammo-box reload conserves the shared reserve")
			s.serial+=1;s.weapon=6;s.cooldown=0;cs.state(id).clips[6]=10
			await publish("AK ready",[6,10,7,0,0]);await publish("AK draw",[6,10,7,0,1]);await publish("AK bump",[6,1,5,0,1]);await publish("AK insert",[6,30,7,0,0]);await publish("AK rack",[6,30,7,0,0])
			s.serial+=1;s.weapon=5;s.cooldown=0
			await publish("MP5 ready",[5,30,7,0,0]);await publish("MP5 notch",[5,30,67,100,0,0,100,100]);await publish("MP5 slap",[5,30,7,0,0])
			s.serial+=1;s.weapon=9;s.cooldown=0
			await publish("AWP ready",[9,10,7,0,0]);await publish("AWP bolt raise",[9,10,11,0,0,0,100,100]);await publish("AWP bolt pull",[9,10,11,100,0,0,100,100]);await publish("AWP bolt close",[9,10,11,0,0,0,100,100]);await publish("AWP bolt lock",[9,10,7,0,0,0,0,100])
			s.serial+=1;s.weapon=2;s.cooldown=0
			await publish("USP ready",[2,12,7,0,0]);cs.physical(id).ready=false;cs.physical(id).locked=true
			await publish("USP side flick",[2,12,7,0,0])
			s.serial+=1;s.weapon=3;s.cooldown=0
			await publish("M3 second ready",[3,8,7,0,0]);await publish("M3 second shot",[3,7,3,0,0]);await publish("M3 swing",[3,7,527,0,0]);await publish("M3 take back",[3,7,7,0,0])
			s.serial+=1;s.weapon=7;s.cooldown=0
			await publish("M4 ready",[7,30,7,0,0]);await publish("M4 grip magazine",[7,30,1031,0,0])
			await publish("M4 pull magazine",[7,1,1029,0,4]);check(cs.row(id)[11]==29,"Authority retains exact held magazine count")
			await publish("M4 reinsert magazine",[7,30,7,0,0]);check(cs.row(id)[11]==0 and s.ammo[2]==300,"Network reinsertion clears held count and conserves ammunition")
		observer.stage.rpc("done",[]);await pause(.2)
	else:
		game.start_join("CS16 remote","127.0.0.1",28978)
		check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,20),"Client enters match")
		game.set_physics_process(false);game.set_process(false)
		check(game.armory.effective()=="cs16","Loadout arrives before player state")
		observer.acknowledge.rpc_id(1,"ready")
		pose=Poses.neutral()
		var handled:="";var deadline:=Time.get_ticks_msec()+90000
		while Time.get_ticks_msec()<deadline and observer.phase!="done":
			await pause(.02)
			if observer.request_reload:
				observer.request_reload=false
				game._input_command.rpc_id(1,{"seq":1000,"map_epoch":game.map_epoch,"input_life":game.local_state().serial,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"reload":true,"weapon":2,"slow":false,"respawn":false,"clips":{2:999}})
			if observer.phase.is_empty() or handled==observer.phase or observer.phase=="done":continue
			var label:=observer.phase
			if observer.expected.size() in [5,8]:await gesture(label,observer.expected[0])
			check(await wait_for(func():
				var row: Array=game.variant_combat.cs.status(game.multiplayer.get_unique_id())
				return row.size()==Reload.ROW_SIZE and ([row[1],row[2],row[5],row[6],row[7],row[8],row[9],row[10]] if observer.expected.size()==8 else [row[1],row[2],row[5],row[7],row[8]] if observer.expected.size()==5 else [row[1],row[2],row[3]>0,row[4]])==observer.expected,5),"Replicated "+label+" agrees with authority")
			if label in ["M4 pull magazine","M4 reinsert magazine"]:
				check(game.variant_combat.cs.status(game.multiplayer.get_unique_id())[11]==(29 if label=="M4 pull magazine" else 0),"Held magazine count replicates for "+label)
			observer.acknowledge.rpc_id(1,label);handled=label
		check(observer.phase=="done","Network scenario completes")
		check(packets_fit,"Physical inputs fit the production packet limit")
	print("CS16_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
