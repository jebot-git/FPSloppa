extends "res://tools/voxel_battle/class_arena.gd"
## Explicit local native test fixture; never modifies a deployed server.
class PassivePatients extends Node:
 var ready_to_walk:=false
 var brains:Dictionary={}
 var teamplay=null
 func setup(_arena):pass
 func tick(_delta):pass
func create_bot_controller()->Node:return PassivePatients.new()
var fixture_request_at:=0.
var fixture_ready:=false
var fixture_reset_at:=0.
var fixture_checks_done:=false
func _ready()->void:
 if not OS.get_cmdline_user_args().has("--cq-medic-test"):
  push_error("Medic test scene requires --cq-medic-test");get_tree().quit(2);return
 set_meta("cq_medic_test",true)
 super._ready()
 if dedicated:bot_population.count_target=1
func start_join(player_name:String,address:String,port:int,spectator:bool=false)->void:
 if address not in ["127.0.0.1","localhost","::1"]:
  push_error("Medic fixture connects only to a local test server.");get_tree().quit(2);return
 super.start_join(player_name,address,port,spectator)
func _process(delta:float)->void:
 super._process(delta)
 if resident.serving() or not active or resident.client_frame.is_empty():return
 var mine:int=multiplayer.get_unique_id()
 if not fixture_ready and clock>=fixture_request_at:
  fixture_request_at=clock+1.;_reset_medic_test.rpc_id(1,map_epoch)
 var state:Dictionary=resident.client_frame.players.get(mine,{})
 var patients:Array=resident.client_frame.players.keys().filter(func(id):return id<0)
 if state.is_empty() or state["class"].role!=2 or patients.is_empty():return
 var patient:Dictionary=resident.client_frame.players[patients[0]]
 if not fixture_ready:
  fixture_ready=true;desired_weapon=state.weapon
  if loadout_menu:loadout_menu.pending=false;loadout_menu.calibration_confirmed=true
  if xr_rig:xr_rig.calibration_pending=false;xr_rig.recenter()
  menu_open=false
  if hud:
   hud.show_menu(false);hud.button(hud.menu_pages.pages.home,"RESET MEDIC TEST",func():_reset_medic_test.rpc_id(1,map_epoch))
  print("CQ_MEDIC_TEST_CLIENT_READY ",JSON.stringify({"hp":state.hp,"patient_hp":patient.hp,"incapacitated":patient.incapacitated}))
 var args:=OS.get_cmdline_user_args();var index:=args.find("--medic-test-check")
 if index>=0 and not fixture_checks_done:
  fixture_checks_done=true
  var failures:Array=[]
  if state.hp!=35 or state.armor!=0 or state.staging or state.dead:failures.append("medic low-health deployed state")
  if patient.hp!=1 or not patient.incapacitated or patient.dead or patient.team!=state.team:failures.append("nearby low-health allied incapacitated bot")
  if players[mine].team!=state.team or players[patients[0]].team!=patient.team:failures.append("presentation team matches native team")
  if patient.position.distance_to(state.position)>2.:failures.append("patient within interaction distance")
  var row:Dictionary={"medic_hp":state.hp,"medic_role":state["class"].role,"patient_hp":patient.hp,"patient_incapacitated":patient.incapacitated,"distance":patient.position.distance_to(state.position),"failures":failures}
  if index+1<args.size():var file:=FileAccess.open(args[index+1],FileAccess.WRITE);file.store_string(JSON.stringify(row,"\t"));file.close()
  print("CQ_MEDIC_TEST_CHECK ",JSON.stringify(row));finish_check.call_deferred(0 if failures.is_empty() else 1)
@rpc("any_peer","call_remote","reliable",0)
func _reset_medic_test(epoch:int)->void:
 if not resident.serving() or epoch!=map_epoch or clock<fixture_reset_at:return
 var id:int=multiplayer.get_remote_sender_id()
 if id<=1 or not resident.lives.has(id):return
 var patients:Array=players.keys().filter(func(peer):return peer<0 and resident.lives.has(peer))
 if patients.is_empty():return
 var patient:int=patients[0]
 var row:Dictionary=resident.core.prepare_medic_test(id,patient)
 if row.is_empty():return
 players[id].team=row.medic.team;players[patient].team=row.patient.team
 resident.lives[id]=row.medic.life;resident.lives[patient]=row.patient.life
 fixture_reset_at=clock+2.
 print("CQ_MEDIC_TEST_READY ",JSON.stringify({"medic":id,"hp":row.medic.hp,"patient":patient,"patient_hp":row.patient.hp,"bleed_seconds":row.patient.bleed_remaining}))
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8 and active and not resident.serving():
  _reset_medic_test.rpc_id(1,map_epoch);return
 super._unhandled_input(event)

func finish_check(code:int)->void:
 disconnect_game()
 await get_tree().process_frame
 get_tree().quit(code)
