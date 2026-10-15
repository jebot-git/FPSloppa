extends "res://tools/voxel_battle/class_arena.gd"
## Scout fixture only: show the real allied technician's designation solution to scout.
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
var preview_next:=0.
var preview_technician:=0
var preview_points:=PackedVector3Array()
var preview_mesh:MeshInstance3D
func _ready()->void:
 if not OS.get_cmdline_user_args().has("--cq-scout-test"):
  push_error("Scout scene requires --cq-scout-test");get_tree().quit(2);return
 set_meta("cq_scout_test",true);super._ready()
 if dedicated:bot_population.count_target=1
func start_join(player_name:String,address:String,port:int,spectator:bool=false)->void:
 if address not in ["127.0.0.1","localhost","::1"]:
  push_error("Scout fixture connects only to a local test server.");get_tree().quit(2);return
 super.start_join(player_name,address,port,spectator)
func _process(delta:float)->void:
 super._process(delta)
 if resident.serving() or not active or resident.client_frame.is_empty():return
 var mine:int=multiplayer.get_unique_id()
 if not fixture_ready and clock>=fixture_request_at:
  fixture_request_at=clock+1.;_reset_scout_test.rpc_id(1,map_epoch)
 var state:Dictionary=resident.client_frame.players.get(mine,{})
 var allies:Array=resident.client_frame.players.keys().filter(func(id):return id<0 and resident.client_frame.players[id]["class"].role==3)
 if state.is_empty() or state["class"].role!=1 or allies.is_empty():return
 preview_technician=allies[0]
 var technician:Dictionary=resident.client_frame.players[preview_technician]
 if not fixture_ready:
  fixture_ready=true;desired_weapon=state.weapon
  if loadout_menu:loadout_menu.pending=false;loadout_menu.calibration_confirmed=true
  if xr_rig:xr_rig.calibration_pending=false;xr_rig.recenter()
  menu_open=false
  if hud:
   hud.show_menu(false);hud.button(hud.menu_pages.pages.home,"RESET SCOUT TEST",func():_reset_scout_test.rpc_id(1,map_epoch))
  print("CQ_SCOUT_TEST_CLIENT_READY ",JSON.stringify({"primary":state.weapon,"utility":"cloak","technician":preview_technician,"technician_distance_xz":Vector2(technician.position.x-state.position.x,technician.position.z-state.position.z).length()}))
 var args:=OS.get_cmdline_user_args();var index:=args.find("--scout-test-check")
 if index>=0 and not fixture_checks_done:
  fixture_checks_done=true
  var failures:Array=[]
  if state.weapon!=9 or not state.owned.has(8) or state.armor!=0 or state.staging or state.dead:failures.append("deployed scout scoped pistol/designator/cloak")
  if players[mine].team!=state.team or technician.team!=state.team or players[preview_technician].team!=state.team:failures.append("allied native/presentation teams")
  var distance:=Vector2(technician.position.x-state.position.x,technician.position.z-state.position.z).length()
  if absf(distance-100.)>.1:failures.append("technician one hundred metres behind scout")
  var config:Dictionary=preload("res://deathmatch/conquest/classes/designation_guide.gd").profile(self,preview_technician)
  if config.is_empty() or config.get("speed",0)!=55. or config.get("gravity",0)!=12.:failures.append("real technician Massacre guide profile")
  var row:Dictionary={"role":state["class"].role,"weapon":state.weapon,"owned":state.owned,"technician_distance_xz":distance,"guide_profile":config,"failures":failures}
  if index+1<args.size():var file:=FileAccess.open(args[index+1],FileAccess.WRITE);file.store_string(JSON.stringify(row,"\t"));file.close()
  print("CQ_SCOUT_TEST_CHECK ",JSON.stringify(row));finish_check.call_deferred(0 if failures.is_empty() else 1)
func draw_class_tools()->void:
 super.draw_class_tools()
 if headless or not active or preview_technician==0 or not fighters.has(preview_technician):return
 if clock>=preview_next:
  preview_next=clock+.1
  var guide=preload("res://deathmatch/conquest/classes/designation_guide.gd")
  var solution:Dictionary=guide.for_player(self,preview_technician)
  preview_points=guide.points(solution)
  # Keep the technician's real trajectory, but present its aiming cross locally.
  # Otherwise the cross sits behind the scout at the remote launcher position.
  if not solution.is_empty():
   var offset:Vector3=_shot_solution(multiplayer.get_unique_id()).origin-solution.origin
   for index in range(preview_points.size()-4,preview_points.size()):preview_points[index]+=offset
 preview_mesh=line_visual(preview_points,Color(.4,1,.8,.85),preview_mesh,.012)
@rpc("any_peer","call_remote","reliable",0)
func _reset_scout_test(epoch:int)->void:
 if not resident.serving() or epoch!=map_epoch or clock<fixture_reset_at:return
 var id:int=multiplayer.get_remote_sender_id()
 if id<=1 or not resident.lives.has(id):return
 var allies:Array=players.keys().filter(func(peer):return peer<0 and resident.lives.has(peer))
 if allies.is_empty():return
 var technician:int=allies[0];var row:Dictionary=resident.core.prepare_scout_test(id,technician)
 if row.is_empty():return
 players[id].team=row.scout.team;players[technician].team=row.technician.team
 resident.lives[id]=row.scout.life;resident.lives[technician]=row.technician.life;fixture_reset_at=clock+2.
 print("CQ_SCOUT_TEST_READY ",JSON.stringify({"scout":id,"technician":technician,"technician_position":row.technician.position}))
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8 and active and not resident.serving():
  _reset_scout_test.rpc_id(1,map_epoch);return
 super._unhandled_input(event)
func finish_check(code:int)->void:
 disconnect_game();await get_tree().process_frame;get_tree().quit(code)
