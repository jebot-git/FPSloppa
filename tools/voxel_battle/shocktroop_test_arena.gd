extends "res://tools/voxel_battle/class_arena.gd"
## Loopback-only shocktrooper fixture with the standard starter loadout.
class Passive extends Node:
 var ready_to_walk:=false
 var brains:Dictionary={}
 var teamplay=null
 func setup(_arena):pass
 func tick(_delta):pass
func create_bot_controller()->Node:return Passive.new()
var fixture_request_at:=0.
var fixture_ready:=false
var fixture_reset_at:=0.
var fixture_checks_done:=false
func _ready()->void:
 if not OS.get_cmdline_user_args().has("--cq-shocktroop-test"):
  push_error("Shocktroop scene requires --cq-shocktroop-test");get_tree().quit(2);return
 set_meta("cq_shocktroop_test",true);super._ready()
 if dedicated:bot_population.count_target=0
func start_join(player_name:String,address:String,port:int,spectator:bool=false)->void:
 if address not in ["127.0.0.1","localhost","::1"]:
  push_error("Shocktroop fixture connects only to a local test server.");get_tree().quit(2);return
 super.start_join(player_name,address,port,spectator)
func _process(delta:float)->void:
 super._process(delta)
 if resident.serving() or not active or resident.client_frame.is_empty():return
 var mine:int=multiplayer.get_unique_id()
 if not fixture_ready and clock>=fixture_request_at:
  fixture_request_at=clock+1.;_reset_shocktroop_test.rpc_id(1,map_epoch)
 var state:Dictionary=resident.client_frame.players.get(mine,{})
 if state.is_empty() or state["class"].role!=0 or state.staging:return
 if not fixture_ready:
  fixture_ready=true;desired_weapon=state.weapon
  if loadout_menu:loadout_menu.pending=false;loadout_menu.calibration_confirmed=true
  if xr_rig:xr_rig.calibration_pending=false;xr_rig.recenter()
  menu_open=false
  if hud:
   hud.show_menu(false);hud.button(hud.menu_pages.pages.home,"RESET SHOCKTROOP TEST",func():_reset_shocktroop_test.rpc_id(1,map_epoch))
  print("CQ_SHOCKTROOP_TEST_CLIENT_READY ",JSON.stringify({"ammo":state.ammo,"hp":state.hp,"armor":state.armor}))
 var args:=OS.get_cmdline_user_args();var index:=args.find("--shocktroop-test-check")
 if index>=0 and not fixture_checks_done:
  fixture_checks_done=true
  var failures:Array=[]
  if state.hp!=100 or state.armor!=100 or state.staging or state.dead:failures.append("healthy deployed shocktrooper")
  if state.grenades!=3:failures.append("three-grenade shocktrooper loadout")
  if players[mine].team!=state.team:failures.append("presentation team matches native team")
  var row:Dictionary={"ammo":state.ammo,"role":state["class"].role,"hp":state.hp,"armor":state.armor,"grenades":state.grenades,"failures":failures}
  if args.has("--shocktroop-grenade-check"):
   row["grenade"]=await check_grenade()
   if not row.grenade.detonation:failures.append("native grenade arm, flight and detonation event")
   elif not headless:
    row.grenade["visual_shapes"]=variant_visuals.shapes.size() if is_instance_valid(variant_visuals) else 0
    await get_tree().process_frame
    row.grenade["audio_sources"]=spatial.active.filter(is_instance_valid).map(func(voice):return {"kind":voice.get_meta("sound_kind",""),"stream":voice.stream.resource_path if voice.stream else "","playing":voice.playing,"position":voice.global_position})
    row.grenade["audible"]=spatial.active.any(func(voice):return is_instance_valid(voice) and voice.get_meta("sound_kind","")=="cq_field_ordnance_impact" and voice.stream!=null and voice.playing)
    if row.grenade.visual_shapes<2 or not row.grenade.audible:failures.append("grenade detonation creates visible blast and playing spatial sound")
    set_process(false);camera.global_position=row.grenade.position+Vector3(0,2,7);camera.look_at(row.grenade.position)
    await get_tree().process_frame;await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(args[index+1]+".png")
  if index+1<args.size():var file:=FileAccess.open(args[index+1],FileAccess.WRITE);file.store_string(JSON.stringify(row,"\t"));file.close()
  print("CQ_SHOCKTROOP_TEST_CHECK ",JSON.stringify(row));finish_check.call_deferred(0 if failures.is_empty() else 1)
@rpc("any_peer","call_remote","reliable",0)
func _reset_shocktroop_test(epoch:int)->void:
 if not resident.serving() or epoch!=map_epoch or clock<fixture_reset_at:return
 var id:int=multiplayer.get_remote_sender_id()
 if id<=1 or not resident.lives.has(id):return
 var row:Dictionary=resident.core.prepare_shocktroop_test(id)
 if row.is_empty():return
 players[id].team=row.team
 resident.lives[id]=row.life;fixture_reset_at=clock+2.
 print("CQ_SHOCKTROOP_TEST_READY ",JSON.stringify({"shocktroop":id,"ammo":row.ammo,"armor":row.armor}))
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8 and active and not resident.serving():
  _reset_shocktroop_test.rpc_id(1,map_epoch);return
 super._unhandled_input(event)
func finish_check(code:int)->void:
 disconnect_game();await get_tree().process_frame;get_tree().quit(code)
func check_grenade()->Dictionary:
 var mine:int=multiplayer.get_unique_id()
 # Let the first unblocked input reach the authority after closing deployment.
 await get_tree().create_timer(.5).timeout
 var count:int=resident.client_frame.players.get(mine,{}).get("grenades",-1)
 resident.request(2,2)
 var deadline:=Time.get_ticks_msec()+2000
 var primed:=false
 while Time.get_ticks_msec()<deadline:
  await get_tree().process_frame
  if resident.client_frame.players.get(mine,{}).get("grenade_primed",false):primed=true;break
 if not primed:return {"primed":false,"flight":false,"detonation":false,"initial_count":count,"state":resident.client_frame.players.get(mine,{})}
 resident.request(3)
 var flight:=false
 deadline=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<deadline:
  await get_tree().process_frame
  for grenade_state in resident.client_frame.get("grenades",{}).values():
   if grenade_state.owner==mine:flight=true
  for event in resident.client_frame.get("events",{}).values():
   if event.kind==8 and event.actor==mine:return {"primed":primed,"flight":flight,"detonation":true,"position":event.position}
 return {"primed":primed,"flight":flight,"detonation":false}
