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
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	Fixture.setup(game);Fixture.box(game,Fixture.ORIGIN-Vector3.UP*.5,Vector3(500,1,500))
	observer=Probe.new();observer.name="TribesProbe";game.add_child(observer)
	await physics_frame
	if role=="server":await server_case()
	else:await client_case()
	print("TRIBES_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
func server_case():
	game.dedicated=true;game.bind_address="127.0.0.1";game.votes.enabled=false;game.selected_map="ctf_stonehenge"
	game.match_mode.configure({"sv_gametype":"st"});game.armory.select("tribes")
	game.start_host("Tribes network",28983,100,30,false,"st","tribes")
	check(await wait_for(func():return observer.seen.has("pilot ready"),25),"Pilot joins Stonehenge with Tribes loadout")
	if not observer.seen.has("pilot ready"):return
	var id: int=game.players.keys().filter(func(key):return not game.players[key].spectator)[0]
	var s: Dictionary=game.players[id];var a=game.fighters[id];var rules=game.match_mode.tribes
	a.position=Fixture.point(0,15);a.velocity=Vector3(0,0,-35);a.reset_tribes();a.reset_view();s.serial+=1
	stage("flight");await pause(2.5)
	check(a.tribes_enabled and a.tribes_state.jetting and a.tribes_state.energy<40 and a.position.y>Fixture.ORIGIN.y+10,"Authoritative sustained thrust drains energy and lifts the player")
	check(await wait_for(func():return observer.seen.has("viewer flight"),15),"Late spectator receives intrinsic jet and energy state")
	check(observer.seen.has("predicted flight"),"Pilot predicts the same intrinsic jet profile")
	stage("release");var energy: float=a.tribes_state.energy;await pause(.8)
	check(not a.tribes_state.jetting and a.tribes_state.energy>energy,"Released remote jets stop and recharge")
	stage("blocked");energy=a.tribes_state.energy;await pause(.5)
	check(not a.tribes_state.jetting and not a.tribes_state.skiing and a.tribes_state.energy>=energy,"Menu-blocked held inputs cannot burn or ski")
	stage("timeout");await pause(.8)
	check(a.tribes_blocked and not a.tribes_state.jetting and not a.ski_held,"Lost connection releases sustained jets and skiing")
	stage("stale");await pause(.5)
	check(not a.jet_held and not a.ski_held,"Previous-life held flight commands are rejected")
	game._damage(id,id,1000,"Tribes network",true);stage("dead")
	check(await wait_for(func():return observer.seen.has("dead"),3),"Death clears remote jetting")
	game._spawn(id);stage("respawn")
	check(await wait_for(func():return observer.seen.has("respawn"),3),"Respawn restores full energy without a pickup")
	for key in ["medium","heavy"]:
		await pause(.3)
		var bank: int=game.match_mode.tribes.bank(id);game.match_mode.tribes.energy[bank]=10000;var before: int=game.match_mode.tribes.energy[bank]
		stage("armour_"+key)
		check(await wait_for(func():return s.get("tribes_next")==key,3),"Remote class menu request reaches authority: "+key)
		check(game.match_mode.tribes.energy[bank]==before,"Queued remote favourites cost nothing until station purchase: "+key)
		a.position=rules.stations().rows.filter(func(r):return r.team==s.team)[0].position;a.velocity=Vector3.ZERO;s.serial+=1
		rules.stations().supply[id]=-10
		await pause(.3);before=rules.energy[bank]
		var price: int=rules.refit_cost(id,key,s.tribes_next_guns,s.tribes_next_pack)
		stage("purchase_"+key)
		check(await wait_for(func():return s.tribes_class==key,3),"Authority accepts remote friendly station purchase: "+key)
		check(rules.energy[bank]==before-price,"Authority charges trade-in cost once: "+key)
		check(await wait_for(func():return observer.seen.has("owner "+key),3),"Owner receives class, durability and larger energy capacity: "+key)
		check(await wait_for(func():return observer.seen.has("viewer "+key),3),"Spectator receives armour profile: "+key)
	game.match_mode.tribes.stations().health[0]=0.0;stage("base_power")
	check(await wait_for(func():return observer.seen.has("pilot outage") and observer.seen.has("viewer outage"),3),"Generator outage replicates to owner and spectator")
	var pads=game.match_mode.tribes.stations()
	var rack: Dictionary=pads.generators.filter(func(r):return r.team==s.team)[0]
	s.tribes_pack="none";a.tribes_state.pack="none";a.position=rack.repair_position;a.velocity=Vector3.ZERO;s.serial+=1
	check(pads.recover_pack(id),"Power-independent repair pack uses authoritative physical pickup")
	stage("repair_pack")
	check(await wait_for(func():return observer.seen.has("pilot repair_pack") and observer.seen.has("viewer repair_pack"),3),"Emergency repair gun and backpack replicate to owner and spectator")
	game.match_mode.tribes.stations().health[0]=160.0;stage("base_restore")
	check(await wait_for(func():return observer.seen.has("pilot restored") and observer.seen.has("viewer restored"),3),"Repaired base power replicates")
	var deploy=game.match_mode.tribes.deployables
	var assets=pads.assets
	for key in [0,4]:
		assets.damage(key,0,10000);stage("asset_off_%d"%key)
		check(await wait_for(func():return observer.seen.has("pilot asset_off_%d"%key) and observer.seen.has("viewer asset_off_%d"%key),3),"Independent fixture destruction replicates: %d"%key)
		var team: int=s.team;s.team=assets.rows[key].team
		assets.repair(key,id,100);s.team=team;stage("asset_on_%d"%key)
		check(await wait_for(func():return observer.seen.has("pilot asset_on_%d"%key) and observer.seen.has("viewer asset_on_%d"%key),3),"Independent fixture repair replicates: %d"%key)
	assets.reset()
	# Detection itself is exercised with real LOS in st_base_assets; hold its
	# authority result here to verify the production peer state and HUD status.
	deploy.next_scan=game.clock+10;deploy.contacts=[[],[]];deploy.suppressed=[id];stage("sensor_suppressed")
	check(await wait_for(func():return observer.seen.has("pilot suppressed") and observer.seen.has("viewer suppressed"),3),"Scan suppression reaches owner and spectator")
	deploy.suppressed=[];deploy.contacts[1-s.team]=[id];stage("sensor_detected")
	check(await wait_for(func():return observer.seen.has("pilot detected") and observer.seen.has("viewer detected"),3),"Detection status reaches owner and spectator")
	deploy.next_scan=0
	var fixed=pads.defences;var fixed_key: int=range(fixed.rows.size()).filter(func(k):return fixed.rows[k].team==s.team)[0]
	stage("fixed_control")
	check(await wait_for(func():return fixed.rows[fixed_key].operator==id,3),"Remote player claims a friendly fixed turret")
	check(await wait_for(func():return observer.seen.has("pilot fixed_control") and observer.seen.has("viewer fixed_control"),3),"Manual control ownership replicates to pilot and spectator")
	check(await wait_for(func():return fixed.rows[fixed_key].energy<fixed.Data.TYPES[fixed.rows[fixed_key].kind].energy,3),"Remote aiming command fires with real turret energy")
	stage("fixed_release")
	check(await wait_for(func():return fixed.rows[fixed_key].operator==0,3),"Remote release returns turret to automatic operation")
	fixed.damage(fixed_key,0,10000);stage("fixed_off")
	check(await wait_for(func():return observer.seen.has("pilot fixed_off") and observer.seen.has("viewer fixed_off"),3),"Destroyed fixed turret replicates to both clients")
	fixed.repair(fixed_key,id,100);stage("fixed_on")
	check(await wait_for(func():return observer.seen.has("pilot fixed_on") and observer.seen.has("viewer fixed_on"),3),"Repaired fixed turret replicates to both clients")
	pads.playable_bounds=AABB(Fixture.ORIGIN-Vector3(100,10,100),Vector3(200,100,200))
	game.match_mode.tribes.apply_equipment(id,"medium",[3,2,4],"turret");a.position=Fixture.point(0,0);a.velocity=Vector3.ZERO;s.serial+=1
	var origin: Vector3=a.position+Vector3.UP*1.6
	check(deploy.deploy(id,origin,Vector3(0,-1.6,-2).normalized()),"Authority accepts physical deployable placement")
	stage("deployable")
	check(await wait_for(func():return observer.seen.has("pilot deployable") and observer.seen.has("viewer deployable"),3),"Owner and spectator receive placed turret and consumed backpack")
	var key: int=deploy.rows.keys()[0];deploy.damage(key,0,1000);stage("deployable_destroyed")
	check(await wait_for(func():return observer.seen.has("pilot deployable_destroyed") and observer.seen.has("viewer deployable_destroyed"),3),"Remote destruction removes fixture for both clients")
	rules.recovery.reset();rules.apply_equipment(id,"light",[3,2,0],"ammo");a.position=Fixture.point(20,20);a.velocity=Vector3.ZERO;s.serial+=1
	rules.recovery.scan_at=game.clock+30
	await pause(.3);stage("field_drop")
	check(await wait_for(func():return not rules.recovery.rows.is_empty(),3),"Remote sequenced field request drops real backpack")
	check(await wait_for(func():return observer.seen.has("pilot field_drop") and observer.seen.has("viewer field_drop"),3),"Owner and spectator receive stored ammo pack contents")
	if not rules.recovery.rows.is_empty():
		var drop_key: int=rules.recovery.rows.keys()[0]
		await pause(1.1);a.position=rules.recovery.rows[drop_key].position-Vector3.UP*.65;a.velocity=Vector3.ZERO;s.serial+=1
		check(rules.recovery.pickup(id,drop_key),"Server recovers actual stored ammo pack through proximity")
	stage("field_recovered")
	check(await wait_for(func():return observer.seen.has("pilot field_recovered") and observer.seen.has("viewer field_recovered"),3),"Recovered inventory and empty world drop replicate together")
	a.position=Fixture.point(30,30);a.velocity=Vector3.ZERO;s.serial+=1;s.tribes_beacons=3
	check(rules.targeting.place(id,a.position+Vector3.UP*.7+Vector3.RIGHT*.8,Vector3.DOWN),"Network fixture places a physical target beacon")
	stage("field_beacon")
	check(await wait_for(func():return observer.seen.has("pilot field_beacon") and observer.seen.has("viewer field_beacon"),3),"Beacon ownership, surface and consumed inventory replicate")
	var beacon_key: int=rules.targeting.beacons.keys()[0];rules.targeting.damage(beacon_key,0,1000);stage("field_beacon_removed")
	check(await wait_for(func():return observer.seen.has("pilot field_beacon_removed") and observer.seen.has("viewer field_beacon_removed"),3),"Destroyed target disappears for owner and spectator")
	game.match_mode.flags[1-s.team].carrier=id
	game.match_mode.st.drop(id,a.position+Vector3(10,15,0),Vector3(8,1,0));stage("flag_flight")
	check(await wait_for(func():return observer.seen.has("pilot flag") and observer.seen.has("viewer flag"),3),"Airborne dropped flag replicates to both clients")
	game.match_mode.return_flag(1-s.team)
	game.match_mode.kind="tdm";game.armory.select("quake");stage("quake");await pause(.6)
	check(not a.tribes_enabled and a.velocity.length()<15,"Switching loadout removes Tribes movement and momentum")
	check(await wait_for(func():return observer.seen.has("quake"),3),"Movement profile change reaches the owner")
	stage("done");await pause(.3)
func client_case():
	var viewer:=role=="viewer"
	game.start_join("Tribes viewer" if viewer else "Tribes pilot","127.0.0.1",28983,viewer)
	check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,25),"Client enters Stonehenge")
	game.set_physics_process(false);game.set_process(false)
	observer.report.rpc_id(1,"viewer ready" if viewer else "pilot ready")
	var reported: Dictionary={};var seq:=1000;var tick:=0;var queue: Array=[];var max_packet:=0
	var previous_phase:="";var phase_stats: Array=[];var phase_tick:=0
	var deadline:=Time.get_ticks_msec()+95000
	while Time.get_ticks_msec()<deadline and observer.phase!="done":
		await physics_frame
		var dt:=1.0/Engine.physics_ticks_per_second;game.clock+=dt;tick+=1
		var mine: int=game.multiplayer.get_unique_id();var s: Dictionary=game.local_state()
		if s.is_empty() or not game.fighters.has(mine):continue
		var a=game.fighters[mine];var phase:=observer.phase
		if phase!=previous_phase and not viewer:
			phase_stats.append({"phase":previous_phase,"prediction":a.prediction.stats.duplicate()})
			a.prediction.stats={"corrections":0,"max_error":0.0,"resets":0};previous_phase=phase;phase_tick=0
		phase_tick+=1
		# Exclude the artificial teleport/new-life handover at flight start.
		if not viewer and phase=="flight" and phase_tick==15:a.prediction.stats={"corrections":0,"max_error":0.0,"resets":0}
		var base=game.match_mode.tribes.stations()
		var shared:={"outage":phase=="base_power" and base and base.health[0]==0,"restored":phase=="base_restore" and base and base.health[0]==160,"flag":phase=="flag_flight" and game.match_mode.flags.any(func(f):return f.dropped)}
		shared["repair_pack"]=phase=="repair_pack" and game.players.keys().any(func(id):return not game.players[id].spectator and game.players[id].get("tribes_pack")=="repair" and 8 in game.players[id].owned and game.fighters[id].tribes_state.pack=="repair")
		shared["deployable"]=phase=="deployable" and game.match_mode.tribes.deployables.rows.size()==1 and game.match_mode.tribes.deployables.nodes.size()==1 and game.players.keys().any(func(id):return not game.players[id].spectator and game.players[id].tribes_pack=="none")
		shared["deployable_destroyed"]=phase=="deployable_destroyed" and game.match_mode.tribes.deployables.rows.is_empty() and game.match_mode.tribes.deployables.nodes.is_empty()
		for key in [0,4]:
			shared["asset_off_%d"%key]=phase=="asset_off_%d"%key and base.assets.rows[key].hp==0
			shared["asset_on_%d"%key]=phase=="asset_on_%d"%key and base.assets.rows[key].hp==100
		var pilots: Array=game.players.keys().filter(func(id):return not game.players[id].spectator)
		if pilots.is_empty():continue
		var pilot: int=pilots[0]
		shared["suppressed"]=phase=="sensor_suppressed" and game.match_mode.tribes.deployables.sensor_status(pilot)=="JAMMED"
		shared["detected"]=phase=="sensor_detected" and game.match_mode.tribes.deployables.sensor_status(pilot)=="DETECTED"
		var fixed_key: int=range(base.defences.rows.size()).filter(func(k):return base.defences.rows[k].team==game.players[pilot].team)[0]
		shared["fixed_control"]=phase=="fixed_control" and base.defences.rows[fixed_key].operator==pilot
		shared["fixed_off"]=phase=="fixed_off" and base.defences.rows[fixed_key].hp==0
		shared["fixed_on"]=phase=="fixed_on" and base.defences.rows[fixed_key].hp==100
		if not viewer and phase=="fixed_control":
			if not reported.has("claim turret"):reported["claim turret"]=true;game.match_mode.tribes.control_turret(fixed_key)
			if base.defences.rows[fixed_key].operator==mine and tick%3==0:game.match_mode.tribes.turret_command.rpc_id(1,fixed_key,game.map_epoch,s.serial,Vector3.FORWARD,true)
		if not viewer and phase=="fixed_release" and not reported.has("release turret"):
			reported["release turret"]=true;game.match_mode.tribes.control_turret(-1)
		var field=game.match_mode.tribes
		shared["field_drop"]=phase=="field_drop" and field.recovery.rows.values().any(func(row):return row.payload.pack=="ammo" and row.payload.ammo[2]==150) and game.players[pilot].tribes_pack=="none"
		shared["field_recovered"]=phase=="field_recovered" and field.recovery.rows.is_empty() and game.players[pilot].tribes_pack=="ammo" and game.players[pilot].tribes_ammo[2]==250
		shared["field_beacon"]=phase=="field_beacon" and field.targeting.beacons.size()==1 and game.players[pilot].get("tribes_beacons",0)==2
		shared["field_beacon_removed"]=phase=="field_beacon_removed" and field.targeting.beacons.is_empty()
		if not viewer and phase=="field_drop" and not reported.has("request drop"):
			reported["request drop"]=true;field.field_action("pack")
		for key in shared:
			var label: String=role+" "+key
			if shared[key] and not reported.has(label):reported[label]=true;observer.report.rpc_id(1,label)
		if viewer:
			for id in game.players:
				if not game.players[id].spectator and game.fighters[id].tribes_state.jetting and game.fighters[id].tribes_state.energy<59 and not reported.has("viewer flight"):
					reported["viewer flight"]=true;observer.report.rpc_id(1,"viewer flight")
			for id in game.players:
				var key: String=game.players[id].get("tribes_class","light")
				var label: String="viewer "+key
				if observer.phase=="purchase_"+key and key in ["medium","heavy"] and not game.players[id].spectator and game.fighters[id].tribes_state.armour==key and not reported.has(label):
					reported[label]=true;observer.report.rpc_id(1,label)
			continue
		if phase.begins_with("armour_") or phase.begins_with("purchase_"):
			var key:=phase.trim_prefix("armour_").trim_prefix("purchase_")
			if phase.begins_with("purchase_") and not reported.has("buy "+key):
				reported["buy "+key]=true;game.match_mode.tribes.choose_equipment(key,s.tribes_next_guns,s.tribes_next_pack,true)
			if not reported.has("request "+key):
				reported["request "+key]=true;game.match_mode.tribes.choose(key)
			var label:="owner "+key
			if s.get("tribes_class")==key and a.tribes_state.armour==key and a.tribes_state.energy<=game.match_mode.tribes.CLASSES[key].energy and s.hp==game.match_mode.tribes.CLASSES[key].hp and not reported.has(label):
				reported[label]=true;observer.report.rpc_id(1,label)
		seq+=1
		var held:=phase in ["flight","blocked","timeout","stale"]
		var command:={"seq":seq,"map_epoch":game.map_epoch,"input_life":s.serial-1 if phase=="stale" else s.serial,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":s.weapon,"slow":false,"respawn":false,"jump":false,"ski":held,"jetpack":held,"input_blocked":phase=="blocked","energy":60000}
		# Deterministic 50–100 ms input delay, jitter and 20% packet loss.
		if tick%2==0 and tick%10!=0 and phase!="timeout":
			var packet:=Codec.pack(command);max_packet=maxi(max_packet,packet.size());queue.append({"at":tick+3+(tick%4),"bytes":packet})
		while not queue.is_empty() and queue[0].at<=tick:
			game._input_packet.rpc_id(1,queue.pop_front().bytes)
		if not s.dead and not s.spectator:
			game._configure_tribes(mine,command)
			a.simulate(Vector2.ZERO,0,false,dt,false)
			a.prediction.remember(seq,a.position,a.velocity,a.collision_height,{},a.tribes_state if a.tribes_enabled else {},a.tribes_command if a.tribes_enabled else {})
		var facts:={"predicted flight":phase=="flight" and a.tribes_state.jetting and a.tribes_state.energy<55,"dead":phase=="dead" and s.dead and not a.tribes_state.jetting,"respawn":phase=="respawn" and not s.dead and a.tribes_state.energy==60,"quake":phase=="quake" and not a.tribes_enabled and game.armory.effective()=="quake"}
		for label in facts:
			if facts[label] and not reported.has(label):reported[label]=true;observer.report.rpc_id(1,label)
	check(observer.phase=="done","Network scenario completes")
	if viewer:check(reported.has("viewer flight"),"Late observer sees flight")
	else:
		check(max_packet<=1100,"Sustained input fits production packet limit")
		check(["predicted flight","dead","respawn","quake"].all(func(k):return reported.has(k)),"Owner observes flight and lifecycle")
		var a=game.fighters[game.multiplayer.get_unique_id()]
		for row in phase_stats:
			if row.phase in ["flight","release"]:
				check(row.prediction.get("max_replay_adjustment",0)<1.0 and row.prediction.resets==0,"Bounded reconciliation during "+row.phase)
		print("TRIBES_PREDICTION ",JSON.stringify(phase_stats))
