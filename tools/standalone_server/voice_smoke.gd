extends SceneTree
var links:Array=[]
var ids:Array[int]=[0,0]
var ready:Array[bool]=[false,false]
var started:=0
var sent:=false
var sent_at:=0
var received:=0
var pong:=false
var report:=""
var map_sha:=""
func _initialize()->void:
 var world:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://native_server/cooked/world.json"));map_sha=world.map_sha;started=Time.get_ticks_msec()
 var args:=OS.get_cmdline_user_args();var index:=args.find("--report")
 if index>=0 and index+1<args.size():report=args[index+1]
 for i in 2:
  var link=ClassDB.instantiate("FPSNativeClient");link.connect_host("127.0.0.1",17777);links.append(link)
func _process(_delta:float)->bool:
 for i in 2:
  for event in links[i].poll():
   var data:Dictionary=event.get("data",{})
   match int(event.type):
    0:links[i].send_control(1,{"protocol":"fpsloppa-cq-native-1","name":"Voice QA "+str(i),"map_sha256":map_sha})
    2:ids[i]=int(data.id);links[i].send_control(3,{})
    4:push_error(str(data));quit(1)
    5:ready[i]=true
    10:
     var bytes:PackedByteArray=event.bytes
     if i!=1 or bytes.size()!=16 or bytes.decode_s64(0)!=ids[0] or bytes.decode_u32(8)!=1 or bytes[12]!=0:push_error("Invalid voice route");quit(2)
     received+=1
    21:pong=int(data.stamp)==42
 if ready.all(func(value):return value) and not sent:
  sent=true;sent_at=Time.get_ticks_msec();var packet:=PackedByteArray([1,0,0,0,0,0,0,8])
  links[0].send_bytes(10,packet,2,false);links[0].send_bytes(10,packet,2,false)
  packet[0]=2;packet[7]=0;links[0].send_bytes(10,packet,2,false)
  packet[0]=3;packet[4]=2;packet[7]=8;links[0].send_bytes(10,packet,2,false)
  links[1].send_control(20,{"stamp":42})
 if sent and Time.get_ticks_msec()-sent_at>1200:
  var result:={"valid_voice_relay":received==1,"duplicate_rejected":received==1,"invalid_toc_rejected":received==1,"radio_scope_gate":received==1,"ping":pong};print("CQ_VOICE_SMOKE ",JSON.stringify(result))
  if not report.is_empty():FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
  for link in links:link.close()
  quit(0 if received==1 and pong else 3)
 if Time.get_ticks_msec()-started>15000:push_error("Voice QA timeout");quit(4)
 return false
