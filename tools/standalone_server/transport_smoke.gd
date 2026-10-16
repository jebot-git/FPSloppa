extends SceneTree
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var link
var test_port:=17777
var request_delta:=true
var negotiated:=""
var started:=0
var welcomed:=false
var rostered:=false
var frame_time:=0
var max_frame_gap_ms:=0
var frames:=0
var inputs:=0
var life:=0
var id:=0
var last_frame:Dictionary={}
var initial:=Vector3.ZERO
var deployed:=false
var moving:=false
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--port="):test_port=arg.trim_prefix("--port=").to_int()
  if arg=="--full-snapshots":request_delta=false
 started=Time.get_ticks_msec()
 link=ClassDB.instantiate("FPSNativeClient")
 if not link or link.connect_host("127.0.0.1",test_port)!=OK:quit(2)
func _process(_delta:float)->bool:
 if not link:return false
 for event in link.poll():
  var data:Dictionary=event.get("data",{})
  match int(event.type):
   0:
    var world:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://native_server/cooked/world.json"))
    link.send_control(1,{"snapshot_codec":link.snapshot_codec() if request_delta and link.has_method("snapshot_codec") else "","protocol":"fpsloppa-cq-native-1","name":"Native smoke","map_sha256":world.map_sha})
   -1:push_error("Transport disconnected");quit(3)
   2:
    negotiated=data.get("snapshot_codec","");welcomed=true;id=int(data.id);link.activate(id);link.send_control(3,{})
   4:push_error(str(data));quit(4)
   5:rostered=true
   6:
    var frame:Dictionary=event.get("frame",{})
    if frame!=Codec.decode_frame_reference(event.bytes):push_error("Native frame differs from reference");quit(8);return false
    if frame.is_empty():push_error("Invalid frame");quit(5);return false
    var now:=Time.get_ticks_msec()
    if frame_time:max_frame_gap_ms=maxi(max_frame_gap_ms,now-frame_time)
    frame_time=now
    frames+=1;last_frame=frame
    if frame.players.has(id):
     var p:Dictionary=frame.players[id];life=int(p.life)
     if not p.staging and not moving:initial=p.position;moving=true
     if not deployed:
      initial=p.position
      link.send_control(8,{"life":life,"seq":1,"kind":11,"a":-1});link.send_control(8,{"life":life,"seq":2,"kind":12});deployed=true
 if life>0:
  inputs+=1
  var c:={"life":life,"seq":inputs,"move":Vector2(0,-1),"yaw":0.,"pitch":0.,"weapon":int(last_frame.players[id].weapon),"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false}
  link.send_bytes(7,Codec.encode_input(c),1,false)
 if frames>=60:
  var p:Dictionary=last_frame.players[id]
  var result:={"max_frame_gap_ms":max_frame_gap_ms,"snapshot_codec":negotiated,"native_frame_parity":true,"welcome":welcomed,"roster":rostered,"frames":frames,"inputs":inputs,"deployed":not p.staging,"distance":p.position.distance_to(initial),"position":str(p.position)}
  print("CQ_TRANSPORT_SMOKE ",JSON.stringify(result));link.close();quit(0 if welcomed and rostered and (not request_delta or negotiated=="row-xor-fastlz-v3") and not p.staging and result.distance>1 else 6)
 if Time.get_ticks_msec()-started>20000:push_error("Transport smoke timeout");quit(7)
 return false
