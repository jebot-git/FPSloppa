extends SceneTree
var link
var began:=0
var bytes:=PackedByteArray()
var hash:=""
var offset:=0
var downloading:=PackedByteArray()
var phase:=0
var sending:=false
var token:=""
var resume_ok:=false
var report:=""
func connect_link()->void:
 link=ClassDB.instantiate("FPSNativeClient");link.connect_host("127.0.0.1",17777)
func _initialize()->void:
 began=Time.get_ticks_msec();var args:=OS.get_cmdline_user_args();var index:=args.find("--report")
 if index>=0 and index+1<args.size():report=args[index+1]
 var source:=FileAccess.get_file_as_bytes("res://deathmatch/avatars/models/base/soldier.utavatar");var size:=source.decode_u32(12)
 var manifest:Dictionary=JSON.parse_string(source.slice(16,16+size).get_string_from_utf8());manifest.title="Native transport QA "+str(Time.get_ticks_usec())
 var text:=JSON.stringify(manifest).to_utf8_buffer();bytes.resize(16);bytes.encode_u32(0,source.decode_u32(0));bytes.encode_u32(4,1);bytes.encode_u32(8,16+text.size()+source.size()-16-size);bytes.encode_u32(12,text.size());bytes.append_array(text);bytes.append_array(source.slice(16+size));var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes);hash=digest.finish().hex_encode();connect_link()
func fail(message:String)->void:push_error(message);link.close();quit(1)
func _process(_delta:float)->bool:
 for event in link.poll():
  var data:Dictionary=event.get("data",{})
  match int(event.type):
   0:
    var world:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://native_server/cooked/world.json"));link.send_control(1,{"protocol":"fpsloppa-cq-native-1","name":"Asset QA","map_sha256":world.map_sha,"resume":token})
   2:
    if phase==2:
     resume_ok=token==data.resume
     var result:={"uploaded":true,"downloaded":true,"sha256":hash,"bytes":bytes.size(),"resume":resume_ok};print("CQ_ASSET_SMOKE ",JSON.stringify(result))
     if not report.is_empty():FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
     link.close();quit(0 if resume_ok else 2);return false
    token=data.resume;link.send_control(3,{})
   4:fail(str(data));return false
   5:
    if phase==0:phase=1;link.send_control(15,{"hash":hash,"size":bytes.size()})
   16:
    if data.get("upload",false):sending=true
    else:link.send_control(17,{"hash":hash});link.send_control(11,{"hash":hash})
   12:
    if data.hash!=hash or int(data.size)!=bytes.size():fail("Asset begin mismatch");return false
   13:
    var packet:PackedByteArray=event.bytes
    if packet.decode_u32(0)!=downloading.size():fail("Asset chunk order");return false
    downloading.append_array(packet.slice(4))
   14:
    if downloading!=bytes:fail("Avatar roundtrip differs");return false
    link.close();phase=2;connect_link();break
 if sending:
  var packet:=PackedByteArray();packet.resize(4);packet.encode_u32(0,offset);var end:=mini(offset+32768,bytes.size());packet.append_array(bytes.slice(offset,end));link.send_bytes(23,packet,3,true);offset=end
  if offset==bytes.size():sending=false
 if Time.get_ticks_msec()-began>30000:fail("Asset smoke timeout")
 return false
