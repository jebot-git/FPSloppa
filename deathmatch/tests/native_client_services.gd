extends SceneTree
const Format=preload("res://deathmatch/avatars/ut_format.gd")
var checks:=0
var failures:Array=[]
var directory:String
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize()->void:run.call_deferred()
func write(path:String,bytes:PackedByteArray)->void:
 var f:=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(bytes);f.close()
func fixture(manifest:Dictionary={},position_data:PackedByteArray=PackedByteArray())->PackedByteArray:
 var m:Dictionary={"title":"Fixture","author":"Test","license":"CC0","vertices":3,"frames":1,"width":512,"height":1,"position_bytes":8192,"skin_bytes":32,"skin_width":2,"skin_height":2,"reference":0,"corners":[[0,0.,0.],[1,1.,0.],[2,0.,1.]],"clips":[{"name":"Idle","start":0,"count":1,"fps":10.}],"bounds":[0.,0.,0.,1.,1.,0.]}
 m.merge(manifest,true);var json:=JSON.stringify(m).to_utf8_buffer();var raw:=PackedByteArray();raw.resize(8192);raw.encode_float(16,1);raw.encode_float(36,1)
 if not position_data.is_empty():raw=position_data
 var skin:=PackedByteArray();skin.resize(32)
 var signature:=PackedByteArray([137,80,78,71,13,10,26,10]);for i in 8:skin[i]=signature[i]
 var ihdr:="IHDR".to_ascii_buffer();for i in 4:skin[12+i]=ihdr[i]
 skin[19]=2;skin[23]=2
 var out:="UTAV".to_ascii_buffer();out.resize(16);out.encode_u32(4,1);out.encode_u32(8,16+json.size()+raw.size()+skin.size());out.encode_u32(12,json.size());out.append_array(json);out.append_array(raw);out.append_array(skin);return out
func chunk(bytes:PackedByteArray,offset:int=0)->PackedByteArray:
 var packet:=PackedByteArray();packet.resize(4);packet.encode_u32(0,offset);packet.append_array(bytes);return packet
func await_validation(service)->Array:
 var result:Array=[]
 for i in 500:
  result.append_array(service.transfer_poll(Time.get_ticks_msec()))
  if not service.stats().validating:return result
  await process_frame
 check(false,"Validation completes within bounded fixture time");return result
func begin_download(service,hash_value:String,bytes:PackedByteArray)->void:
 service.set_catalog({hash_value:{"size":bytes.size()}});service.queue_downloads([hash_value,hash_value])
 var events:Array=service.transfer_poll(0)
 check(events.size()==1 and events[0].type==11,"One deduplicated native download request")
 check(service.transfer_control(12,{"hash":hash_value,"size":bytes.size()},1).is_empty(),"Accept matching download begin")
