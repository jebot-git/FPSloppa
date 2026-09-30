extends SceneTree
const Fixture=preload("res://deathmatch/tests/native_network_packing.gd")
const FullPose=preload("res://tools/native_study/remaining_network.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
const Movement=preload("res://deathmatch/network/movement_delivery.gd")
const Fire=preload("res://deathmatch/network/fire_delivery.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
func stats(rows:Array) -> Dictionary:
 rows.sort();return {"median":rows[rows.size()/2],"p95":rows[ceili(rows.size()*.95)-1]}
func _initialize():
 var fixture=Fixture.new();var poses=FullPose.new();var actor=Fighter.new()
 var reports:Array=[]
 for enhanced in [false,true]:
  var sender:=Replication.new();var times:Array=[];var sizes:Array=[];var large:=0
  for tick in 140:
   var state:Array=fixture.snapshot(16,32,false,tick)
   for row in state[0]:
    row[18]=poses.full_pose(tick*.05+row[0])
    var locomotion:Dictionary={"height":1.65,"grounded":true,"jump_ack":tick,"jetpack_owned":false,"jetpack_ack":0,"fire_ack":tick}
    if enhanced:
     locomotion.replay=actor.prediction_state();locomotion.shot_counts={};locomotion.fire_results=[]
     for n in 8:
      locomotion.shot_counts["0:"+str(tick+n)]=n+1
      locomotion.fire_results.append([tick+n,"fired",1])
    state[10].locomotion[row[0]]=locomotion
   var start:=Time.get_ticks_usec();var batch:=sender.packets(state);var elapsed:=Time.get_ticks_usec()-start
   if tick<20:continue
   times.append(elapsed);var size:=0
   for packet in batch.normal+batch.large:size+=packet.size()
   sizes.append(size);large+=batch.large.size()
  reports.append({"enhanced":enhanced,"encoding_us":stats(times),"bytes":stats(sizes),"oversized_records":large})
 var input_reports:Array=[]
 for scenario in ["baseline","typical","saturated"]:
  var moves:=Movement.new();var fire:=Fire.new();var inputs:Array=[];var timings:Array=[]
  var memory_before:int=Performance.get_monitor(Performance.MEMORY_STATIC)
  for tick in 240:
   var command:Dictionary={"seq":tick,"map_epoch":1,"input_life":1,"move":Vector2(.4,.8),"yaw":tick*.01,"pitch":.2,"fire":tick%2==0 if scenario=="saturated" else tick%60<30,"slow":false,"weapon":6,"respawn":false,"jump":false,"crouch":false,"prone":false,"input_blocked":false,"room":Vector3(.01,0,0),"swim":Vector3.ZERO,"view_time":tick/60.,"xr":poses.full_pose(tick*.05)}
   var start:=Time.get_ticks_usec()
   if scenario!="baseline":
    moves.sample(command,1);fire.sample(command,1,tick/60.)
    if scenario=="typical" and tick%60==7:fire.acknowledge(1,fire.event)
    moves.annotate(command);fire.annotate(command,tick/60.)
   var bytes:=preload("res://deathmatch/network/input_delivery.gd").pack(command)
   timings.append(Time.get_ticks_usec()-start);inputs.append(bytes.size())
   if bytes.is_empty() or bytes.size()>1100:push_error("Input exceeds datagram budget");quit(1);return
  input_reports.append({"scenario":scenario,"bytes":stats(inputs),"max_bytes":inputs.max(),"build_pack_us":stats(timings),"retained_static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))-memory_before,"history_count":moves.history.size(),"pending_edges":fire.pending.size()})
 print("RESPONSIVENESS_PERF_RESULT ",JSON.stringify({"native_codec":Codec.native_codec!=null,"native_packing":Codec.native_codec!=null and Codec.native_codec.has_method("encode_records") and not OS.get_cmdline_user_args().has("--gdscript-network-packing"),"snapshots":reports,"inputs":input_reports,"scope":"16 full-body actors, 32 projectiles, 8 recent shot identities; 20 warmup + 120 changing snapshots. Input: 240 samples, typical 1 edge/sec and 100ms receipt, saturated 30 edges/sec without receipt. Memory includes retained measurement arrays, not an allocation count. No rendering or ENet."}))
 actor.free();fixture.free();poses.free();quit()
