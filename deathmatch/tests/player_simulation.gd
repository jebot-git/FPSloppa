extends SceneTree
## Differential state transitions, lifecycle guards and realistic 32/64-player microbenchmarks.
const Runtime=preload("res://deathmatch/native/runtime.gd")
const Delivery=preload("res://deathmatch/network/input_delivery.gd")
const Fire=preload("res://deathmatch/network/fire_delivery.gd")
const Test=preload("res://deathmatch/tests/cq_battery_tank.gd")
const Attribution=preload("res://deathmatch/server/attribution.gd")
class FakeActor extends RefCounted:
 var jetpack_requested:=false
 var jump_held:=true
var checks:=0
var failures:Array=[]
var rng:=RandomNumberGenerator.new()
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func state()->Dictionary:
 return {"serial":1,"last_seq":-1,"last_input":0.,"dead":false,"spectator":false,"move":Vector2.ZERO,"room":Vector3.ZERO,"swim":Vector3.ZERO,"jump":false,"fire":false,"alt_fire":false,"offhand_fire":false,"melee":false,"input_blocked":false,"weapon":6,"cooldown":.1,"offhand_cooldown":.2,"charge":0.,"held":false,"offhand_held":false}
func command(seq:int)->Dictionary:
 return {"seq":seq,"move":Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2)),"yaw":rng.randf_range(-20,20),"pitch":rng.randf_range(-3,3),"fire":bool(seq%2),"weapon":6,"slow":bool(seq%3),"respawn":false,"input_life":1,"jump_event":seq%35,"jump_seq":seq,"jetpack_event":seq%35,"fire_event":[seq%35,6,seq%7+1],"input_blocked":seq%11==0,"jump":seq%7==0,"fly":rng.randf_range(-2,2),"physical":seq%5==0,"prone":seq%3==0,"crouch":seq%4==0,"melee":seq%8==0,"alt_fire":seq%9==0,"offhand_fire":seq%10==0,"view_time":rng.randf()}
func header_reference(s:Dictionary,c:Dictionary,now:float)->void:
 s.last_seq=c.seq;s.last_input=now
 var view=c.get("view_time",-1.)
 s.view_time=float(view) if (view is float or view is int) and is_finite(float(view)) else -1.
 Delivery.accept(s,c)
func begin_reference(s:Dictionary,now:float,actor=null)->int:
 if now-s.last_input>.35:
  s.move=Vector2.ZERO;s.room=Vector3.ZERO;s.swim=Vector3.ZERO;s.jump=false;s.fire=false;s.offhand_fire=false;s.alt_fire=false;s.melee=false;s.input_blocked=true
 if actor==null:actor=FakeActor.new()
 var jump:=Delivery.consume(s,actor)
 return int(jump)|(2 if actor.jetpack_requested else 0)|(4 if not actor.jump_held else 0)
func advance_reference(s:Dictionary,dt:float)->bool:
 s.cooldown=maxf(0,s.cooldown-dt);s.offhand_cooldown=maxf(0,s.offhand_cooldown-dt)
 if s.charge>0:s.charge-=dt;return s.charge<=0
 return false
