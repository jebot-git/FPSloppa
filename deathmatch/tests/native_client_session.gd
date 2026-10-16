extends SceneTree
var checks:=0
var failures:Array=[]
class Actor extends CharacterBody3D:
 var label=Node3D.new()
 var nametag:Array=[]
 var nametag_updates:=0
 func _init():add_child(label)
 func set_nametag(n,t,c):nametag=[n,t,c];nametag_updates+=1
class Interpolation extends RefCounted:
 var removed:Array=[]
 func erase(id):removed.append(id)
class Arena extends Node:
 var players:Dictionary={}
 var fighters:Dictionary={}
 var local_yaw:=99.
 var remote_interpolation=Interpolation.new()
 var creates:=0
 func _new_state(n,id):return {"name":n,"id":id,"color":0,"team":-1,"yaw":0.,"preserved":42}
 func _create_fighter(id):
  var actor=Actor.new();add_child(actor);fighters[id]=actor;creates+=1
 func reference(rows:Array,mine:int,teams:Array,palette:Array):
  var keep:Array=[]
  for r in rows:
   var id:int=r[0];keep.append(id)
   if not players.has(id):
    players[id]=_new_state(r[1],id);players[id].color=r[2];players[id].spectator=r[5];players[id].dead=r[5];players[id].team=r[6]
    _create_fighter(id);fighters[id].position=r[3];players[id].yaw=r[4]
    if id==mine:local_yaw=r[4]
   players[id].team=r[6];var team:int=r[6]
   fighters[id].set_nametag(players[id].name,team,teams[team] if team>=0 else palette[players[id].color])
  for id in players.keys():
   if not keep.has(id):fighters[id].queue_free();fighters.erase(id);players.erase(id);remote_interpolation.erase(id)
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize()->void:run.call_deferred()
func welcome()->Dictionary:return {"protocol":"fpsloppa-cq-native-1","map_sha256":"test-map","id":2,"epoch":7,"capacity":128,"time":10.}
func roster(n:int)->Array:
 var rows:Array=[]
 for i in n:rows.append({"id":i+2,"name":"Player%d"%i,"spectator":i%5==0,"team":i%2,"avatar":"a".repeat(64)})
 return rows
func frame(tick:int,life:int=1,dead:bool=false,staging:bool=false)->Dictionary:
 return {"tick":tick,"players":{2:{"life":life,"dead":dead,"staging":staging}},"mode":{"epoch":1,"intermission":0.},"events":{}}
