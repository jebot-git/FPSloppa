extends "res://deathmatch/tests/network_runner.gd"
const COUNT=8
const ROLES=["scout","sniper","soldier","demoman","medic","heavy","pyro","engineer"]
class Probe extends Node:
	var phase:="idle"
	var commands: Dictionary={}
	var seen: Dictionary={}
	@rpc("authority","call_local","reliable")
	func begin(label: String,data: Dictionary) -> void:phase=label;commands=data
	@rpc("any_peer","call_remote","reliable")
	func ack(label: String) -> void:
		if multiplayer.is_server():
			if not seen.has(label):seen[label]={}
			seen[label][multiplayer.get_remote_sender_id()]=true
var observer: Probe
var ids: Array=[]
var tf
var lane: Dictionary={}
var timeline: Array=[]
var record_path:=""
var cues: Array=[]
var used: Dictionary={}
func run() -> void:
	var args:=OS.get_cmdline_user_args();role=args[0];var path: String=args[1];record_path=args[2] if args.size()>2 else ""
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=Probe.new();observer.name="TFProbe";game.add_child(observer);tf=game.match_mode.fortress
	game.announcer.cue_received.connect(func(cue,_target):cues.append(cue))
	var hash:=FileAccess.get_sha256(path);var key:=path.get_file().get_basename()
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-tf-eight.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map=key
	if role=="probe":
		game.set_physics_process(false);game._load_map(key);game.match_mode.kind="tf";game.match_mode.reset()
		await physics_frame;await physics_frame
		lane=find_lane();print("TF_LANE ",lane);game.free();quit(0 if not lane.is_empty() else 1);return
	if role=="server":await authority()
	else:await client()
	var result={"role":role,"failures":failures,"phases":timeline,"used_classes":used.keys(),"objective_calls":cues.count("objective_completed")}
	if role=="server" and not record_path.is_empty():FileAccess.open(record_path.get_basename()+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("EIGHT_RESULT ",JSON.stringify(result));game.disconnect_game("TF eight-player test complete");await pause(.2);game.free();quit(0 if failures.is_empty() else 1)
func floor_at(pos: Vector3) -> Variant:
	var space=game.get_world_3d().direct_space_state
	var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*3,pos-Vector3.UP*5,1))
	if hit.is_empty() or hit.normal.y<.9:return null
	var feet: Vector3=hit.position+Vector3.UP*.05
	var shape:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;shape.shape=capsule;shape.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*.92);shape.collision_mask=1
	if not space.intersect_shape(shape,1).is_empty():return null
	return feet
func find_lane() -> Dictionary:
	var anchors: Array=game.ctf_spawns[0]+game.ctf_spawns[1]+game.match_mode.captures
	for anchor in anchors:
		for dx in [-8,0,8]:
			for dz in [-8,0,8]:
				var start=floor_at(anchor+Vector3(dx,0,dz))
				if start==null:continue
				for angle in [0.0,PI*.5,PI,PI*1.5]:
					var dir:=Vector3(-sin(angle),0,-cos(angle));var end=floor_at(start+dir*5)
					if end==null or absf(start.y-end.y)>.2:continue
					var valid:=true
					for n in 11:
						var at=floor_at(start+dir*n*.5)
						if at==null or absf(at.y-start.y)>.2:valid=false;break
						if n>=5 and game.spawn_points.any(func(p):return p.distance_to(at)<2.1):valid=false;break
						if n>=5 and game.match_mode.bases.any(func(p):return p.distance_to(at)<2.1):valid=false;break
					if valid and game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3.UP*1.5,end+Vector3.UP*1.5,1)).is_empty():return {"start":start,"end":end,"direction":dir,"yaw":angle}
	return {}
func command(index: int,fire: bool=false,use: bool=false,weapon: int=-1) -> Dictionary:
	var target: Vector3=lane.end+Vector3.UP*1.1
	var origin: Vector3=game._shot_origin(ids[index]);var dir: Vector3=(target-origin).normalized()
	return {"yaw":atan2(-dir.x,-dir.z),"pitch":asin(dir.y),"fire":fire,"use":use,"weapon":game.players[ids[index]].weapon if weapon<0 else weapon}