func run()->void:
 if not ClassDB.class_exists("FPSClientServices"):push_error("Rebuild native services");quit(1);return
 directory=ProjectSettings.globalize_path("user://native-services-test-%d/"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(directory)
 var path:=directory+"fixture.utavatar";var bytes:=fixture();write(path,bytes)
 var hash_value:=FileAccess.get_sha256(path);var parsed:Dictionary=Format.read(path)
 check(not parsed.has("error") and parsed==Format.read_reference(path),"Valid native/reference full container parity")
 var mutations:Array=[{"vertices":2},{"vertices":4097},{"frames":0},{"width":256},{"height":2},{"position_bytes":10},{"skin_bytes":31},{"skin_width":2049},{"skin_height":0},{"reference":1},{"title":false},{"author":"x".repeat(257)},{"license":null},{"corners":[]},{"corners":[[3,0,0],[1,0,0],[2,0,0]]},{"corners":[[0,-.1,0],[1,0,0],[2,0,0]]},{"clips":[]},{"clips":[{"name":"Idle","start":0,"count":2,"fps":10}]},{"clips":[{"name":"Idle","start":0,"count":1,"fps":0}]},{"bounds":[0,0,0,-1,1,1]},{"base_model":"Unsafe"},{"arm_profile":{}},{"ik_profile":{}}]
 for m in mutations:
  write(directory+"bad.utavatar",fixture(m));var native:Dictionary=Format.read(directory+"bad.utavatar");var reference:Dictionary=Format.read_reference(directory+"bad.utavatar")
  check(native.has("error") and reference.has("error"),"Malformed manifest rejection parity: "+str(m.keys()))
 for at in [0,4,8,12,bytes.size()-32,bytes.size()-20,bytes.size()-13]:
  var bad:=bytes.duplicate();bad[at]^=255;write(directory+"bad.utavatar",bad)
  check(Format.read(directory+"bad.utavatar").has("error")==Format.read_reference(directory+"bad.utavatar").has("error"),"Malformed header/PNG rejection parity")
 var bad:=bytes.slice(0,bytes.size()-1);write(directory+"bad.utavatar",bad);check(Format.read(directory+"bad.utavatar").has("error"),"Truncation rejected")
 var ik:Dictionary={"left":[[-.2,.8,0],[-.5,.6,0],[-.8,.5,0]],"right":[[.2,.8,0],[.5,.6,0],[.8,.5,0]],"neck":[0,.8,0],"head":[0,1,0],"eye":[0,1,-.1],"sockets":[[-.2,.8,0,.2,.8,0,0,.8,0]]}
 var full:Dictionary={"ik_profile":ik,"ik_weights":[[1,1,0],[2,.5,.5],[3,1,.5]],"arm_profile":{"left":ik.left,"right":ik.right},"arm_weights":[-1.,1.,0.]}
 write(directory+"ik.utavatar",fixture(full));check(Format.read(directory+"ik.utavatar")==Format.read_reference(directory+"ik.utavatar"),"Full arm/head IK profile parity")
 var invalid_profiles:Array=[]
 var change:=full.duplicate(true);change.ik_profile.head_correction=[1,1,1,1];invalid_profiles.append(change)
 change=full.duplicate(true);change.ik_profile.sockets=[];invalid_profiles.append(change)
 change=full.duplicate(true);change.ik_profile.left[1]=change.ik_profile.left[0];invalid_profiles.append(change)
 change=full.duplicate(true);change.ik_weights[0][0]=4;invalid_profiles.append(change)
 change=full.duplicate(true);change.ik_weights[1][1]=-1;invalid_profiles.append(change)
 change=full.duplicate(true);change.arm_weights[0]=3;invalid_profiles.append(change)
 for edited in invalid_profiles:
  write(directory+"bad.utavatar",fixture(edited));check(Format.read(directory+"bad.utavatar").has("error") and Format.read_reference(directory+"bad.utavatar").has("error"),"Malformed nested IK rejection parity")
 for value in [NAN,INF,11.]:
  var raw:=PackedByteArray();raw.resize(8192);raw.encode_float(0,value);write(directory+"bad.utavatar",fixture({},raw))
  check(Format.read(directory+"bad.utavatar").has("error") and Format.read_reference(directory+"bad.utavatar").has("error"),"Invalid/nonfinite animated position rejection")
 var timings:Array=[]
 var manifest:Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
 for row in manifest:
  var started:=Time.get_ticks_usec();var native:Dictionary=Format.inspect(row.path);var native_us:=Time.get_ticks_usec()-started
  started=Time.get_ticks_usec();var reference:Dictionary=Format.inspect_reference(row.path);var script_us:=Time.get_ticks_usec()-started
  check(not native.has("error") and native==reference,"Bundled model metadata parity: "+str(row.title))
  timings.append({"title":row.title,"native_us":native_us,"reference_us":script_us})
 var service=ClassDB.instantiate("FPSClientServices");var cache:=directory+"cache";var profiles:=directory+"profiles.cfg"
 check(service.configure(cache,profiles)==OK,"Prepare isolated cache")
 check(service.resolve_start(" 127.0.0.1 ",27933)==OK,"Resolve numeric address")
 var connection:Dictionary=service.connection_poll();check(connection.ready and connection.endpoint=="127.0.0.1:27933","Canonical endpoint")
 check(service.resume_token()=="","Missing profile is empty")
 check(service.save_resume("a".repeat(64))==OK and service.resume_token()=="a".repeat(64),"Atomic profile persistence")
 check(service.save_resume("../invalid")!=OK and service.resume_token()=="a".repeat(64),"Invalid token preserves previous profile")
 check(service.resolve_start("localhost",27934)==OK,"Asynchronous local hostname resolution")
 for i in 300:
  connection=service.connection_poll()
  if connection.get("ready",false) or connection.has("error"):break
  await process_frame
 check(connection.get("ready",false),"Hostname resolution completes")
 check(service.save_resume("b".repeat(64))==OK,"Store second endpoint")
 service.resolve_start("127.0.0.1",27933);service.connection_poll();check(service.resume_token()=="a".repeat(64),"Profile update preserves other endpoints")
 service.resolve_start("localhost",27934);service.reset();check(not service.connection_poll().ready,"Resolver cancellation cannot deliver stale result")
 check(service.resolve_start("",27933)!=OK and service.resolve_start("127.0.0.1",1)!=OK,"Invalid connection parameters rejected")
 begin_download(service,hash_value,bytes)
 check(not service.transfer_chunk(chunk(bytes,1)).is_empty() and service.stats().download_offset==0,"Offset mismatch does not advance download")
 check(service.transfer_chunk(chunk(bytes)).is_empty(),"Disk-stream complete chunk")
 check(service.stats().buffered_download_bytes==0 and not FileAccess.file_exists(cache+"/"+hash_value+".utavatar"),"No full scripted/in-memory download and no early publication")
 check(service.transfer_control(14,{"hash":hash_value},2).is_empty(),"Bounded background validation starts")
 var events:Array=await await_validation(service);var installed:Array=events.filter(func(e):return e.has("installed"))
 check(installed.size()==1 and FileAccess.get_sha256(installed[0].installed.path)==hash_value,"Only hash-validated avatar published")
 check(service.pending_downloads().is_empty(),"Completion releases pending membership")
 # Cancel during disk reception.
 service.reset();begin_download(service,hash_value,bytes);service.transfer_chunk(chunk(bytes.slice(0,100)));var temporary:String=service.stats().temporary;service.reset()
 check(not FileAccess.file_exists(temporary),"Reset removes partial disk download")
 # Cancel during verification. A canonical file must never be replaced by stale results.
 begin_download(service,hash_value,bytes);service.transfer_chunk(chunk(bytes));service.transfer_control(14,{"hash":hash_value},2);service.reset()
 var sentinel:="preserve existing cache".to_utf8_buffer();write(cache+"/"+hash_value+".utavatar",sentinel)
 check(service.configure(cache,profiles)==OK,"Reconnect configuration does not wait for stale validation")
 events=await await_validation(service)
 check(events.is_empty() and FileAccess.get_file_as_bytes(cache+"/"+hash_value+".utavatar")==sentinel,"Stale worker cannot publish or emit completion")
 DirAccess.remove_absolute(cache+"/"+hash_value+".utavatar")
 # Digest mismatch never enters canonical cache.
 var wrong:="f".repeat(64);begin_download(service,wrong,bytes);service.transfer_chunk(chunk(bytes));service.transfer_control(14,{"hash":wrong},2);events=await await_validation(service)
 check(events.any(func(e):return e.has("error")) and not FileAccess.file_exists(cache+"/"+wrong+".utavatar"),"Checksum mismatch is rejected before publication")
 # A missing DONE and an idle request both expire, and leave no partial file.
 service.reset();begin_download(service,hash_value,bytes);service.transfer_chunk(chunk(bytes));temporary=service.stats().temporary
 events=service.transfer_poll(30001)
 check(events.any(func(e):return e.has("error")) and not FileAccess.file_exists(temporary),"Incomplete transfer times out and removes temporary")
 service.reset();service.set_catalog({hash_value:{"size":bytes.size()}});service.queue_downloads([hash_value]);service.transfer_poll(1)
 check(service.transfer_poll(30002).any(func(e):return e.has("error")),"Unanswered request times out")
 # A sparse quota fixture has a large logical size without allocating a GB of disk.
 service.reset();var quota:=FileAccess.open(cache+"/quota.utavatar",FileAccess.WRITE);quota.seek(1000000000);quota.store_8(0);quota.close()
 check(ClassDB.class_call_static("FPSClientServices","avatar_inspect",cache+"/quota.utavatar",hash_value).error.contains("25 MB"),"Oversized files rejected before checksum scan")
 begin_download(service,hash_value,bytes);service.transfer_chunk(chunk(bytes));service.transfer_control(14,{"hash":hash_value},2);events=await await_validation(service)
 check(events.any(func(e):return e.has("error")) and not FileAccess.file_exists(cache+"/"+hash_value+".utavatar"),"Cache budget checked before atomic publication")
 DirAccess.remove_absolute(cache+"/quota.utavatar")
 # Wrong size and chunk bounds cannot create or advance a transfer.
 service.reset();service.set_catalog({hash_value:{"size":bytes.size()}});service.queue_downloads([hash_value]);service.transfer_poll(1)
 check(not service.transfer_control(12,{"hash":hash_value,"size":bytes.size()+1},2).is_empty(),"Wrong advertised size rejected")
 service.transfer_control(12,{"hash":hash_value,"size":bytes.size()},2)
 check(not service.transfer_chunk(PackedByteArray([0,0,0,0])).is_empty(),"Empty payload rejected")
 var oversized:=PackedByteArray();oversized.resize(32773)
 check(not service.transfer_chunk(oversized).is_empty() and service.stats().download_offset==0,"Oversized payload rejected")
 service.reset();service.set_catalog({});check(service.offer(hash_value,path,bytes.size()).is_empty(),"Native upload opens source once")
 events=service.transfer_poll(0);check(events.size()==1 and events[0].type==15,"Upload offer packet")
 service.transfer_control(16,{"hash":hash_value,"busy":true},0)
 check(service.transfer_poll(1999).is_empty(),"Busy ACK waits before retry")
 events=service.transfer_poll(2000);check(events.size()==1 and events[0].type==15,"Busy ACK retry after two seconds")
 service.transfer_control(16,{"hash":hash_value,"upload":true},2001);events=service.transfer_poll(2001)
 check(events.size()==1 and events[0].type==23 and events[0].bytes==chunk(bytes),"Bounded upload packet format")
 service.upload_sent(false);var retried:Array=service.transfer_poll(2002);check(retried[0].bytes==events[0].bytes and service.stats().upload_offset==0,"Failed network enqueue retains exact pending chunk")
 service.upload_sent(true);check(service.stats().upload_offset==bytes.size() and service.transfer_poll(2003).is_empty(),"Only acknowledged enqueue advances upload offset")
 service.transfer_control(16,{"hash":hash_value},2004);events=service.transfer_poll(2004);check(events.size()==1 and events[0].type==17,"Server acceptance selects uploaded avatar")
 check(not service.offer("../bad",path,bytes.size()).is_empty() and not service.offer(hash_value,path,25000001).is_empty(),"Unsafe/oversized offers rejected")
 service.reset();service.set_catalog({});service.offer(hash_value,path,bytes.size());service.transfer_poll(1)
 check(service.transfer_poll(30002).any(func(e):return e.has("error")),"Unanswered upload offer times out")
 service.reset();service.set_catalog({});service.offer(hash_value,path,bytes.size());service.transfer_poll(1);service.transfer_control(16,{"hash":hash_value,"upload":true},2);service.transfer_poll(2);service.upload_sent(true)
 check(service.transfer_poll(30003).any(func(e):return e.has("error")),"Missing final upload acceptance times out")
 service.reset();service.set_catalog({hash_value:{"size":bytes.size()}});service.offer(hash_value,path,bytes.size());events=service.transfer_poll(0);check(events.size()==1 and events[0].type==17,"Catalog avatar selection skips upload")
 service.reset();check(service.pending_downloads().is_empty() and service.transfer_poll(0).is_empty(),"Reset clears pending transfers and outgoing packets")
 for file in DirAccess.get_files_at(cache):DirAccess.remove_absolute(cache+"/"+file)
 DirAccess.remove_absolute(cache)
 for file in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory+file)
 DirAccess.remove_absolute(directory)
 print("NATIVE_CLIENT_SERVICES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"avatar_timings":timings}));quit(0 if failures.is_empty() else 1)
