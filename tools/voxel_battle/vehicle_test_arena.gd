extends "res://tools/voxel_battle/class_arena.gd"
## Isolated vehicle lineup; maximum current unlock level on all four classes.
class Passive extends Node:
 var ready_to_walk:=false
 var brains:Dictionary={}
 var teamplay=null
 func setup(_arena):pass
 func tick(_delta):pass
func create_bot_controller()->Node:return Passive.new()
var fixture_ready:=false
var request_at:=0.
var reset_at:=0.
var checked:=false
func _ready()->void:
 if not OS.get_cmdline_user_args().has("--cq-vehicle-test"):
  push_error("Vehicle fixture requires --cq-vehicle-test");get_tree().quit(2);return
 set_meta("cq_vehicle_test",true);super._ready()
 if dedicated:bot_population.count_target=0
func start_join(player_name:String,address:String,port:int,spectator:bool=false)->void:
 if address not in ["127.0.0.1","localhost","::1"]:
  push_error("Vehicle test is loopback only");get_tree().quit(2);return
 super.start_join(player_name,address,port,spectator)
func _process(delta:float)->void:
 super._process(delta)
 if resident.serving() or not active or resident.client_frame.is_empty():return
 var mine:int=multiplayer.get_unique_id()
 var state:Dictionary=resident.client_frame.players.get(mine,{})
 if state.is_empty():return
 var unlocked:bool=state["class"].xp.all(func(xp):return xp>=7500)
 if not fixture_ready and not unlocked and clock>=request_at:
  request_at=clock+1.;_reset_vehicle_test.rpc_id(1,map_epoch)
 if not unlocked or state.staging:return
 var nearby:Array=resident.client_frame.get("vehicles",{}).values().filter(func(v):return v.hp>0 and v.position.distance_to(state.position)<50.)
 if not fixture_ready:
  if nearby.size()<5:return
  fixture_ready=true;desired_weapon=state.weapon
  if loadout_menu:loadout_menu.pending=false;loadout_menu.calibration_confirmed=true
  if xr_rig:xr_rig.calibration_pending=false;xr_rig.recenter()
  menu_open=false
  if hud:
   hud.show_menu(false);hud.button(hud.menu_pages.pages.home,"RESET VEHICLE TEST",func():_reset_vehicle_test.rpc_id(1,map_epoch))
  print("CQ_VEHICLE_TEST_CLIENT_READY ",JSON.stringify({"xp":state["class"].xp,"level":15,"nearby_vehicles":nearby.size(),"total_vehicles":resident.client_frame.vehicles.size()}))
 var args:=OS.get_cmdline_user_args();var index:=args.find("--vehicle-test-check")
 if index>=0 and not checked:
  checked=true
  var kinds:Array=nearby.map(func(v):return v.kind);var failures:Array=[]
  for kind in 5:
   if not kinds.has(kind):failures.append("missing vehicle type "+str(kind))
  if not unlocked or state.staging or state.dead:failures.append("max progression deployed player")
  var result:Dictionary={"xp":state["class"].xp,"role":state["class"].role,"nearby":kinds,"total_vehicles":resident.client_frame.vehicles.size(),"failures":failures}
  if index+1<args.size():var file:=FileAccess.open(args[index+1],FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
  print("CQ_VEHICLE_TEST_CHECK ",JSON.stringify(result));finish.call_deferred(0 if failures.is_empty() else 1)
@rpc("any_peer","call_remote","reliable",0)
func _reset_vehicle_test(epoch:int)->void:
 if not resident.serving() or epoch!=map_epoch or clock<reset_at:return
 var id:int=multiplayer.get_remote_sender_id()
 if id<=1 or not resident.lives.has(id):return
 var result:Dictionary=resident.core.prepare_vehicle_test(id)
 if result.is_empty():return
 players[id].team=result.player.team;resident.lives[id]=result.player.life;reset_at=clock+2.
 print("CQ_VEHICLE_TEST_READY ",JSON.stringify({"player":id,"xp":result.player["class"].xp if result.player.has("class") else [7500,7500,7500,7500],"vehicles":result.vehicles}))
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8 and active and not resident.serving():
  _reset_vehicle_test.rpc_id(1,map_epoch);return
 super._unhandled_input(event)
func finish(code:int)->void:
 disconnect_game();await get_tree().process_frame;get_tree().quit(code)
