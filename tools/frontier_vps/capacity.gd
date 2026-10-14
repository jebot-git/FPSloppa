extends Node
## Full-map authority probe: scripted humans, no AI or rendering, real collision.
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const Summary=preload("res://tools/voxel_battle/performance.gd")
class ProbeArena extends Base:
	var wire:Array=[]
	var projectile_ms:=0.0
	func _update_projectiles(delta:float,movement_start:Dictionary={}) -> void:
		var start:=Time.get_ticks_usec();super._update_projectiles(delta,movement_start);projectile_ms=(Time.get_ticks_usec()-start)/1000.0
	func _snapshot(data:Array,items:PackedByteArray,remaining:float,pause:float,message:String,limit:int,duration:float,shots:Array,gate_states:Array,epoch:int=0,mode_state:Dictionary={},vote_state:Dictionary={},server_time:float=-1.0,shot_watermark:int=-1) -> void:
		wire=[data,items,remaining,pause,message,limit,duration,shots,gate_states,epoch,mode_state,vote_state,server_time,shot_watermark]
var game
var results:Array=[]
func _ready() -> void:run.call_deferred()
func rss_mb() -> float:
	var status:=FileAccess.open("/proc/self/status",FileAccess.READ)
	if status:
		while not status.eof_reached():
			var line:=status.get_line()
			if line.begins_with("VmRSS:"):return float(line.replace("\t"," ").split(" ",false)[1])/1024.0
	return -1
func run() -> void:
	seed(170032)
	var started:=Time.get_ticks_usec()
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(ProbeArena);get_tree().root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Capacity probe",28815,100,15,false);game.voice.set_mode(0);game.voice.process_mode=Node.PROCESS_MODE_DISABLED
	if not game.active:get_tree().quit(1);return
	var startup:float=(Time.get_ticks_usec()-started)/1000000.0
	game.practice=false;game.votes.enabled=false
	if is_instance_valid(game.bots):game.bots.set_process(false);game.bots.set_physics_process(false);game.bots=null
	var cases:Array=[[32,30],[64,30]]
	if OS.get_cmdline_user_args().has("--capacity-64"):cases=[[64,30]]
	for scenario in cases:
		var count:int=scenario[0];var tick_rate:int=scenario[1];Engine.physics_ticks_per_second=tick_rate
		for id in game.players.keys():
			if id>count:game._peer_left(id)
		for id in range(game.players.size()+1,count+1):game._add_player(id,"Scripted %d"%id)
		for id in game.players:
			var zone:int=(id-1)%11;var site:Dictionary=game.match_mode.objectives.sites[zone]
			game.fighters[id].position=site.position+Vector3((id%3-1)*1.3,.1,((id/11)%3-1)*1.3);game.fighters[id].velocity=Vector3.ZERO
			game.players[id].team=zone%2;game.players[id].invulnerable=game.clock+10000;game.players[id].vr_device=false
		game.match_mode.objectives.rules.reset(11)
		for projectile in game.projectiles.keys():game.projectiles.erase(projectile)
		for id in game.players:
			game._spawn(id)
			var site:Dictionary=game.match_mode.objectives.sites[(id-1)%11]
			game.fighters[id].position=site.position+Vector3((id%3-1)*1.3,.1,((id/11)%3-1)*1.3)
			game.players[id].invulnerable=game.clock+10000

		var case_started:=Time.get_ticks_usec()
		var series:Dictionary={"simulation_ms":[],"simulation_without_projectiles_ms":[],"projectiles_ms":[],"snapshot_build_ms":[],"snapshot_encode_ms":[],"engine_physics_ms":[],"rss_mb":[],"static_mb":[],"active_projectiles":[]}
		var encoder=preload("res://deathmatch/network/replication.gd").new();var bytes:=0;var max_packet:=0;var reliable:=0;var frames:=120*tick_rate;var warmup:=3*tick_rate;var snapshot_clock:=0.0
		for frame in frames+warmup:
			var delta:=1.0/tick_rate;game.clock+=delta
			for id in game.players:
				var s:Dictionary=game.players[id];s.last_input=game.clock;s.input_blocked=false;s.fire=true;s.move=Vector2(sin((frame+id)*.006)*.35,cos((frame+id)*.004)*.35)
				s.yaw=id*.8+sin(frame*.003)*.3;s.pitch=.05;s.xr=preload("res://deathmatch/vr/poses.gd").neutral();s.vr_device=true
				if frame%120==0:s.ammo=[9999,9999,9999,9999];s.cooldown=0
			var begin:=Time.get_ticks_usec();game._server_tick(delta);var simulation:float=(Time.get_ticks_usec()-begin)/1000.0
			if frame>=warmup:
				series.simulation_ms.append(simulation);series.simulation_without_projectiles_ms.append(maxf(0,simulation-game.projectile_ms));series.projectiles_ms.append(game.projectile_ms);series.engine_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000);series.active_projectiles.append(game.projectiles.size())
			snapshot_clock+=delta
			if snapshot_clock>=.05:
				snapshot_clock=fmod(snapshot_clock,.05)
				begin=Time.get_ticks_usec();game._send_snapshot();var build:float=(Time.get_ticks_usec()-begin)/1000.0
				begin=Time.get_ticks_usec();var packets:Dictionary=encoder.packets(game.wire);var encode:float=(Time.get_ticks_usec()-begin)/1000.0
				if frame>=warmup:
					series.snapshot_build_ms.append(build);series.snapshot_encode_ms.append(encode)
					for packet in packets.normal:bytes+=packet.size()+64;max_packet=maxi(max_packet,packet.size())
					for packet in packets.large:bytes+=packet.size()+64;reliable+=1
			if frame>=warmup and frame%60==0:series.rss_mb.append(rss_mb());series.static_mb.append(OS.get_static_memory_usage()/1048576.0)
			await get_tree().physics_frame
		var result:Dictionary={"wall_seconds":(Time.get_ticks_usec()-case_started)/1000000.0,"achieved_tick_hz":(frames+warmup)*1000000.0/(Time.get_ticks_usec()-case_started),"players":count,"tick_rate":tick_rate,"seconds":120,"AI":false,"XR":false,"synthetic_tracked_poses":true,"rendering":false,"traffic":"20 Hz encoded snapshots; fanout estimate, not live transport","udp_max_bytes":max_packet,"reliable_packets":reliable,"per_client_snapshot_mbps":bytes*8.0/120/1000000,"aggregate_snapshot_mbps":bytes*8.0*count/120/1000000}
		for key in series:result[key]=Summary.summary(series[key])
		results.append(result);print("CQ_SERVER_CAPACITY_CASE ",JSON.stringify(result))
	var report:Dictionary={"host":"87.106.27.237; AMD EPYC-Milan, Ubuntu 24.04, 12 vCPU","target":"12 vCPU / 24 GB / 1 Gbps VPS","startup_seconds":startup,"terrain_side":game.battle_map.COLLISION_SIDE,"environment_colliders":game.battle_map.environment_colliders,"cases":results}
	DirAccess.make_dir_recursive_absolute("user://vps-validation")
	var file:=FileAccess.open("user://vps-validation/server-capacity.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CQ_SERVER_CAPACITY_RESULT ",JSON.stringify(report));game.disconnect_game();game.free();get_tree().quit()
