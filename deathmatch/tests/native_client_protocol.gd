extends SceneTree
const Reference=preload("res://deathmatch/native/authority_protocol.gd")
var checks:=0
var failures:Array=[]
var native
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func section(kind:int,count:int,version:int)->PackedByteArray:
 var sizes:Dictionary={1:257,2:42,3:67,4:41,5:147,7:36,8:47,9:98,10:74,11:79,12:54,13:63,14:83,15:17,16:27}
 var n:int=count if kind in [1,2,4,5,14,15,16] else 1
 var data:=PackedByteArray();data.resize(2+(29+30 if kind==6 else n*int(sizes[kind])));data.encode_u16(0,n)
 if kind==6:
  data.encode_s8(2,-2);data.encode_float(7,12.5);data.encode_float(27,600.);data.encode_float(31+12,3.);data.encode_s8(31+16,-1)
 else:
  for i in n:
   var at:int=2+i*int(sizes[kind]);data.encode_u64(at,100+i if kind in [1,2,4,5,14,15,16] else 10000+kind);data.encode_u32(at+8,1)
   if kind==1:
    data[at+12]=3;data.encode_float(at+13,1.65)
    for j in 5:
     for k in 3:data.encode_float(at+17+j*48+k*16,1.)
     data.encode_float(at+17+j*48+36,float(j)*.13);data.encode_float(at+17+j*48+40,1.2)
   elif kind==2:data[at+12]=4;data.encode_u16(at+13,7);data.encode_u16(at+15,1030);data.encode_float(at+17,.5);data.encode_s8(at+22,-1);data.encode_s8(at+27,-1)
   elif kind==3:data[at+21]=5;data.encode_float(at+22,-18.);data.encode_float(at+46,3.);data[at+50]=3;data.encode_float(at+51,20.);data.encode_float(at+59,1.)
   elif kind==4:data[at+12]=2;data.encode_float(at+17,4.)
   elif kind==5:
    data[at+12]=i%4;data[at+13]=(i+1)%4;data[at+14]=2;data[at+15]=31;data[at+143]=15;data[at+144]=15;data[at+145]=15;data.encode_s8(at+146,-1)
    for j in 4:data.encode_s32(at+16+j*4,1000+j)
   elif kind==7:data[at+21]=1
   elif kind==9:data[at+9]=3;data[at+11]=3
   elif kind==11:data[at+8]=1
   elif kind==14:data.encode_u16(at+12,4095);data[at+46]=7;data.encode_s8(at+55,-1);data.encode_s8(at+60,-1);data.encode_float(at+26,1.)
   elif kind==15:data[at+12]=2;data.encode_float(at+13,4.)
   elif kind==16:
    data.encode_u32(at+12,131071);data[at+26]=15
    for j in 5:data.encode_u16(at+16+j*2,10+j)
 var out:=PackedByteArray();out.resize(6);out.encode_u16(0,kind);out.encode_u32(2,data.size());out.append_array(data);return out
func fixture(count:int,version:int=3)->PackedByteArray:
 var b:PackedByteArray=("CQA%d"%version).to_ascii_buffer();b.resize(14+count*104);b.encode_u64(4,57);b.encode_u16(12,count)
 for i in count:
  var at:=14+i*104;b.encode_s64(at,100+i);b.encode_u32(at+8,1);b[at+12]=i%2;b[at+14]=4;b[at+15]=1;b.encode_float(at+48,1.65);b.encode_float(at+52,100.)
  b.encode_float(at+16,float(i));b.encode_float(at+40,.3);b.encode_s64(at+56,-1);b.encode_u64(at+64,123)
  for j in 4:b.encode_u16(at+72+j*2,20+j)
  for j in 12:b.encode_u16(at+80+j*2,j)
 if version>1:
  for kind in [1,2,3,4,5,6,7,8,9,10,11,12,13,16,14,15]:
   if kind==16 and version<3:continue
   b.append_array(section(kind,count,version))
 return b
