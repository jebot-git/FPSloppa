extends SceneTree
const Fixture=preload("res://deathmatch/tests/native_network_packing.gd")
const Pose=preload("res://tools/native_study/remaining_network.gd")
const Rep=preload("res://tools/native_study/personal_replication_reference.gd")
const Live=preload("res://deathmatch/network/replication.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
func stats(a:Array) -> Dictionary:
 a.sort();return {"median":a[a.size()/2],"p95":a[int(a.size()*.95)]}
func _initialize():
 var fixture=Fixture.new();var pose=Pose.new();var actor=Fighter.new();var reports:Array=[]
 for variant in ["broadcast","reference","native","native","reference","broadcast"]:
  var personal:bool=variant!="broadcast"
  var senders:Array=[]
  for i in 16:
   var sender=Live.new() if variant=="broadcast" else Rep.new();sender.native_packing_enabled=variant!="reference";senders.append(sender)
  var times:Array=[];var bytes:Array=[];var preparation:Array=[];var compression:Array=[]
  for tick in 100:
   var state:Array=fixture.snapshot(16,32,false,tick);state[12]=tick/30.
   for i in state[0].size():
    var row:Array=state[0][i];row[1]=Vector3((i%4)*25,0,(i/4)*25);row[18]=pose.full_pose(tick*.05+i)
    var locomotion:Dictionary={"height":1.65,"grounded":true,"replay":actor.prediction_state(),"shot_counts":{},"fire_results":[],"fire_ack":tick}
    for n in 8:locomotion.shot_counts["0:"+str(tick+n)]=n;locomotion.fire_results.append([tick+n,"fired",1])
    state[10].locomotion[row[0]]=locomotion
   var shared:Dictionary={};var size:=0;var start:=Time.get_ticks_usec()
   var prep_us:=0;var pack_us:=0
   if variant=="native":
    for i in 16:
     var sender=Rep.new();var began:=Time.get_ticks_usec()
     var groups:Dictionary=sender.native_packer.snapshot_records(state,state[0][i][0],sender.pose_sent,sender.cached,shared)
     prep_us+=Time.get_ticks_usec()-began;began=Time.get_ticks_usec()
     var packets:Dictionary={"normal":[],"large":[]}
     if i==0:sender._pack_records(groups.common,[1,tick,state[12]],packets)
     sender._pack_records(groups.personal,[1,tick,state[12]],packets)
     pack_us+=Time.get_ticks_usec()-began
    # Isolate preparation/packing scopes above; measure the actual production
    # implementation independently below with fresh per-frame caches.
    shared={}
   start=Time.get_ticks_usec()
   if personal:
    for i in 16:
     var packets:Dictionary=senders[i].packets(state,state[0][i][0],shared)
     for packet in packets.normal+packets.large:size+=packet.size()
   else:
    var packets:Dictionary=senders[0].packets(state)
    for packet in packets.normal+packets.large:size+=packet.size()*16
   if tick>=20:times.append(Time.get_ticks_usec()-start);bytes.append(size);preparation.append(prep_us);compression.append(pack_us)
  reports.append({"variant":variant,"personal":personal,"all_16_recipients_us":stats(times),"total_payload_bytes":stats(bytes),"fresh_native_projection_us":stats(preparation),"fresh_native_packing_us":stats(compression)})
 print("RECIPIENT_PERF_RESULT ",JSON.stringify({"reports":reports,"native":preload("res://deathmatch/network/codec.gd").native_codec!=null,"scope":"16 fully tracked players on 25m grid, 32 projectiles, 30Hz, 20 warmup + 80 samples; includes projection/encoding/compression, no transport or rendering"}))
 fixture.free();pose.free();actor.free();quit()
