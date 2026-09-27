extends SceneTree
const Opus=preload("res://deathmatch/tests/opus_fixture.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Dead observer",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	var de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0)
	g._add_player(-4,"Observer",true);g._add_player(-5,"Live T");g.players[-5].team=0
	g.players[1].dead=true;g.players[1].hp=0;g.players[-1].dead=true;g.players[-1].hp=0
	var corpse: Vector3=g.fighters[1].position;var serial: int=g.players[1].serial;var team: int=g.players[1].team
	de.move_observer({"move":Vector2.RIGHT,"fly":1.0,"yaw":0.0,"slow":false},1.0)
	check(de.observing() and de.observer_position.distance_to(corpse)>6.9,"Killed DE player can freely spectate")
	check(g.fighters[1].position==corpse and g.players[1].serial==serial and g.players[1].team==team and not g.players[1].spectator,"Spectating preserves corpse, life and team membership")
	g._accept_input(1,{"seq":1,"move":Vector2.ZERO,"fly":0.0,"yaw":0.0,"pitch":0.0,"fire":true,"offhand_fire":true,"alt_fire":true,"melee":true,"weapon":1,"slow":false,"respawn":true})
	check(not g.players[1].fire and not g.players[1].melee and not g.players[1].want_respawn,"Dead spectator input cannot shoot or respawn")
	var shots: int=g.players[1].shots;g._fire(1);g._collect(1)
	check(g.players[1].shots==shots and g.players[1].hp==0,"Dead observer cannot interact with the match")
	g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	var rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false;g.menu_open=false
	rig._process(.016)
	check(rig.global_position.is_equal_approx(de.observer_position) and not rig.blackout.visible and not rig.gun.visible,"VR observer camera moves without wall blackout or weapons")
	var tracker:=XRControllerTracker.new();tracker.name=&"right_hand";tracker.type=XRServer.TRACKER_CONTROLLER;XRServer.add_tracker(tracker);tracker.set_input("primary",Vector2(0,1))
	check(rig.command(2).fly==1.0,"Right stick vertical axis flies while dead in VR")
	g.menu_open=true;check(rig.command(3).fly==0.0 and rig.command(3).move==Vector2.ZERO,"VR menu stops spectator flight")
	g.menu_open=false;XRServer.remove_tracker(tracker)
	# Both dead teams and explicit spectators share one channel. Living players remain separate.
	for sender in g.players:
		for listener in g.players:
			for radio in [false,true]:
				var a: Dictionary=g.players[sender];var b: Dictionary=g.players[listener]
				var dead_a: bool=a.dead or a.spectator;var dead_b: bool=b.dead or b.spectator
				var expected: bool=dead_a==dead_b and (dead_a or not radio or a.team==b.team)
				check(g.voice.can_hear(sender,listener,radio)==expected,"Communication matrix %d → %d radio=%s"%[sender,listener,radio])
	g.chat_feed.clear();g.clock+=1;g._chat_for(-1,"dead room",true)
	check(g.chat_feed.any(func(row):return row.text.contains("[DEAD]") and row.text.contains("dead room")),"Dead cross-team text reaches dead local player")
	g.chat_feed.clear();g.clock+=1;g._chat_for(-2,"living room",false)
	check(g.chat_feed.is_empty(),"Live global text does not enter dead channel")
	g.voice.test_receive=true;var packet:=Opus.packet(Opus.encoder())
	g.voice._receive_audio(-1,1,packet,false,true,serial,de.round_id)
	check(g.voice.streams.has(-1) and g.voice.streams[-1].dead,"Real Opus dead voice creates a playback stream")
	g.voice.remove_stream(-1);g.headless=false;g.voice.create_stream(-1,2,false,true,serial,de.round_id);g.headless=true
	check(g.voice.streams[-1].player is AudioStreamPlayer and not g.voice.streams[-1].player is AudioStreamPlayer3D,"Dead voice is audible independent of corpse/camera distance")
	g.players[1].dead=false;g.players[1].hp=100;g.voice._process(0)
	check(not g.voice.streams.has(-1),"Revival immediately discards queued dead audio")
	var before: int=g.voice.received_packets;g.voice._receive_audio(-1,3,packet,false,true,serial,de.round_id)
	check(g.voice.received_packets==before,"In-flight dead packet cannot play to a living player")
	g.chat_feed.clear();g.clock+=1;g._chat_for(-1,"cannot ghost",false)
	check(g.chat_feed.is_empty(),"Dead global text cannot reach living host")
	check(de.observer_origin(corpse)==corpse and de.observer_life.is_empty(),"Revival returns camera to authoritative fighter")
	g.players[1].dead=true;de.begin_round();check(not g.players[1].dead and not g.players[1].spectator and g.players[1].team==team,"Next round respawns dead observer on original team")
	g.players[1].dead=true;g.players[-1].dead=true
	g.voice._receive_audio(-1,4,packet,false,true,serial,de.round_id-1)
	check(g.voice.received_packets==before,"Old life/round packet remains rejected even after another death")
	g.players[1].dead=false;g.voice._receive_audio(-2,5,packet,false,false,g.players[1].serial,de.round_id)
	check(g.voice.streams.has(-2),"Living proximity stream still works")
	g.players[1].dead=true;g.voice._process(0);check(not g.voice.streams.has(-2),"Death flushes queued living audio")
	g.match_mode.kind="tdm"
	check(g.voice.can_hear(-1,1,false) and not de.observing(),"Other modes retain existing voice and respawn behavior")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/observer.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_OBSERVER_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