func phase(label: String,focus: int,data: Dictionary={}) -> void:
	timeline.append({"time":game.clock-game.demos.started,"label":label,"focus":ids[focus]})
	observer.begin.rpc(label,data);print("TF_PHASE ",label)
func park() -> void:
	observer.begin.rpc("idle",{})
	for index in COUNT:
		var id: int=ids[index];game._spawn(id);game.players[id].invulnerable=0;game.players[id].use_at=0;tf.cooldowns[id]=0
		var spawn: Vector3=game.ctf_spawns[index%2][index/2];game.fighters[id].position=spawn;game.fighters[id].velocity=Vector3.ZERO;game.players[id].serial+=1
func pair(caster: int,target: int,distance: float=4) -> void:
	park()
	game.fighters[ids[caster]].position=lane.start
	game.fighters[ids[target]].position=lane.start+lane.direction*distance
	for index in [caster,target]:game.fighters[ids[index]].velocity=Vector3.ZERO;game.players[ids[index]].serial+=1
func all_seen(label: String,seconds: float=15) -> bool:return await wait_for(func():return observer.seen.get(label,{}).size()==COUNT,seconds)
func authority() -> void:
	game.dedicated=true;game.max_clients=COUNT;game.match_mode.configure({"sv_gametype":"tf","capturelimit":1});game.start_host("Turtler eight-player TF",27885,20,7,false,"tf")
	check(await wait_for(func():return game.players.size()==COUNT,90),"Eight real clients join Turtler TF")
	if game.players.size()!=COUNT:return
	check(await all_seen("join",30),"All clients receive the eight-player TF roster")
	ids=game.players.keys();ids.sort_custom(func(a,b):return game.players[a].name<game.players[b].name)
	check(await wait_for(func():return ids.all(func(id):return game.players[id].get("tf_next","")==ROLES[int(game.players[id].name.trim_prefix("player"))]),10),"All clients choose their assigned classes through RPC")
	for index in COUNT:
		game.players[ids[index]].team=index%2;game._spawn(ids[index])
	game._broadcast_roster();lane=find_lane();check(not lane.is_empty(),"Actual BSP supplies a clear interaction lane")
	if lane.is_empty():return
	print("TF_LANE ",lane)
	check(game.demos.start_record(record_path),"Authoritative TF recording starts")
	await pause(.5)
	phase("class_loadouts",0)
	check(await all_seen("loadouts"),"Every client confirms all eight class loadouts")
	# Buffs through actual client Use RPC, then deliberate combat with normal weapon rules.
	park();await pause(.2)
	phase("sprint_focus_brace",0,{0:{"use":true,"move":Vector2(.35,0)},1:{"use":true},5:{"use":true}})
	check(await wait_for(func():return tf.effects.size()>=3,3),"Scout sprint, sniper focus and heavy brace activate remotely")
	check(tf.speed(ids[0])>1.25 and tf.weapon_data(ids[1],9).damage==150 and tf.incoming_damage(ids[5],100,"PISTOL",false)==65,"Buffs affect movement, focus damage and brace resistance")
	for name in ["scout","sniper","heavy"]:used[name]=true
	check(await all_seen("buffs",4),"All peers receive the active buff states")
	await pause(2)
	pair(1,2);await pause(.2);phase("focused_rail",1,{1:command(1,false,true)})
	check(await wait_for(func():return tf.effects.has(ids[1]),2),"Sniper prepares focused shot")
	var health: int=game.players[ids[2]].hp
	phase("focused_rail_fire",1,{1:command(1,true,false,9)});await pause(.4);observer.begin.rpc("idle",{})
	check(game.players[ids[2]].hp<health,"Focused rail hits the opposing soldier")
	pair(4,2,3);game.players[ids[2]].hp=40;await pause(.2)
	phase("medic_heal",4,{4:command(4,false,true)})
	check(await wait_for(func():return game.players[ids[2]].hp>=75,2),"Medic heals teammate through aimed remote Use")
	used.medic=true;await pause(1)
	pair(7,2,5);game.players[ids[2]].invulnerable=game.clock+4;await pause(.2)
	phase("engineer_sentry_build",7,{7:{"yaw":lane.yaw,"pitch":0.0,"use":true}})
	check(await wait_for(func():return not tf.buildings.is_empty(),2),"Engineer builds sentry on the converted map")
	if not tf.buildings.is_empty():
		var key: int=tf.buildings.keys()[0];var hp: int=game.players[ids[2]].hp
		check(await wait_for(func():return game.players[ids[2]].hp<hp,6),"Constructed sentry attacks and damages the enemy")
		# Pause sentry fire during its repair demonstration.
		tf.buildings[key].next=game.clock+20;tf.damage_building(key,ids[2],40)
		game.fighters[ids[7]].position+=lane.direction*.8;game.players[ids[7]].serial+=1
		await pause(.2)
		var aim: Vector3=(tf.buildings[key].position+Vector3.UP*.7-game._shot_origin(ids[7])).normalized()
		phase("engineer_repair",7,{7:{"yaw":atan2(-aim.x,-aim.z),"pitch":asin(aim.y),"use":true}})
		check(await wait_for(func():return tf.buildings.has(key) and tf.buildings[key].hp==150,2),"Engineer repairs damaged sentry")
		await pause(1);tf.damage_building(key,ids[2],500);await pause(.8)
	used.engineer=true
	pair(2,5,3);game.players[ids[5]].armor=0;await pause(.2);health=game.players[ids[5]].hp
	phase("soldier_grenade",2,{2:command(2,false,true)})
	check(await wait_for(func():return tf.charges.has(ids[2]),1),"Soldier throws a network grenade")
	check(await wait_for(func():return not tf.charges.has(ids[2]) and game.players[ids[5]].hp<health,3),"Soldier grenade detonates and damages enemy")
	used.soldier=true;await pause(.8)
	pair(3,2,3);game.players[ids[2]].armor=0;await pause(.2);health=game.players[ids[2]].hp
	var pipe_command:=command(3,false,true);pipe_command.pitch=-.9
	phase("demoman_pipe_throw",3,{3:pipe_command})
	check(await wait_for(func():return tf.charges.has(ids[3]),1),"Demoman throws a pipe projectile")
	await pause(.3);check(tf.charges.has(ids[3]),"Pipe stays alive while arming")
	await pause(.5);phase("demoman_pipe_detonate",3,{3:command(3,false,true)})
	check(await wait_for(func():return not tf.charges.has(ids[3]),2),"Armed pipe detonates through remote Use")
	check(game.players[ids[2]].hp<health,"Manual pipe blast applies enemy damage")
	used.demoman=true;check(await all_seen("charge",4),"All eight replicas observe a thrown grenade");await pause(.8)
	pair(6,5,3);game.players[ids[5]].armor=0;await pause(.2);health=game.players[ids[5]].hp
	var napalm_command:=command(6,false,true);napalm_command.pitch=-.7
	phase("pyro_napalm",6,{6:napalm_command})
	check(await wait_for(func():return tf.charges.has(ids[6]),1),"Pyro launches a napalm projectile")
	check(await wait_for(func():return tf.burns.has(ids[5]),3),"Napalm ignites the enemy")
	await pause(1);check(game.players[ids[5]].hp<health,"Napalm and afterburn apply damage")
	pair(6,5,4);game.players[ids[5]].armor=0;await pause(.2);health=game.players[ids[5]].hp
	phase("pyro_flamethrower",6,{6:command(6,true,false,7)});await pause(1);observer.begin.rpc("idle",{})
	check(game.players[ids[5]].hp<health and tf.burns.has(ids[5]),"Flamethrower hits, ignites and emits flame effects")
	used.pyro=true
	park();phase("select_spy",0)
	check(await wait_for(func():return game.players[ids[0]].tf_next=="spy",3),"Client selects ninth class, Spy, for respawn")
	pair(0,5,4);await pause(.2);phase("spy_cloak",5,{0:{"use":true}})
	check(await wait_for(func():return tf.cloaked(ids[0]),2),"Spy cloaks through remote Use")
	check(game.players[ids[0]].tf_disguise.get("hash","")==game.avatars.choices[ids[5]].hash,"Spy disguise uses nearby enemy VRM identity")
	check(await all_seen("spy",4),"All eight clients receive the cloak and VRM disguise")
	await pause(2);phase("spy_reveal",0,{0:command(0,true,false,2)});await pause(.4)
	check(not tf.cloaked(ids[0]) and game.players[ids[0]].tf_disguise.is_empty(),"Firing reveals Spy and restores identity")
	used.spy=true
	park();phase("select_dispenser",7)
	check(await wait_for(func():return game.players[ids[7]].tf_tool=="dispenser",3),"Engineer selects dispenser through class/tool RPC")
	pair(7,5,5);game.players[ids[7]].ammo[3]=120;await pause(.2)
	phase("engineer_dispenser",7,{7:{"yaw":lane.yaw,"pitch":0.0,"use":true}})
	check(await wait_for(func():return tf.buildings.values().any(func(b):return b.kind=="dispenser"),2),"Engineer constructs a dispenser")
	if not tf.buildings.is_empty():
		var building: Dictionary=tf.buildings.values()[0];game.fighters[ids[5]].position=building.position-lane.direction*.8;game.players[ids[5]].serial+=1;game.players[ids[5]].hp=30;game.players[ids[5]].armor=0;game.players[ids[5]].ammo=[0,0,0,0]
		check(await wait_for(func():return game.players[ids[5]].hp>30 and game.players[ids[5]].ammo[0]>0,4),"Dispenser heals and resupplies a teammate")
	await pause(1)
	park();phase("flag_capture",0)
	game.fighters[ids[0]].position=game.match_mode.bases[1];game.players[ids[0]].serial+=1
	check(await wait_for(func():return game.match_mode.flags[1].carrier==ids[0],3),"Spy picks up enemy flag and loses disguise")
	await pause(1);game.fighters[ids[0]].position=game.match_mode.captures[0];game.players[ids[0]].serial+=1
	check(await all_seen("result",10),"All eight clients receive RED capture victory and objective voice")
	check(used.size()==9,"All nine class abilities were exercised")
	await pause(1);game.demos.stop_record();observer.begin.rpc("done",{});await pause(1)
