extends "res://deathmatch/tests/network_runner.gd"
## Eight real ENet clients on the authored BSP. Scripted setup, production input/combat/rules.
const COUNT=8
class Probe extends Node:
	var seen: Dictionary={}
	var phase:="idle"
	@rpc("any_peer","call_remote","reliable")
	func ack(label: String) -> void:
		if multiplayer.is_server():
			if not seen.has(label):seen[label]={}
			seen[label][multiplayer.get_remote_sender_id()]=true
	@rpc("authority","call_local","reliable")
	func begin(label: String) -> void:phase=label
var observer: Probe
var sample_count:=0
var projectile_seen:=false
var damage_seen:=false
var roster_stable:=true
var started:=0
var record_path:=""
func all_seen(label: String,seconds: float=20) -> bool:
	return await wait_for(func():return observer.seen.get(label,{}).size()==COUNT,seconds)
func run() -> void:
	var args:=OS.get_cmdline_user_args();role=args[0];var path: String=args[1]
	if args.size()>2:record_path=args[2]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=Probe.new();observer.name="EightProbe";game.add_child(observer)
	var hash:=FileAccess.get_sha256(path);var key:=path.get_file().get_basename()
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-eight.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map=key
	started=Time.get_ticks_msec()
	if role=="server":await authority()
	else:await client()
	print("EIGHT_RESULT ",JSON.stringify({"role":role,"failures":failures,"samples":sample_count,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0}))
	game.disconnect_game("Eight-player test complete");await pause(.2);game.free();quit(0 if failures.is_empty() else 1)
func authority() -> void:
	game.dedicated=true;game.max_clients=COUNT;game.match_mode.configure({"sv_gametype":"as"});game.start_host("AS eight-player test",27884,20,7,false,"as")
	check(await wait_for(func():return game.players.size()==COUNT,90),"Eight independent clients join the dedicated server")
	if game.players.size()!=COUNT:return
	check(await all_seen("spawn",40),"All eight clients confirm pistol-only AS spawn, roster and three sentries")
	if not record_path.is_empty():check(game.demos.start_record(record_path),"Server records the eight-player match")
	var ids: Array=game.players.keys();ids.sort_custom(func(a,b):return game.players[a].name<game.players[b].name)
	var teams:=[0,0]
	for id in ids:teams[game.players[id].team]+=1
	check(teams==[4,4],"Eight players balance into 4-versus-4")
	# Move and fire from ordinary role spawns, no server-generated player inputs.
	var positions: Dictionary={};var displacement: Dictionary={}
	for id in ids:positions[id]=game.fighters[id].position;displacement[id]=0.0;game.players[id].invulnerable=game.clock+20
	observer.begin.rpc("movement")
	for sample in 40:
		await pause(.1)
		for id in ids:displacement[id]=maxf(displacement[id],game.fighters[id].position.distance_to(positions[id]))
	observer.begin.rpc("idle");await pause(.2)
	var moved:=0;var fired:=0
	for id in ids:
		if displacement[id]>.3:moved+=1
		if game.players[id].shots>0:fired+=1
	check(moved==COUNT,"All eight remote movement streams move authoritative capsules")
	check(fired==COUNT,"All eight remote fire streams consume pistol ammunition")
	# Four simultaneous duels on the actual broad roof of Car 1.
	# Setup positions/loadouts only; shots, sweeps, damage, deaths and respawns remain production code.
	for index in COUNT:
		var id: int=ids[index];var s: Dictionary=game.players[id]
		s.team=index%2;game._spawn(id);s.invulnerable=0;s.armor=0;s.hp=100;s.cooldown=0
		s.owned=[2,6];s.ammo=[200,0,30,0]
		var roof_x: float=-2.4+int(index/2)*1.6;var roof_z: float=-54 if index%2==0 else -63
		var floor_hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(roof_x,14,roof_z),Vector3(roof_x,8,roof_z),1))
		check(not floor_hit.is_empty() and floor_hit.normal.y>.8,"Duel setup finds a walkable roof for "+s.name)
		if floor_hit.is_empty():return
		game.fighters[id].position=floor_hit.position+Vector3.UP*.05
		game.fighters[id].velocity=Vector3.ZERO;s.serial+=1
	game._broadcast_roster();game.history.clear()
	observer.begin.rpc("pistols");await pause(3)
	observer.begin.rpc("rockets");await pause(3)
	observer.begin.rpc("idle");await pause(.2)
	var total_deaths:=0
	for id in ids:total_deaths+=game.players[id].deaths
	check(total_deaths>0,"Network combat produces authoritative deaths and scoreboard updates")
	check(await all_seen("damage"),"All eight replicas observe combat damage")
	check(await all_seen("projectile"),"All eight replicas observe moving network projectiles")
	observer.begin.rpc("respawn");await pause(3);observer.begin.rpc("idle")
	check(game.players.values().all(func(s):return not s.dead),"All dead players respawn through client input")
	var rules=game.match_mode.assault
	# Reset participants to role spawns before testing simultaneous objective touches.
	for id in ids:game._spawn(id);game.players[id].invulnerable=game.clock+120
	await pause(.3)
	for id in ids:
		if game.players[id].team==0:game.fighters[id].position=rules.objectives[0].position;game.players[id].serial+=1
	check(await all_seen("switch"),"All eight clients receive one ordered switch activation")
	check(rules.stage==1,"Simultaneous attacker touches advance the objective exactly once")
	game.round_left=360
	for id in ids:
		if game.players[id].team==0:game.fighters[id].position=rules.objectives[1].position;game.players[id].serial+=1
	check(await all_seen("swap",25),"All eight clients receive timed role swap and reset objectives/sentries")
	check(rules.leg==1 and rules.attacking==1 and rules.stage==0,"Second leg is authoritative and resets state")
	for id in ids:game.players[id].invulnerable=game.clock+120
	var red:=0;var blue:=0
	for id in ids:
		if game.players[id].team==0:red=id
		else:blue=id
	game.match_mode.fortress.damage_building(100001,red,150)
	check(game.match_mode.fortress.buildings.has(100001),"Defender cannot destroy its friendly static turret")
	game.match_mode.fortress.damage_building(100001,blue,150)
	check(await all_seen("turret"),"All eight clients remove an attacker-destroyed turret")
	for id in ids:
		if game.players[id].team==1:game.fighters[id].position=rules.objectives[0].position;game.players[id].serial+=1
	check(await wait_for(func():return rules.stage==1,5),"Return attackers activate first objective")
	game.round_left=rules.budget-20
	for id in ids:
		if game.players[id].team==1:game.fighters[id].position=rules.objectives[1].position;game.players[id].serial+=1
	check(await all_seen("result"),"All eight clients agree on BLUE winning the faster return assault")
	check(game.players.size()==COUNT,"All eight clients remain connected through both legs")
	print("EIGHT_SERVER_METRICS ",JSON.stringify({"teams":teams,"moved":moved,"max_displacement":displacement,"fired":fired,"combat_deaths":total_deaths,"scores":game.match_mode.scores,"first_time":rules.first_time,"acks":observer.seen}))
	await pause(.4)
	if game.demos.recording:
		game.demos.stop_record();print("EIGHT_DEMO ",record_path)
	observer.begin.rpc("done");await pause(1)