func _initialize()->void:
 native=preload("res://deathmatch/native/runtime.gd").codec()
 check(native!=null and native.has_method("decode_authority_frame") and native.has_method("encode_authority_input"),"required native client protocol methods")
 if failures.size():quit(1);return
 for version in [1,2,3]:
  for count in [1,4,64,128]:
   var b:=fixture(count,version);var reference:Dictionary=Reference.decode_frame_reference(b);var actual:Dictionary=native.decode_authority_frame(b)
   check(not reference.is_empty(),"valid fixture %s/%s"%[version,count]);check(actual==reference,"all decoded fields match reference %s/%s"%[version,count])
 var bytes:=fixture(4)
 for length in bytes.size():
  if length%29!=0:continue
  check(native.decode_authority_frame(bytes.slice(0,length)).is_empty()==Reference.decode_frame_reference(bytes.slice(0,length)).is_empty(),"truncation %s"%length)
 var bad:=bytes.duplicate();bad.encode_float(14+16,NAN);check(native.decode_authority_frame(bad).is_empty(),"reject nonfinite base position")
 bad=bytes.duplicate();bad.encode_u16(12,129);check(native.decode_authority_frame(bad).is_empty(),"reject player count overflow")
 bad=bytes.duplicate();bad.append_array(section(1,4,3));check(native.decode_authority_frame(bad).is_empty(),"reject duplicate section")
 bad=bytes.duplicate();bad.encode_u64(14+104,100);check(native.decode_authority_frame(bad).is_empty(),"reject duplicate player")
 # Unknown sections are forward-compatible, but cannot repeat.
 bad=bytes.duplicate();var extension:=PackedByteArray([100,0,2,0,0,0,0,0]);bad.append_array(extension)
 check(native.decode_authority_frame(bad)==Reference.decode_frame_reference(bad),"unknown section compatibility");bad.append_array(extension);check(native.decode_authority_frame(bad).is_empty(),"reject repeated unknown section")
 var base:Dictionary={"life":7,"seq":123,"move":Vector2(.1,-.8),"yaw":.3,"pitch":-.4,"weapon":4,"fire":true,"jump":true,"reload":false,"slow":false,"crouch":true,"prone":false,"blocked":false}
 for mask in 64:
  var c:=base.duplicate()
  if mask&1:c.xr={"head":Transform3D(Basis(Vector3.UP,.4),Vector3(0,1.65,0)),"left":Transform3D.IDENTITY,"right":Transform3D.IDENTITY,"weapon":Transform3D.IDENTITY,"height":1.65,"left_handed":true}
  if mask&2:
   if c.has("xr"):c.xr.offhand_weapon=Transform3D.IDENTITY
   c.weapon_held=false;c.vr_device=true;c.reload_grip=true;c.reload_trigger=true;c.jetpack=true;c.offhand_fire=true;c.cq_drag=true;c.melee=true;c.respawn=true;c.room=Vector3(.1,0,-.1)
  if mask&4:c.view_time=123.25
  if mask&8:c.jump_event=12;c.jump_seq=-1;c.jetpack_event=15;c.fire_event=[55,4,3]
  if mask&16:c.swim=Vector3(.3,-.1,.2)
  if mask&32:c.weapon_held=true
  check(native.encode_authority_input(c)==Reference.encode_input_reference(c),"input wire parity flags %d"%mask)
 check(native.encode_authority_input({}).is_empty(),"reject incomplete input")
 var invalid:=base.duplicate();invalid.yaw=INF;check(native.encode_authority_input(invalid).is_empty(),"reject nonfinite input")
 var results:Array=[]
 for count in [64,128]:
  var data:=fixture(count);var n:=40;var start:=Time.get_ticks_usec()
  for i in n:Reference.decode_frame_reference(data)
  var reference_us:float=(Time.get_ticks_usec()-start)/float(n);start=Time.get_ticks_usec()
  for i in n:native.decode_authority_frame(data)
  var native_us:float=(Time.get_ticks_usec()-start)/float(n)
  results.append({"players":count,"bytes":data.size(),"reference_us":reference_us,"native_us":native_us})
 var tracked:=base.duplicate();tracked.xr={"head":Transform3D.IDENTITY,"left":Transform3D.IDENTITY,"right":Transform3D.IDENTITY,"weapon":Transform3D.IDENTITY,"height":1.65};tracked.weapon_held=true;tracked.view_time=12.5;tracked.swim=Vector3(.2,0,0)
 var iterations:=4000;var began:=Time.get_ticks_usec()
 for i in iterations:Reference.encode_input_reference(tracked)
 var input_reference_us:float=(Time.get_ticks_usec()-began)/float(iterations);began=Time.get_ticks_usec()
 for i in iterations:native.encode_authority_input(tracked)
 var input_native_us:float=(Time.get_ticks_usec()-began)/float(iterations)
 print("NATIVE_CLIENT_PROTOCOL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"timings":results,"input":{"reference_us":input_reference_us,"native_us":input_native_us}}));quit(0 if failures.is_empty() else 1)
