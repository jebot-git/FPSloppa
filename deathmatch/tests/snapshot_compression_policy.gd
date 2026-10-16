extends SceneTree
const Replication=preload("res://deathmatch/network/replication.gd")
const Codec=preload("res://deathmatch/network/snapshot_codec.gd")
const Fixture=preload("res://deathmatch/tests/native_network_packing.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var fixture:=Fixture.new()
 for scenario in ["pve","pve_classes","cq","cq_legacy"]:
  var cq:bool=scenario.begins_with("cq")
  var state:Array=fixture.snapshot(64,128,true,2)
  state[10].kind="pve" if not cq else "tdm"
  if cq or scenario=="pve_classes":state[10].class_mode={"clock":1.};state[10].cq_points={"scores":[0,0]}
  if scenario=="cq_legacy":state[10].erase("class_mode");state[10].kind="cq"
  var native:=Replication.new();var reference:=Replication.new();reference.native_packing_enabled=false
  var a:Dictionary=native.packets(state);var b:Dictionary=reference.packets(state)
  check(a==b,"native/reference packet parity, CQ=%s"%cq)
  for packet in a.normal+a.large:
   check(packet[0]==(2 if cq else 3),"compression restricted to CQ")
   check(Codec.unpack(packet)!=null,"envelope roundtrip")
   if not cq:check(packet.size()==packet.decode_u32(1)+5,"PvE envelope is raw without compression")
  check(a.normal.all(func(p):return p.size()<=1100),"packet budget")
  check(native.queue_packets(state),"async snapshot accepted")
  var end:=Time.get_ticks_msec()+10000;var packets:Array=[]
  while packets.is_empty() and Time.get_ticks_msec()<end:
   await process_frame;packets=native.poll_packets()
  check(not packets.is_empty(),"async snapshot completed")
  for group in packets:
   print("POLICY_ASYNC ",JSON.stringify({"scenario":scenario,"packets":group.normal.size()+group.large.size(),"compressed":cq}))
   for packet in group.normal+group.large:check(packet[0]==(2 if cq else 3),"async compression restricted to CQ")
  native.reset();reference.reset()
 # Old compressed envelopes still decode; malformed raw lengths are rejected.
 var packet:=Codec.pack([1,2,3.],false);packet.encode_u32(1,10);check(Codec.unpack(packet)==null,"reject raw length mismatch")
 packet=Codec.pack([1,2,3.],true);check(Codec.unpack(packet)==[1,2,3.],"legacy compressed decode")
 fixture.free()
 print("SNAPSHOT_COMPRESSION_POLICY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
