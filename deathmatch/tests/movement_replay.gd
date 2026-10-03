extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
var sound_count:=0
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var world:=Node3D.new();root.add_child(world)
 Fixture.box(world,Vector3(0,-.5,0),Vector3(50,1,50))
 Fixture.box(world,Vector3(4,1,0),Vector3(.1,2,20))
 Fixture.box(world,Vector3(0,.1,-3),Vector3(4,.2,1))
 var authority:=Fighter.new();authority.setup(1,"Server",Color.WHITE);world.add_child(authority)
 var client:=Fighter.new();client.setup(2,"Client",Color.WHITE);world.add_child(client)
 for actor in [authority,client]:actor.collision_layer=0;actor.collision_mask=1;actor.quake_movement=true;actor.position=Vector3(0,.01,0)
 if "--cs16" in OS.get_cmdline_user_args():
  for actor in [authority,client]:actor.configure_cs16(true)
 client.movement_sound.connect(func(_kind,_where):sound_count+=1)
 await physics_frame;await physics_frame
 client.position.x=.15
 var replay_times:Array=[]
 var snapshots:Array=[];var worst_after_settle:=0.;var duplicate_sounds:=0
 for tick in 220:
  await physics_frame
  var dt:=1./60.
  var move:=Vector2.RIGHT if tick<45 else Vector2(0,-1) if tick<100 else Vector2.LEFT if tick<160 else Vector2.ZERO
  var jump:=tick==70 or tick==130
  if tick==110:authority.apply_blast(Vector3(-3,4,0))
  if authority.cs16_enabled and tick==115:authority.cs16_stamina=.8
  authority.simulate(move,0,false,dt,jump)
  snapshots.append({"seq":tick,"position":authority.position,"velocity":authority.velocity,"state":authority.locomotion_state()})
  if snapshots.size()>6:
   var echo:Dictionary=snapshots.pop_front()
   client.prediction.queue_authority(echo.seq,echo.position,echo.velocity,echo.state)
   var sounds_before:=sound_count
   var started:=Time.get_ticks_usec()
   client.prediction.apply_pending(client)
   replay_times.append(Time.get_ticks_usec()-started)
   duplicate_sounds+=sound_count-sounds_before
  var command:Dictionary={"move":move,"yaw":0.,"slow":false,"delta":dt,"jump":jump,"swim":Vector3.ZERO,"height":1.65,"room":Vector3.ZERO,"jet_request":false,"jet_enabled":false,"jet_blocked":false,"speed":1.,"environment":client.prediction_environment()}
  client.simulate(move,0,false,dt,jump)
  client.prediction.remember(tick,client.position,client.velocity,client.collision_height,{}, {},command,client.prediction_state())
  if tick>180:worst_after_settle=maxf(worst_after_settle,client.position.distance_to(authority.position))
 check(client.prediction.stats.get("replays",0)>0 and client.prediction.stats.get("replays",0)+client.prediction.stats.get("confirmed",0)>100,"Delayed snapshots execute fixed-tick collision replay")
 check(worst_after_settle<.04,"Replay converges after strafe, wall, steps, jumps and external impulse (error %.5f)"%worst_after_settle)
 check(duplicate_sounds==0,"Replay never duplicates movement sounds")
 check(client.position.x<3.7,"Replay does not penetrate the wall")
 if authority.cs16_enabled:check(absf(client.cs16_stamina-authority.cs16_stamina)<.001,"Delayed authority restores and replays hidden CS jump fatigue")
 var before:=client.position
 client.prediction.queue_authority(1,Vector3(100,0,0),Vector3.ZERO,{})
 client.prediction.apply_pending(client)
 check(client.position==before,"Out-of-order authority cannot rewind newer movement")
 var prediction_stats:Dictionary=client.prediction.stats.duplicate()
 replay_times.sort()
 world.free();await process_frame
 print("MOVEMENT_REPLAY_RESULT ",JSON.stringify({"failures":failures,"settled_error":worst_after_settle,"prediction":prediction_stats,"six_tick_reconcile_median_us":replay_times[replay_times.size()/2],"six_tick_reconcile_p95_us":replay_times[int(replay_times.size()*.95)]}));quit(0 if failures.is_empty() else 1)
