extends SceneTree
## Readiness probe only: trusted local calls, no public listener or integration flag.
const State=preload("res://tools/district_sim/state.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
func _initialize():
	Engine.max_fps=60
	create_timer(20).timeout.connect(func():quit(2))
	run.call_deferred()
func run() -> void:
	var report:={}
	var config=preload("res://deathmatch/server/config.gd")
	report.current_config_accepts_district_option=not config.parse("set sv_simulation districts").has("error")
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.dedicated=true
	game.start_host("Probe",0,100,60,true,"dm","quake")
	assert(game.active)
	for id in game.players.keys():game._peer_left(id)
	game.clock=100.0;game._add_player(42,"Human input probe")
	var s: Dictionary=game.players[42]
	var command: Dictionary={"seq":17,"move":Vector2(.5,0),"yaw":.2,"pitch":0.0,"fire":false,"weapon":s.weapon,"slow":false,"respawn":false,"input_life":s.serial,"view_time":99.92}
	game._accept_input(42,command)
	report.production_input_accepts_routed_human=(s.last_seq==17 and s.move==Vector2(.5,0))
	assert(report.production_input_accepts_routed_human)
	s.hp=73;s.armor=41;s.invulnerable=102.0;s.respawn_at=103.0
	var packet:=State.snapshot(game,0,1)
	var receiver:=Replication.new()
	report.raw_district_snapshot_accepted_by_production=receiver.receive(var_to_bytes(packet),game.map_epoch)
	assert(not report.raw_district_snapshot_accepted_by_production)
	# Reuse the real production serializer for a narrow local translation probe.
	game._send_snapshot()
	var production: Array=[]
	# Construct a minimal client-compatible baseline from real actor and mode state.
	# This verifies codec reuse; it is not a network gateway.
	var f=game.fighters[42]
	var rows: Array=[[42,f.position,f.velocity,s.yaw,s.pitch,s.hp,s.armor,s.dead,s.weapon,s.ammo,s.owned,s.kills,s.deaths,s.ping,s.serial,3.0,true,s.cooldown,s.xr,s.offhand_cooldown,s.spectator,f.blast_velocity]]
	var mode: Dictionary=game.match_mode.snapshot();mode.locomotion={42:f.locomotion_state()};mode.movement_ack={42:s.last_seq}
	production=[rows,PackedByteArray(),600.0,0.0,"",100,60,[],[],game.map_epoch,mode, {},100.0,0]
	var sender:=Replication.new();var frames:=sender.packets(production)
	for frame in frames.normal+frames.large:assert(receiver.receive(frame,game.map_epoch))
	var decoded:=receiver.flush();assert(not decoded.is_empty())
	report.production_codec_roundtrip_hp=decoded[0][0][5]
	report.production_codec_roundtrip_input_ack=decoded[10].movement_ack[42]
	assert(report.production_codec_roundtrip_hp==73 and report.production_codec_roundtrip_input_ack==17)
	s.fire_pending=[s.weapon,1,100.25]
	var transfer:=State.actor(game,42);game._peer_left(42);game.clock=800.0;State.restore(game,transfer)
	report.actor_identity_preserved=game.players.has(42)
	report.inventory_and_hp_preserved=game.players[42].hp==73 and game.players[42].armor==41
	report.relative_invulnerability_seconds=game.players[42].invulnerable-game.clock
	report.relative_respawn_seconds=game.players[42].respawn_at-game.clock
	report.buffered_fire_remaining_seconds=game.players[42].fire_pending[2]-game.clock
	report.view_timestamp_age_seconds=game.clock-game.players[42].view_time
	report.buffered_fire_deadline_preserved=is_equal_approx(report.buffered_fire_remaining_seconds,.25)
	report.view_time_preserved=is_equal_approx(report.view_timestamp_age_seconds,.08)
	assert(report.actor_identity_preserved and report.inventory_and_hp_preserved)
	assert(is_equal_approx(report.relative_invulnerability_seconds,2) and is_equal_approx(report.relative_respawn_seconds,3))
	report.scope="Local API/codec/clock probes; not a network playable-client test. False deadline/capability values are integration gaps."
	DirAccess.make_dir_recursive_absolute("res://test-results/district-sim")
	FileAccess.open("res://test-results/district-sim/integration-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DISTRICT_INTEGRATION_PROBE ",JSON.stringify(report))
	game.disconnect_game();game.queue_free();await process_frame;quit()
