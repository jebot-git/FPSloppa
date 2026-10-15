extends SceneTree
## Exact wire/state differential and preparation benchmark on a populated CQ fixture.
const Test=preload("res://deathmatch/tests/cq_battery_tank.gd")
const Runtime=preload("res://deathmatch/native/runtime.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
const Attribution=preload("res://deathmatch/server/attribution.gd")
class BenchArena extends Test.TestArena:
 var reference:=false
 func _snapshot_preparation_backend():return null if reference else super._snapshot_preparation_backend()
class FakeTriggers extends RefCounted:
 var killed_targets:Dictionary={"fixture":true}
class FakeRuntime extends Node:
 var triggers:=FakeTriggers.new()
var failures:Array=[]
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func elapsed(values:Array)->Dictionary:
 values.sort();return {"p50_ms":values[values.size()/2],"p95_ms":values[int(values.size()*.95)],"samples":values.size()}
func run()->void:
 var backend=Runtime.backend();check(backend!=null and backend.has_method("prepare_snapshot"),"Native snapshot preparation available")
 if not backend or not backend.has_method("prepare_snapshot"):quit(1);return
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(BenchArena);root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.dedicated=true;game.start_host("Snapshot benchmark",28819,100,15,false)
 for id in range(1,65):game._add_player(id,"Snapshot %d"%id)
 var runtime:=FakeRuntime.new();runtime.name="MapRuntime";game.get_node("Map").add_child(runtime)
 var gate:=Node3D.new();game.add_child(gate);gate.position=Vector3(1,2,3)
 game.gates=[{"node":gate,"open":true,"bsp":true,"elevator":true}]
 game.pickups=[{"available":true,"node":null},{"available":false,"node":null}]
 for id in game.players:
  var state:Dictionary=game.players[id];var actor=game.fighters[id]
  state.xr=preload("res://deathmatch/vr/poses.gd").neutral();state.last_seq=id*3
  state.jump_ack=id;state.fire_ack=id+1;state.jetpack_ack=id+2
  actor.position=Vector3(id*2,.2,id*.4);actor.velocity=Vector3(1,0,-2)
  actor.update_height([.65,1.05,1.65][id%3],true)
  var magazine:Dictionary=game.variant_combat.magazines.state(id)
  magazine.clips[0]=id%8;magazine.reloading=0;magazine.reload_at=20.0
  magazine.physical[0]={"mag":true,"ready":false,"carry":3,"stroke":.2,"locked":true,"private_field":99}
  game.spotting.spotted[id]=[1.0,2.0]
 game.projectiles={100:{"position":Vector3(2,3,4),"owner":1,"weapon":0,"direction":Vector3.FORWARD,"yaw":.1,"pitch":.2},101:{"position":Vector3(5,6,7),"owner":2,"weapon":6,"direction":Vector3.RIGHT,"yaw":.3,"pitch":.4,"definition":{},"extra":{"spread":[1,2,3]},"velocity":Vector3(10,0,0),"life":2.0,"stuck":false}}
 var trials:Array=[]
 for tick in 16:
  game.clock=10.0+tick*.05;game.players[1].serial+=1
  game.defer_snapshot_classes=false;game.reference=true;var expected:Array=game._prepare_snapshot_reference()
  game.defer_snapshot_classes=tick>=8;game.reference=false;var actual:Array=backend.prepare_snapshot(game)
  if tick<8:
   check(actual==expected,"Complete snapshot differential tick %d"%tick)
   check(var_to_bytes(actual)==var_to_bytes(expected),"Exact snapshot value order and bytes tick %d"%tick)
  var reference_records:Array=Replication.new()._records(expected)
  check(backend.snapshot_records(actual)==reference_records,"Record layout differential tick %d"%tick)
  check(var_to_bytes(backend.snapshot_records(actual))==var_to_bytes(reference_records),"Exact record ordering tick %d"%tick)
  var sync:=Replication.new();var async_rep:=Replication.new();var packets:Dictionary=sync.packets(expected)
  check(async_rep.queue_packets(actual),"Frozen state accepted tick %d"%tick)
  # Mutate every kind of producer-owned container immediately after submission.
  actual[0][0][9][0]=-5;actual[0][0][18].head.origin.x=99;actual[10].ordnance[101].extra.spread[0]=99
  if tick>=8:
   game.classes.states[1].xp.shocktroop=-1;game.variant_combat.magazines.states[1].physical[0].carry=19;game.spotting.spotted[1][0]=99
  else:actual[10]["cp:1"].state.xp.shocktroop=-1
  var ready:Array=[];var deadline:=Time.get_ticks_msec()+5000
  while ready.is_empty() and Time.get_ticks_msec()<deadline:await process_frame;ready=async_rep.poll_packets()
  check(ready.size()==1,"Frozen completion tick %d"%tick)
  if ready.size()==1:
   check(ready[0].normal==packets.normal and ready[0].large==packets.large,"Exact packet bytes after producer mutation tick %d"%tick)
  async_rep.reset()
  # The sampled player rows may borrow game containers; restore test state.
  game.players[1].ammo[0]=99;game.players[1].xr.head.origin.x=0;game.classes.states[1].xp.shocktroop=0
  game.variant_combat.magazines.states[1].physical[0].carry=3;game.spotting.spotted[1][0]=1.0
 for count in [32,64]:
  var subset:Array=game.players.keys()
  # Keep the same scene and choose a fixed population for each measurement.
  var removed:Dictionary={};var actors:Dictionary={}
  for id in subset:
   if id>count:removed[id]=game.players[id];actors[id]=game.fighters[id];game.players.erase(id);game.fighters.erase(id)
  var timings:Dictionary={}
  for strategy in ["reference","hybrid","native","deferred"]:
   var reference:bool=strategy=="reference"
   game.reference=reference;game.defer_snapshot_classes=strategy=="deferred";var times:Array=[]
   for tick in 160:
    game.clock+=.05;var began:=Time.get_ticks_usec()
    var snapshot:Array=backend.prepare_snapshot(game) if strategy=="native" else game._prepare_snapshot_reference()
    if tick>=20:times.append((Time.get_ticks_usec()-began)/1000.)
    check(snapshot.size()==14,"Benchmark snapshot remains complete")
   timings[strategy]=elapsed(times)
  trials.append({"players":count,"timings":timings})
  game.players.merge(removed);game.fighters.merge(actors)
 var state:Array=backend.prepare_snapshot(game);var queue=ClassDB.instantiate("FPSBackend")
 var worker:=Thread.new()
 worker.start(func():return [backend.prepare_snapshot(game).is_empty(),not backend.submit_snapshot_state(state,[state[9],1,state[12]],1)])
 check(worker.wait_to_finish()==[true,true],"Scene capture and queue submission reject non-owner threads")
 var malformed:Array=state.duplicate(true);malformed[10]["_native_class_source"]=[]
 check(not queue.submit_snapshot_state(malformed,[state[9],1,state[12]],1),"Malformed deferred class source rejected")
 check(not queue.submit_snapshot_state([], [1,1,0.],1),"Malformed snapshot state rejected")
 check(not queue.submit_snapshot_state(state,[state[9]+1,1,state[12]],1),"Mismatched epoch rejected")
 check(queue.submit_snapshot_state(state,[state[9],1,state[12]],1) and queue.submit_snapshot_state(state,[state[9],2,state[12]],1) and not queue.submit_snapshot_state(state,[state[9],3,state[12]],1),"State queue retains two-job bound")
 queue.shutdown();queue=null
 var immutable=ClassDB.instantiate("FPSBackend")
 var immutable_state:Array=state.duplicate(true)
 game.defer_snapshot_classes=false
 var expected_immutable:Dictionary=Replication.new().packets(game._prepare_snapshot_reference())
 check(immutable.submit_snapshot_buffer(immutable_state,[state[9],1,state[12]],1),"Native immutable value buffer accepted")
 immutable_state[0][0][9][0]=-999;immutable_state[0][0][18].head.origin.x=999
 var immutable_ready:Array=[];var immutable_deadline:=Time.get_ticks_msec()+5000
 while immutable_ready.is_empty() and Time.get_ticks_msec()<immutable_deadline:await process_frame;immutable_ready=immutable.poll_snapshots()
 check(immutable.snapshot_buffer_stats().submitted==1 and immutable.snapshot_buffer_stats().fallback==0,"Immutable buffer executes without fallback")
 check(immutable_ready.size()==1,"Immutable buffer completes")
 if immutable_ready.size()==1:check(immutable_ready[0].normal==expected_immutable.normal and immutable_ready[0].large==expected_immutable.large,"Immutable buffer bytes survive nested producer mutation")
 var typed_values:Array[int]=[1,2,3]
 var typed_state:Array=state.duplicate(true);typed_state[10]["typed_fixture"]=typed_values
 var typed_public:Array=game._prepare_snapshot_reference();typed_public[10]["typed_fixture"]=typed_values
 var typed_expected:Dictionary=Replication.new().packets(typed_public)
 check(immutable.submit_snapshot_buffer(typed_state,[state[9],1,state[12]],2),"Typed array uses safe ownership fallback")
 typed_values[0]=99
 var typed_ready:Array=[];var typed_deadline:=Time.get_ticks_msec()+5000
 while typed_ready.is_empty() and Time.get_ticks_msec()<typed_deadline:await process_frame;typed_ready=immutable.poll_snapshots()
 check(typed_ready.size()==1 and typed_ready[0].normal==typed_expected.normal and typed_ready[0].large==typed_expected.large,"Typed fallback preserves exact bytes after mutation")
 check(immutable.snapshot_buffer_stats().fallback==1,"Typed container metadata preserved by fallback")
 immutable.shutdown()
 var guarded=ClassDB.instantiate("FPSBackend");var buffer_thread:=Thread.new()
 buffer_thread.start(func():return guarded.submit_snapshot_buffer(state,[state[9],1,state[12]],1))
 check(not buffer_thread.wait_to_finish(),"Immutable buffer rejects non-owner capture")
 check(not guarded.submit_snapshot_buffer([], [1,1,0.],1),"Immutable buffer rejects malformed state")
 check(guarded.submit_snapshot_buffer(state,[state[9],1,state[12]],1) and guarded.submit_snapshot_buffer(state,[state[9],2,state[12]],1) and not guarded.submit_snapshot_buffer(state,[state[9],3,state[12]],1),"Immutable buffer retains two-job bound")
 guarded.shutdown()
 game.pickups=[];game.gates=[];game.projectiles.clear();game.disconnect_game();game.free();await process_frame
 print("SNAPSHOT_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"trials":trials}));quit(0 if failures.is_empty() else 1)
