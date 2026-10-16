extends SceneTree
const Motion=preload("res://deathmatch/native/movement.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class Body extends CharacterBody3D:
 var blast_velocity:=Vector2(.2,.3)
 var target:=Vector3.ZERO
 var target_yaw:=0.0
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func reference_fields(rows:Array,players:Dictionary,bodies:Dictionary,mine:int,clock:float)->void:
 for row in rows:
  var id:int=row[0]
  if not bodies.has(id):continue
  var state:Dictionary=players[id];var actor=bodies[id]
  state.merge({"yaw":row[3],"pitch":row[4],"hp":row[5],"armor":row[6],"dead":row[7],"weapon":row[8],"ammo":row[9],"owned":row[10],"kills":row[11],"deaths":row[12],"ping":row[13],"serial":row[14],"cooldown":row[17],"offhand_cooldown":row[19],"spectator":row[20]},true)
  var old:Vector2=actor.blast_velocity;actor.blast_velocity=row[21]
  if id!=mine:actor.velocity.x+=actor.blast_velocity.x-old.x;actor.velocity.z+=actor.blast_velocity.y-old.y
  state.respawn_at=clock+row[15];state.invulnerable=clock+1 if row[16] else 0;actor.target=row[1];actor.target_yaw=row[3]
func _initialize()->void:run.call_deferred()
func run()->void:
 var kernel=Motion.create();check(kernel!=null and kernel.has_method("snapshot_apply_fields") and kernel.has_method("prediction_reconcile"),"native state APIs")
 if failures.size():quit(1);return
 var timings:Array=[]
 for count in [64,128]:
  var states:Dictionary={};var bodies:Dictionary={};var copies:Dictionary={};var rows:Array=[]
  for id in range(1,count+1):
   states[id]={"name":"Keep me","custom":123};var actor:=Body.new();root.add_child(actor);actor.velocity=Vector3(1,2,3);bodies[id]=actor
   var other:=Body.new();root.add_child(other);other.velocity=actor.velocity;copies[id]=other
   rows.append([id,Vector3(id,1,2),Vector3(3,4,5),.3,.2,80,20,false,4,[12,13,14,15],[2,4],8,9,1,3,1.5,true,.25,{},.1,false,Vector2(.4,.7)])
  var expected:Dictionary=states.duplicate(true);var original:=rows.duplicate(true)
  reference_fields(rows,expected,copies,1,100.);check(kernel.snapshot_apply_fields(rows,states,bodies,1,100.),"native state batch applied")
  check(states==expected,"all fields, timers and retained metadata match")
  check(rows==original,"source rows unmodified")
  for id in bodies:check(bodies[id].velocity.is_equal_approx(copies[id].velocity) and bodies[id].blast_velocity==copies[id].blast_velocity and bodies[id].target==copies[id].target and bodies[id].target_yaw==copies[id].target_yaw,"body fields parity %d"%id)
  check(bodies[1].velocity==Vector3(1,2,3),"local velocity not changed by remote blast update")
  var invalid:=rows.duplicate(true);invalid[-1]=[];var before:=states.duplicate(true);check(not kernel.snapshot_apply_fields(invalid,states,bodies,1,200.) and states==before,"malformed batch fails before mutation")
  var n:=100;var start:=Time.get_ticks_usec()
  for i in n:reference_fields(rows,expected,copies,1,100.)
  var reference_us:float=(Time.get_ticks_usec()-start)/float(n);start=Time.get_ticks_usec()
  for i in n:kernel.snapshot_apply_fields(rows,states,bodies,1,100.)
  timings.append({"players":count,"reference_us":reference_us,"native_us":(Time.get_ticks_usec()-start)/float(n)})
  for actor in bodies.values():actor.free()
  for actor in copies.values():actor.free()
 var world:=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,-.5,0),Vector3(30,1,30))
 var a:=Fighter.new();a.setup(1,"Native",Color.WHITE);world.add_child(a);a.set_process(false);a.set_physics_process(false)
 var b:=Fighter.new();b.setup(2,"Reference",Color.WHITE);world.add_child(b);b.set_process(false);b.set_physics_process(false)
 await physics_frame;await physics_frame
 for scenario in range(12):
  for actor in [a,b]:
   actor.reset_view();actor.position=Vector3(0,2,0);actor.velocity=Vector3(1,3,0);actor.cs16_enabled=true;actor.cs16_stamina=.7
   actor.jetpack_state=actor.Jetpack.fresh();actor.jetpack_state.activation=2;actor.jetpack_state.time=10.;actor.jetpack_state.distance=3.;actor.jetpack_state.age=.6
   if scenario<9:
    var saved:Dictionary=actor.jetpack_state.duplicate(true);saved.time=9.8;saved.distance=2.
    actor.prediction.remember(5,Vector3(0,2,0),Vector3(1,-2,0),1.65,saved,.5)
    actor.prediction.remember(6,Vector3(.1,2,0),Vector3(1,2,0),1.65,saved,.4)
  var jet:Dictionary=a.Jetpack.fresh();jet.activation=1 if scenario==7 else 2;jet.cooldown=3.;jet.mode=1 if scenario==8 else 0;jet.distance=1.
  var position:=Vector3(4 if scenario in [6,11] else .6,2,0);var height:float=.65 if scenario==5 else -1.;var seq:int=4 if scenario==10 else 5
  a.prediction.reconcile(a,seq,position,Vector3(2,0,0),height,true,jet,.3)
  b.prediction.reconcile_reference(b,seq,position,Vector3(2,0,0),height,true,jet,.3)
  check(a.position.is_equal_approx(b.position) and a.velocity.is_equal_approx(b.velocity),"reconciliation motion %d"%scenario)
  check(a.jetpack_state==b.jetpack_state and is_equal_approx(a.cs16_stamina,b.cs16_stamina) and is_equal_approx(a.collision_height,b.collision_height),"reconciliation jetpack/stamina/posture %d"%scenario)
  check(a.prediction.samples==b.prediction.samples and a.prediction.stats==b.prediction.stats and a.prediction.acknowledged==b.prediction.acknowledged,"reconciliation histories and ACKs %d"%scenario)
 world.free()
 print("NATIVE_CLIENT_STATE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"timings":timings}));quit(0 if failures.is_empty() else 1)