func client() -> void:
	var index:=int(role.trim_prefix("player"));var samples=["sample_d","sample_f","sample_g"]
	var model:=FileAccess.get_sha256(game.avatars.library.Paths.folder("vrm")+samples[index%3]+".vrm")
	if game.avatars.library.entries.has(model):game.avatars.library.selected=model
	game.start_join(role,"127.0.0.1",27885)
	check(await wait_for(func():return game.active and game.players.size()==COUNT and game.match_mode.kind=="tf",100),"Client joins full Turtler TF roster")
	if not game.active:return
	game.dedicated=true;tf.choose(ROLES[index]);observer.ack.rpc_id(1,"join")
	var last:="";var acked: Dictionary={};var deadline:=Time.get_ticks_msec()+160000;var roster_ok:=true
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		game.sequence+=1;var cmd: Dictionary=observer.commands.get(index,{})
		game._input_command.rpc_id(1,{"seq":game.sequence,"map_epoch":game.map_epoch,"move":cmd.get("move",Vector2.ZERO),"yaw":cmd.get("yaw",0.0),"pitch":cmd.get("pitch",0.0),"weapon":cmd.get("weapon",game.local_state().get("weapon",2)),"fire":cmd.get("fire",false),"slow":false,"respawn":false,"view_time":game.remote_view_time})
		if observer.phase!=last:
			last=observer.phase
			if last=="select_spy" and index==0:tf.choose("spy")
			if last=="select_dispenser" and index==7:tf.choose("engineer","dispenser")
			if cmd.get("use",false):await pause(.08);game._use_request.rpc_id(1)
		roster_ok=roster_ok and game.players.size()==COUNT
		var conditions={"loadouts":game.players.values().all(func(s):return s.get("tf_class","")==ROLES[int(s.name.trim_prefix("player"))]),"buffs":tf.effects.size()>=3,"charge":not tf.charges.is_empty(),"spy":game.players.values().any(func(s):return not s.get("tf_disguise",{}).is_empty()) and tf.effects.values().any(func(e):return e.kind=="spy"),"result":game.match_mode.scores==[1,0] and game.intermission>0 and cues.has("objective_completed")}
		for label in conditions:
			if conditions[label] and not acked.has(label):observer.ack.rpc_id(1,label);acked[label]=true
		await pause(1.0/30)
	check(observer.phase=="done" and roster_ok,"Client completes simulation with stable eight-player roster")
	for label in ["loadouts","buffs","charge","spy","result"]:check(acked.has(label),"Client verifies "+label)