func run()->void:
 if not ClassDB.class_exists("FPSClientSession"):push_error("Rebuild native extension");quit(1);return
 var session=ClassDB.instantiate("FPSClientSession")
 check(not session.welcome({},"test-map").ok,"Reject invalid welcome")
 check(not session.accept_frame(frame(1),0,7).accepted,"No frames before admission")
 check(session.welcome(welcome(),"test-map").ok,"Admit matching session")
 check(not session.welcome(welcome(),"test-map").ok,"Reject duplicate admission")
 var catalog=session.catalog_update([{ "hash":"a".repeat(64),"size":1024},{"hash":"../unsafe","size":200},{"hash":"b".repeat(64),"size":25000001}])
 check(catalog.size()==1,"Only bounded content hashes admitted")
 catalog.clear();check(session.stats().catalog==1,"Catalog result is detached")
 var teams:Array=[Color.RED,Color.BLUE,Color.GREEN,Color.YELLOW];var palette:Array=[]
 for i in 8:palette.append(Color(i/8.,.4,.8))
 var timings:Array=[]
 for count in [64,128]:
  var rows:=roster(count);var original:=rows.duplicate(true)
  var plan:Dictionary=session.roster_plan(rows,{},[],"","",{})
  check(plan.ok and plan.rows.size()==count,"Complete roster projection")
  check(plan.downloads==["a".repeat(64)],"Deduplicate shared skin download")
  check(plan.choices.size()==count and plan.pinned.size()==count,"Avatar choices/pins")
  check(rows==original,"Roster input remains immutable")
  check(session.roster_plan(rows,{},["a".repeat(64)],"","",{}).downloads.is_empty(),"Already queued asset excluded")
  check(session.roster_plan(rows,{},[],"a".repeat(64),"",{}).downloads.is_empty(),"Requested asset excluded")
  var native_arena:=Arena.new();var reference_arena:=Arena.new();root.add_child(native_arena);root.add_child(reference_arena)
  check(session.apply_roster(native_arena,plan.rows,teams,palette,2),"Native entity admission")
  reference_arena.reference(plan.rows,2,teams,palette)
  for id in reference_arena.players:
   check(native_arena.players[id]==reference_arena.players[id],"Entity initial state parity")
   check(native_arena.fighters[id].position==reference_arena.fighters[id].position,"Entity position parity")
   check(native_arena.fighters[id].nametag==reference_arena.fighters[id].nametag,"Nametag parity")
  check(native_arena.local_yaw==reference_arena.local_yaw,"Local initial yaw parity")
  var ids:Dictionary={}
  for id in native_arena.fighters:ids[id]=native_arena.fighters[id].get_instance_id()
  var updated:Array=plan.rows.duplicate(true)
  for r in updated:r[6]=1-int(r[6])
  var started:=Time.get_ticks_usec()
  for i in 30:session.apply_roster(native_arena,updated,teams,palette,2)
  var native_us:float=(Time.get_ticks_usec()-started)/30.
  started=Time.get_ticks_usec()
  for i in 30:reference_arena.reference(updated,2,teams,palette)
  timings.append({"players":count,"native_us":native_us,"reference_us":(Time.get_ticks_usec()-started)/30.})
  for id in native_arena.fighters:
   check(native_arena.fighters[id].nametag_updates==2,"Unchanged roster avoids repeated nametag callbacks")
   check(ids[id]==native_arena.fighters[id].get_instance_id(),"Existing entity binding survives roster refresh")
   check(native_arena.players[id]==reference_arena.players[id],"Team/state refresh parity")
  check(native_arena.creates==count,"No duplicate scene factories")
  var before:=native_arena.players.duplicate(true);var malformed:=updated.duplicate(true);malformed.back()[0]=malformed[0][0]
  check(not session.apply_roster(native_arena,malformed,teams,palette,2) and native_arena.players==before,"Invalid roster rejects before mutation")
  var small:=rows.slice(0,2);var delta:Dictionary=session.roster_plan(small,{},[],"","",native_arena.players)
  check(delta.removed.size()==count-2,"Native departure delta")
  check(session.apply_roster(native_arena,delta.rows,teams,palette,2),"Native departures applied")
  reference_arena.reference(delta.rows,2,teams,palette)
  check(native_arena.players==reference_arena.players and native_arena.remote_interpolation.removed==reference_arena.remote_interpolation.removed,"Departure/interpolation cleanup parity")
  check(session.stats().bound==2 and session.stats().members==2,"Bindings bounded to roster membership")
  var bad:=small.duplicate(true);bad[1].id=bad[0].id
  check(not session.roster_plan(bad,{},[],"","",{}).ok and session.stats().members==2,"Invalid roster does not alter membership")
  native_arena.free();reference_arena.free()
 check(session.stats().bound==0,"Freed scene bindings cannot be reused")
 var bots:=roster(2);bots.append({"id":-1,"name":"Bot","spectator":false,"team":1,"avatar":""})
 var bot_plan:Dictionary=session.roster_plan(bots,{},[],"","",{})
 check(bot_plan.ok and bot_plan.rows.back()[2]==7,"Negative bot ID keeps positive palette index")
 var f:=frame(1,1,false,true);f.events={3:{"kind":1},1:{"kind":2},2:{"kind":3}}
 var original_frame:=f.duplicate(true);var decision:Dictionary=session.accept_frame(f,0.,7)
 check(decision.accepted and decision.deployment_offer and decision.events.keys()==[1,2,3],"Ordered once-only event batch and deployment")
 check(f==original_frame,"Frame source remains immutable")
 check(not session.accept_frame(f,0.,7).accepted,"Duplicate frame rejected")
 check(not session.accept_frame(frame(2),0.,8).accepted,"Wrong epoch rejected")
 f=frame(2);f.events={2:{"kind":3},4:{"kind":5}}
 decision=session.accept_frame(f,0.,7)
 check(decision.was_staging and not decision.deployment_offer and decision.events.keys()==[4],"Staging transition and event watermark")
 decision=session.accept_frame(frame(3,1,true),0.,7);check(decision.deaths.size()==1,"One death transition")
 check(session.accept_frame(frame(4,1,true),0.,7).deaths.is_empty(),"Repeated dead snapshot does not repeat effect")
 decision=session.accept_frame(frame(5,2,true),0.,7);check(decision.deaths.size()==1 and decision.life_changes==[2],"New life can die independently")
 f=frame(6);f.mode.intermission=2.;decision=session.accept_frame(f,0.,7);check(decision.round_end,"Intermission gong transition")
 f.tick=7;check(not session.accept_frame(f,0.,7).round_end,"No repeated gong")
 var invalid:=frame(8);invalid.players[2].life="bad"
 check(not session.accept_frame(invalid,0,7).accepted and session.stats().tick==7,"Malformed frame preserves watermarks")
 invalid=frame(8);invalid.events=[]
 check(not session.accept_frame(invalid,0,7).accepted,"Invalid event container rejected")
 check(session.actions(10,2,0,0,0)==[{"life":2,"seq":1,"kind":11,"a":-1,"b":0,"c":0},{"life":2,"seq":2,"kind":12,"a":0,"b":0,"c":0}],"Deployment action compatibility")
 check(session.actions(5,2,3,4,5)[0].seq==3,"Monotonic action sequence")
 var old_generation:int=session.stats().generation;session.reset()
 check(session.stats().generation==old_generation+1 and session.stats().members==0 and session.stats().catalog==0,"Reconnect teardown drops connection state")
 check(not session.accept_frame(frame(8),0,7).accepted and session.actions(5,1,0,0,0).is_empty(),"No stale actions/frames after reset")
 check(session.welcome(welcome(),"test-map").ok and session.accept_frame(frame(1),0,7).accepted,"Reconnect accepts fresh low tick")
 print("NATIVE_CLIENT_SESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"timings":timings}));quit(0 if failures.is_empty() else 1)
