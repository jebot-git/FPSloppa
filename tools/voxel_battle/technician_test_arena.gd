extends "res://tools/voxel_battle/class_arena.gd"
## Loopback-only technician fixture: low ammunition beside a damaged transport.
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
 if not OS.get_cmdline_user_args().has("--cq-technician-test"):
  push_error("Technician scene requires --cq-technician-test");get_tree().quit(2);return
 set_meta("cq_technician_test",true);super._ready()
 if dedicated:bot_population.count_target=0
func start_join(player_name:String,address:String,port:int,spectator:bool=false)->void:
 if address not in ["127.0.0.1","localhost","::1"]:
  push_error("Technician fixture connects only to a local test server.");get_tree().quit(2);return
 super.start_join(player_name,address,port,spectator)
func _process(delta:float)->void:
 super._process(delta)
 if resident.serving() or not active or resident.client_frame.is_empty():return
 var mine:int=multiplayer.get_unique_id()
 if not fixture_ready and clock>=fixture_request_at:
  fixture_request_at=clock+1.;_reset_technician_test.rpc_id(1,map_epoch)
 var state:Dictionary=resident.client_frame.players.get(mine,{})
 if state.is_empty() or state["class"].role!=3:return
 var vehicles:Array=resident.client_frame.get("vehicles",{}).values().filter(func(v):return v.kind==3 and v.team==state.team and v.hp>0 and v.hp<100 and v.position.distance_to(state.position)<8)
 if vehicles.is_empty():return
 var vehicle:Dictionary=vehicles[0]
 if not fixture_ready:
  fixture_ready=true;desired_weapon=state.weapon
  if loadout_menu:loadout_menu.pending=false;loadout_menu.calibration_confirmed=true
  if xr_rig:xr_rig.calibration_pending=false;xr_rig.recenter()
  menu_open=false
  if hud:
   hud.show_menu(false);hud.button(hud.menu_pages.pages.home,"RESET TECHNICIAN TEST",func():_reset_technician_test.rpc_id(1,map_epoch))
  print("CQ_TECHNICIAN_TEST_CLIENT_READY ",JSON.stringify({"ammo":state.ammo,"vehicle_hp":vehicle.hp}))
 var args:=OS.get_cmdline_user_args();var index:=args.find("--technician-test-check")
 if index>=0 and not fixture_checks_done:
  fixture_checks_done=true
  var failures:Array=[]
  if state.ammo[2]!=3 or state.ammo[0]!=1 or state.staging or state.dead:failures.append("low ammunition deployed technician")
  if players[mine].team!=state.team:failures.append("presentation team matches native team")
  if vehicle.hp!=40:failures.append("nearby damaged allied transport")
  var row:Dictionary={"ammo":state.ammo,"role":state["class"].role,"vehicle_hp":vehicle.hp,"distance":vehicle.position.distance_to(state.position),"failures":failures}
  if index+1<args.size():var file:=FileAccess.open(args[index+1],FileAccess.WRITE);file.store_string(JSON.stringify(row,"\t"));file.close()
  print("CQ_TECHNICIAN_TEST_CHECK ",JSON.stringify(row));finish_check.call_deferred(0 if failures.is_empty() else 1)
@rpc("any_peer","call_remote","reliable",0)
func _reset_technician_test(epoch:int)->void:
 if not resident.serving() or epoch!=map_epoch or clock<fixture_reset_at:return
 var id:int=multiplayer.get_remote_sender_id()
 if id<=1 or not resident.lives.has(id):return
 var row:Dictionary=resident.core.prepare_technician_test(id)
 if row.is_empty():return
 players[id].team=row.technician.team
 resident.lives[id]=row.technician.life;fixture_reset_at=clock+2.
 print("CQ_TECHNICIAN_TEST_READY ",JSON.stringify({"technician":id,"ammo":row.technician.ammo,"vehicle_hp":row.vehicle_hp}))
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8 and active and not resident.serving():
  _reset_technician_test.rpc_id(1,map_epoch);return
 super._unhandled_input(event)
func finish_check(code:int)->void:
 disconnect_game();await get_tree().process_frame;get_tree().quit(code)
