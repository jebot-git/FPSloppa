extends SceneTree
var game
var checks:=0
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle():
	for i in 5:await process_frame
func shot(name:String):
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cq-squads/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute("/tmp/cq-squads")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.process_mode=Node.PROCESS_MODE_DISABLED
	game.active=true;game.voice_enabled=true;game.voice.mode=1;game.match_mode.kind="tdm"
	var f:Dictionary={"mode":{"time":100.,"winner":-2,"zones":[]},"players":{},"vehicles":{}}
	for i in game.match_mode.objectives.sites.size():
		f.mode.zones.append({"position":game.match_mode.objectives.sites[i].position,"owner":i%3-1,"contested":i==3,"progress":[3.,0.]})
	for i in range(1,6):
		var team:=0 if i<5 else 1;var squad:=1 if i==4 else 0
		var p:Dictionary=game._new_state("Pilot %d"%i,i);p.team=team;p.serial=10+i;game.players[i]=p
		game.classes.states[i]={"squad":squad,"class":"shocktroop","next":"shocktroop"}
		f.players[i]={"id":i,"life":10+i,"team":team,"squad":squad,"dead":false,"incapacitated":false,"staging":i==1,"respawn_at":0.,"combat_until":0.,"vehicle":-1,"position":Vector3(-500+i*90,30,-450+i*70)}
	game.resident.client_frame=f
	var service=game.squads;var screen=service.screen
	game.loadout_menu.pending=false
	service.open_map();await shot("deployment-map")
	check(screen.squad_buttons.size()==4 and screen.squad_buttons[0].text=="ALPHA 3/8","four squad join controls show authoritative membership counts")
	check(screen.members().size()==2,"overview only exposes same-squad members")
	check(screen.deploy.get_global_rect().end.y<=640 and screen.map.size.x>=360,"map and deployment controls fit 960×640")
	check(service.reason(0).is_empty(),"squad member can use team insertion")
	f.players[1].squad=-1;game.classes.states[1].squad=-1
	check("squad" in service.reason(0).to_lower(),"squad membership is mandatory")
	f.players[1].squad=0;game.classes.states[1].squad=0
	check(service.reason(1,1).is_empty(),"friendly controlled POI is eligible")
	check(not service.reason(1,2).is_empty(),"opponent POI is refused")
	f.mode.zones[1].contested=true
	check("contested" in service.reason(1,1),"contested controlled POI is refused")
	f.mode.zones[1].contested=false
	check(service.reason(2,2,12).is_empty(),"active squad buddy is eligible")
	f.players[2].combat_until=107.
	check("combat" in service.reason(2,2,12),"combat buddy is refused")
	f.players[2].combat_until=0.
	check(not service.reason(2,2,99).is_empty(),"stale buddy life is refused")
	check(not service.reason(2,4,14).is_empty(),"another squad is refused")
	f.players[2].vehicle=0;f.vehicles[10]={"index":0,"kind":0,"team":0,"hp":100.,"pilot":2}
	check("tank" in service.reason(2,2,12),"tank-driver spawn is refused")
	f.vehicles[10].kind=3
	check(service.reason(2,2,12).is_empty(),"transport with a passenger vacancy is eligible")
	for i in range(6,12):f.players[i]={"vehicle":0,"vehicle_seat":0}
	check("full" in service.reason(2,2,12),"full transport is refused")
	for i in range(6,12):f.players.erase(i)
	f.players[1].staging=false;f.players[1].dead=true;f.players[1].respawn_at=102.
	check("Reinforcements" in service.reason(0),"respawn delay is visible on the map")
	f.players[1].respawn_at=99.
	check(service.reason(0).is_empty(),"dead squad member may deploy after delay")
	game.loadout_menu.pending=true;game.loadout_menu.calibration_confirmed=false
	check("alignment" in service.reason(0),"initial deployment retains avatar confirmation gate")
	game.loadout_menu.pending=false
	game.hud.menu_pages.navigate("home");service._process(.1)
	check(game.hud.menu_pages.current=="cq_deployment","death presents tactical map automatically")
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=screen.map.project(f.mode.zones[1].position)
	screen.map._gui_input(event)
	check(screen.selected=="p:1","selecting a POI map marker chooses spawn target")
	await shot("controlled-poi")
	event.position=screen.map.project(f.players[3].position);screen.map._gui_input(event)
	check(screen.selected=="m:3:13","selecting a teammate map marker chooses that life-bound squad spawn")
	check(screen.selection()==[2,3,13] and service.reason(2,3,13).is_empty(),"teammate click updates deployment target and eligibility")
	await shot("squad-buddy")
	check(game.voice.recipients(1,true,1)==[2,3],"squad radio routes only to other same-squad players")
	check(game.voice.recipients(1,true,2)==[2,3,4],"team radio reaches other squads without reaching enemies")
	game.players[5].team=0
	check(not game.voice.recipients(1,true,2).has(5),"native team membership overrides stale presentation roster for radio privacy")
	game.players[5].team=1
	check(game.voice.recipients(1,false,0)==[2,3,4,5],"proximity voice retains its existing audience")
	check(game.voice.recipients(1,false,1).is_empty(),"malformed radio scope cannot bypass routing")
	game.voice.radio_trigger(true)
	check(game.voice.radio_mode==1 and game.voice.radio_scope()==1,"one trigger press selects squad radio")
	game.voice.radio_trigger(false);game.voice.radio_trigger(true)
	check(game.voice.radio_mode==2 and game.voice.radio_scope()==2,"second trigger within double-tap window selects team radio")
	game.voice.radio_trigger(false);game.voice.radio_last_press=-1000.;game.voice.radio_trigger(true)
	check(game.voice.radio_scope()==1,"later single press returns to squad radio")
	game.voice.radio_trigger(false)
	game.voice.test_receive=true
	var opus=preload("res://deathmatch/tests/opus_fixture.gd");var packet:PackedByteArray=opus.packet(opus.encoder())
	game.voice.receive(2,10,packet,true,1)
	check(game.voice.streams.has(2) and game.voice.streams[2].scope==1,"squad packet creates nonpositional squad audio stream")
	game.voice.receive(2,12,packet,true,2)
	check(game.voice.streams[2].scope==2,"team packet changes radio scope")
	var received:int=game.voice.received_packets;game.voice.receive(2,11,packet,true,1)
	check(game.voice.received_packets==received and game.voice.streams[2].scope==2,"reordered squad packet cannot restore an older channel")
	game.voice.receive(2,13,packet,true,1);game.classes.states[2].squad=1
	game.voice._process(.02)
	check(not game.voice.streams.has(2),"squad membership change flushes private queued audio")
	game.voice.receive(2,14,packet,true,1)
	check(not game.voice.streams.has(2),"receiver rejects former-squad audio after membership change")
	game.voice.receive(5,14,packet,true,2)
	check(not game.voice.streams.has(5),"receiver rejects enemy team-radio audio")
	game.players[1].dead=false;game.players[1].spectator=false;game._create_fighter(1);game.fighters[1].set_process(false);game.fighters[1].set_physics_process(false);game.fighters[1].position=Vector3(-400,0,-400);game.local_yaw=PI/2
	game.menu_open=false;game.hud.menu.hide();game.hud.hud.show()
	var tactical=game.hud.tactical_map;tactical.show();tactical.overview.queue_redraw();await shot("combat-map")
	var at:Vector2=tactical.overview.get_global_transform_with_canvas()*tactical.overview.project(game.fighters[1].render_position())
	var pixel:Color=root.get_texture().get_image().get_pixelv(Vector2i(at-Vector2(4,0)))
	check(pixel.r>.7 and pixel.g>.7 and pixel.b>.7,"combat map renders own position and west-pointing heading")
	check(tactical.overview.read_only,"combat map cannot issue spawn requests")
	game.active=false;game.players.clear();game.queue_free();await settle()
	print("CQ_SQUADS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