func client() -> void:
	game.start_join(role,"127.0.0.1",27884)
	check(await wait_for(func():return game.active and game.players.size()==COUNT and game.local_state().get("serial",0)>0 and game.match_mode.fortress.buildings.size()==3,100),"Client receives all eight players and AS map state")
	if not game.active:return
	check(game.local_state().owned==[2] and game.match_mode.kind=="as" and not game.match_mode.fortress.enabled(),"AS starts with only pistol and no classes")
	observer.ack.rpc_id(1,"spawn")
	# Disable automatic local input, retaining the real client snapshot/interpolation code.
	game.dedicated=true
	var acked: Dictionary={};var deadline:=Time.get_ticks_msec()+110000;var ticks:=0
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		ticks+=1;game.sequence+=1
		var phase: String=observer.phase;var state: Dictionary=game.local_state()
		if state.is_empty():check(false,"Local player remains in roster");break
		var index:=int(role.trim_prefix("player"))
		var command: Dictionary={"seq":game.sequence,"map_epoch":game.map_epoch,"move":Vector2(sin(ticks*.08)*.45,0) if phase=="movement" else Vector2.ZERO,"yaw":0.0 if index%2==0 else PI,"pitch":0.0,"fire":phase in ["movement","pistols","rockets"],"weapon":6 if phase=="rockets" else 2,"slow":false,"respawn":phase=="respawn","jump":phase=="movement" and ticks%45==0,"view_time":game.remote_view_time}
		game._input_command.rpc_id(1,command)
		roster_stable=roster_stable and game.players.size()==COUNT
		projectile_seen=projectile_seen or not game.projectiles.is_empty()
		damage_seen=damage_seen or game.players.values().any(func(s):return s.hp<100 or s.dead or s.deaths>0)
		var rules=game.match_mode.assault
		var conditions={"damage":damage_seen,"projectile":projectile_seen,"switch":rules.stage==1 and rules.leg==0,"swap":rules.leg==1 and rules.stage==0 and rules.attacking==1 and game.match_mode.fortress.buildings.size()==3,"turret":rules.leg==1 and not game.match_mode.fortress.buildings.has(100001),"result":rules.finished and game.match_mode.scores==[0,1]}
		for label in conditions:
			if conditions[label] and not acked.has(label):observer.ack.rpc_id(1,label);acked[label]=true
		sample_count+=1
		await pause(1.0/30)
	check(observer.phase=="done","Test completes without timeout or disconnect")
	check(roster_stable,"Eight-player roster remains synchronized")
	for label in ["damage","projectile","switch","swap","turret","result"]:check(acked.has(label),"Replica verified "+label)