func run()->void:
 rng.seed=176041
 check(Runtime.available("FPSBackend"),"Native backend available")
 if not Runtime.available("FPSBackend"):quit(1);return
 var backend=ClassDB.instantiate("FPSBackend")
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.dedicated=true;game.start_host("Player state suite",28829,100,15,false);game._add_player(1,"Fixture")
 # Full input adapter differential includes pose rejection and equipment guards.
 for i in 300:
  var c:=command(i);c.weapon=game.players[1].weapon;c.input_life=game.players[1].serial
  if i%3==0:c.xr=preload("res://deathmatch/vr/poses.gd").neutral()
  if i%13==0:c.xr={"head":"invalid"}
  if i%17==0:c.input_life=-1
  if i%19==0:c.seq=2147483648
  var original:Dictionary=game.players[1].duplicate(true)
  game.native_input_state_enabled=false;game._accept_input(1,c);var expected:Dictionary=game.players[1].duplicate(true)
  game.players[1]=original.duplicate(true);game.native_input_state_enabled=true;game._accept_input(1,c)
  check(game.players[1]==expected,"Full input adapter parity %d"%i)
  if game.players[1]!=expected:
   for k in expected:if game.players[1].get(k)!=expected[k]:print("MISMATCH ",k," expected=",expected[k]," actual=",game.players[1].get(k))
 for i in 1200:
  var a:=state();a.serial=i%4;a.dead=i%19==0;a.spectator=i%23==0;a.last_input=rng.randf();a.jump_pending=i%3==0;a.jump_received=i
  a.jetpack_pending=i%7==0;a.input_blocked=i%11==0;a.charge=[0.,.01,.5,-.1][i%4];a.fire_pending=[6,i%7+1,.8]
  var b:=a.duplicate(true);backend.bind_players({42:b})
  var now:=rng.randf();check(begin_reference(a,now)==backend.begin_player(42,now),"Delivery bits %d"%i);check(a==b,"Delivery state %d"%i)
  check(advance_reference(a,1./30)==backend.advance_player(42,1./30),"Charge completion %d"%i);check(a==b,"Timer state %d"%i)
  var saved:=Fire.begin_attempt(a,now,i%2==0);var actual:Array=backend.begin_player_fire(42,now,i%2==0)
  check(saved==actual and a==b,"Trigger edge state %d"%i)
  Fire.end_attempt(a,saved);backend.end_player_fire(42,actual);check(a==b,"Trigger restoration %d"%i)
  var c:=command(i);c.input_life=a.serial
  header_reference(a,c,now);backend.accept_input_header(b,c,now);check(a==b,"Header/jump/jetpack parity %d"%i)
  Fire.accept(a,c,now);backend.accept_fire_event(b,c,now);check(a==b,"Fire event acceptance %d"%i)
 # Stateful reload-motion differential: fresh/repeated/gapped tracking, head-only
 # shifts, translated/rotated bodies, both handedness and fast invalid sweeps.
 var Motion=preload("res://deathmatch/conquest/classes/reload_motion.gd")
 var motion_a:Dictionary={};var motion_b:Dictionary={};var stamp:=0.
 for i in 1600:
  if i%53==0:motion_a={"gestures":{"active":true}};motion_b=motion_a.duplicate(true)
  stamp+=[0.,.004,.008,1./30,.16,.161,.5][i%7]
  var yaw:=i*.001;var base:=Vector3(i*.002,1.5,0)
  if i%41==0:base+=Vector3(2,0,2)
  var pose:Dictionary={"head":Transform3D(Basis(Vector3.UP,yaw),base),"weapon":Transform3D(Basis(Vector3.UP,yaw*.5),base+Vector3(.2,-.3,-.4))}
  var hand:=Transform3D(Basis.IDENTITY,base+Vector3(rng.randf_range(-.02,.02),-.2,-.45))
  var weapon:=Transform3D(pose.weapon.basis.scaled(Vector3.ONE*.65),pose.weapon.origin)
  var reference_motion:Dictionary=Motion.sample_reference(motion_a,pose,weapon,hand,stamp)
  var native_motion:Dictionary=backend.sample_reload_motion(motion_b,pose,weapon,hand,stamp)
  check(reference_motion==native_motion and motion_a==motion_b,"Reload motion exact state %d"%i)
 # Invalid variants must be rejected without mutating producer state.
 var values:Array=[null,true,0,1.,"bad",Vector2(INF,0),Vector3.ZERO,{},[],NAN]
 for field in ["seq","move","yaw","pitch","fire","weapon","slow","respawn"]:
  var absent:=command(1);absent.erase(field);check(not backend.valid_input(absent),"Missing "+field)
  for v in values:
   var c:=command(1);c[field]=v
   check(backend.valid_input(c)==game._valid_input_reference(c),"Validation "+field+" "+str(v))
 for event_field in ["jump_event","jetpack_event","jump_seq","fire_event","input_life","view_time"]:
  for value in [null,true,-1,1,2147483648,1.,NAN,"bad",{},[],[1,6,1],[true,6,1],[1,6,8]]:
   # Legacy helpers throw on non-numeric life values; compare their supported
   # numeric domain, including float-valued life IDs, without masking errors.
   if event_field=="input_life" and not (value is int or value is float):continue
   var a:=state();var b:=a.duplicate(true);var c:=command(1);c[event_field]=value
   header_reference(a,c,.5);backend.accept_input_header(b,c,.5)
   Fire.accept(a,c,.5);backend.accept_fire_event(b,c,.5)
   check(a==b,"Malformed event parity "+event_field+" "+str(value))
 var old_budget:int=game.bandwidth.realtime_bytes
 var fanout_thread:=Thread.new();fanout_thread.start(func():return backend.send_snapshot_batch(game,game.bandwidth,[PackedByteArray([1])],[],[1],0.))
 check(not fanout_thread.wait_to_finish() and game.bandwidth.realtime_bytes==old_budget,"Non-owner fanout cannot send or reserve budget")
 backend.bind_players({});check(backend.get_player_state_count()==0 and backend.begin_player(42,1.)==0,"Departed players released")
 var old:=state();backend.bind_players({42:old});var fresh:=state();fresh.serial=2;backend.bind_players({42:fresh});backend.advance_player(42,.05)
 check(old.cooldown==.1 and fresh.cooldown==.05,"Peer reuse binds current life only")
 var thread:=Thread.new();thread.start(func():backend.bind_players({});return backend.begin_player(42,1.));var bits=thread.wait_to_finish()
 check(bits==0 and backend.get_player_state_count()==1,"Non-owner calls cannot touch player state")
 check(not backend.send_snapshot_batch(null,null,[],[],[],0.),"Invalid fanout rejected")
 var benchmarks:Array=[]
 for population in [32,64]:
  for native in [false,true]:
   var roster:Dictionary={}
   var actors:Dictionary={}
   for id in population:roster[id]=state();actors[id]=FakeActor.new()
   var samples:Array=[]
   for tick in 800:
    var began:=Time.get_ticks_usec()
    if native:backend.bind_players(roster)
    for id in roster:
     if native:
      var bench_bits:int=backend.begin_player(id,0.);actors[id].jetpack_requested=bool(bench_bits&2)
      if bench_bits&4:actors[id].jump_held=false
      backend.advance_player(id,1./30)
      var previous:Array=backend.begin_player_fire(id,0.,true);backend.end_player_fire(id,previous)
     else:
      begin_reference(roster[id],0.,actors[id]);advance_reference(roster[id],1./30)
      var previous:=Fire.begin_attempt(roster[id],0.,true);Fire.end_attempt(roster[id],previous)
    if tick>=100:samples.append((Time.get_ticks_usec()-began)/1000.)
   samples.sort();benchmarks.append({"kind":"bookkeeping","players":population,"native":native,"p50_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"samples":samples.size()})
 for population in [32,64]:
  for native in [false,true]:
   var motion_states:Array=[]
   for id in population:motion_states.append({})
   var samples:Array=[];var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
   var weapon:=Transform3D(pose.weapon.basis.scaled(Vector3.ONE*.65),pose.weapon.origin)
   for tick in 500:
    var began:=Time.get_ticks_usec()
    for id in population:
     if native:backend.sample_reload_motion(motion_states[id],pose,weapon,pose.left,tick/30.)
     else:Motion.sample_reference(motion_states[id],pose,weapon,pose.left,tick/30.)
    if tick>=100:samples.append((Time.get_ticks_usec()-began)/1000.)
   samples.sort();benchmarks.append({"kind":"reload-motion","players":population,"native":native,"p50_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"samples":samples.size()})
 # Exercise complete main-thread tick scopes on the native stage.
 game.native_player_state_enabled=true;game.native_input_state_enabled=true
 for id in range(2,65):game._add_player(id,"Profile %d"%id)
 for id in game.players:
  game.fighters[id].position=Vector3(id*3,.05,id%3*4);game.players[id].invulnerable=1000.
 Attribution.reset();Attribution.enabled=true
 for tick in 30:
  game.clock+=1./30;game.players[1].last_input=game.clock;game.players[1].fire=false;game.players[1].fire_pending=[]
  for id in game.players:game.players[id].last_input=game.clock
  var start:=Time.get_ticks_usec();game._server_tick(1./30);Attribution.tick(Time.get_ticks_usec()-start,game.players.size())
 check(Attribution.summary().scope_errors==0,"Fine attribution closes on full ticks")
 Attribution.enabled=false
 game.disconnect_game("");game.queue_free();await process_frame
 print("PLAYER_SIMULATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"benchmarks":benchmarks,"attribution":Attribution.summary()}));quit(0 if failures.is_empty() else 1)
