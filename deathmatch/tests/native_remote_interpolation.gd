extends SceneTree
const Interpolation=preload("res://deathmatch/network/interpolation.gd")
class Actor extends Node3D:
 var target:=Vector3.ZERO
 var target_yaw:=0.0
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var actual:=Interpolation.new();var reference:=Interpolation.new();reference.native=null
 check(actual.native!=null,"native interpolation available")
 if not actual.native:quit(1);return
 var rng:=RandomNumberGenerator.new();rng.seed=1982
 var bodies:Dictionary={};var expected:Dictionary={}
 for id in range(1,66):
  var actor:=Actor.new();root.add_child(actor);actor.target=Vector3(id*.2,1,-2);actor.target_yaw=1.1;actor.rotation=Vector3(.1,.3,.2);bodies[id]=actor
  var other:=Actor.new();root.add_child(other);other.target=actor.target;other.target_yaw=actor.target_yaw;other.rotation=actor.rotation;expected[id]=other
 var mine:=1
 for step in 200:
  var now:float=step*.016
  if step%3==0:
   var stamp:float=10.+step*.016+rng.randf_range(-.005,.005)
   for id in range(2,65):
    var pos:=Vector3(id*.2+step*.01,0,sin(step*.02)*.2);var serial:=1 if step<99 else 2
    if step==150:pos+=Vector3(20,0,0)
    var yaw:float=3.05+step*.01
    for service in [actual,reference]:service.push(id,stamp,pos,Vector3.RIGHT,yaw,serial,now)
  if step==75:
   for service in [actual,reference]:service.push(2,10.,Vector3(999,0,0),Vector3.ZERO,0.,1,now)
  var a:float=actual.advance(now);var b:float=reference.advance(now)
  check(absf(a-b)<.0000001,"render clock and jitter parity %d"%step)
  actual.apply(bodies,mine,.016)
  for id in expected:
   if id==mine:continue
   var value:Dictionary=reference.sample(id)
   if not value.is_empty():expected[id].position=value.position;expected[id].rotation.y=value.yaw
   else:expected[id].position=expected[id].position.lerp(expected[id].target,.256);expected[id].rotation.y=lerp_angle(expected[id].rotation.y,expected[id].target_yaw,.256)
   check(bodies[id].position.is_equal_approx(expected[id].position) and bodies[id].rotation.is_equal_approx(expected[id].rotation),"batched body transform parity %d:%d"%[step,id])
  check(actual.sample(2)==reference.sample(2),"sample dictionary parity %d"%step)
 check(bodies[mine].position==Vector3.ZERO and bodies[mine].rotation.is_equal_approx(Vector3(.1,.3,.2)),"local tracked body untouched")
 check(actual.underruns==reference.underruns and absf(actual.delay-reference.delay)<.0000001,"telemetry parity")
 check(actual.tracks[2].size()<=12,"bounded native history")
 actual.erase(2);reference.erase(2);check(actual.sample(2).is_empty() and not actual.tracks.has(2),"departed body history removed")
 actual.reset();check(actual.tracks.is_empty() and actual.advance(200.)==-1 and actual.server_time==-1,"reset clears native clocks and history")
 # Snapshot ingestion must respect per-entity timestamps and membership before batching.
 reference.reset()
 for step in 2:
  var rows:Array=[]
  for id in [1,2,99]:
   var row:Array=[];row.resize(15);row[0]=id;row[1]=Vector3(step*.4,0,0);row[2]=Vector3.RIGHT;row[3]=3.1+step*.1;row[14]=7;rows.append(row)
  var times:Dictionary={2:22.+step*.1}
  check(actual.push_rows(rows,times,30.,step*.1,mine,bodies),"native snapshot batch accepted")
  for row in rows:
   if row[0]!=mine and bodies.has(row[0]):reference.push(row[0],times.get(row[0],30.),row[1],row[2],row[3],row[14],step*.1)
 actual.advance(.125);reference.advance(.125)
 check(actual.sample(2)==reference.sample(2),"batched snapshot ingestion parity")
 check(not actual.tracks.has(1) and not actual.tracks.has(99),"batch excludes local and absent bodies")
 check(absf(actual.server_time-reference.server_time)<.0000001,"batch uses per-entity source timestamps")
 var timings:Array=[]
 for count in [64,128]:
  var native:=Interpolation.new();var script:=Interpolation.new();script.native=null;var actors:Dictionary={}
  for id in range(1,count+1):
   var actor:=Actor.new();root.add_child(actor);actors[id]=actor
   for service in [native,script]:service.push(id,10.,Vector3.ZERO,Vector3.RIGHT,3.,1,0.);service.push(id,10.1,Vector3.RIGHT,Vector3.RIGHT,-3.,1,.1);service.advance(.125)
  var n:=500;var start:=Time.get_ticks_usec()
  for i in n:
   for id in actors:
    var sample:Dictionary=script.sample(id);actors[id].position=sample.position;actors[id].rotation.y=sample.yaw
  var reference_us:float=(Time.get_ticks_usec()-start)/float(n);start=Time.get_ticks_usec()
  for i in n:native.apply(actors,-1,.016)
  timings.append({"players":count,"reference_us":reference_us,"native_us":(Time.get_ticks_usec()-start)/float(n)})
  for actor in actors.values():actor.free()
 for actor in bodies.values():actor.free()
 for actor in expected.values():actor.free()
 print("NATIVE_REMOTE_INTERPOLATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"timings":timings}));quit(0 if failures.is_empty() else 1)
