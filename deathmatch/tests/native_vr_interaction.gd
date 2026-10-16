extends SceneTree
const Aim=preload("res://deathmatch/vr/aim_support.gd")
const Stock=preload("res://deathmatch/vr/virtual_stock.gd")
const Swim=preload("res://deathmatch/vr/swim_strokes.gd")
const Throw=preload("res://deathmatch/vr/throw_ballistics.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok and failures.size()<30:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 check(ClassDB.class_exists("FPSVRInteraction"),"Native interaction capability loaded")
 if not ClassDB.class_exists("FPSVRInteraction"):quit(1);return
 var rng:=RandomNumberGenerator.new();rng.seed=800235
 # Stateful differential sequences include grip loss, weapon swaps, both hands,
 # engagement hysteresis, shoulder entry, smoothing and tracking discontinuities.
 for rules in ["cq","cs16","quake","ut99","tribes","doom"]:
  var a=Aim.new();var ar=Aim.new();ar.native=null
  var s=Stock.new();var sr=Stock.new();sr.native=null
  for i in 1200:
   var w:int=rng.randi_range(0,16) if i%60==0 else a.last_weapon
   var valid:=i%77!=0;var holding:=i%51!=0;var smooth:=i%2==0
   var head:=Transform3D(Basis(Vector3.UP,sin(i*.03)*.1),Vector3(0,1.7,0))
   var p:=Transform3D(Basis.from_euler(Vector3(sin(i*.17)*.15,cos(i*.09)*.08,0)),Vector3(.18,1.47,-.1)+Vector3(0,0,sin(i*.02)*.45))
   var support:=p.translated(p.basis*Vector3(0,.035,-.25)*.65)
   if i%90>70:support.origin+=Vector3(1,0,1)
   a.advance(.011);ar.advance(.011);s.advance(.011);sr.advance(.011)
   var got:Transform3D=a.solve(p,support,w,holding,valid,rules,smooth)
   var expected:Transform3D=ar.solve(p,support,w,holding,valid,rules,smooth)
   check(got.is_equal_approx(expected) and a.engaged==ar.engaged and is_equal_approx(a.blend,ar.blend),"Aim state/transform parity %s %d"%[rules,i])
   got=s.solve(p,support,head,w,i%2==0,valid,rules,smooth)
   expected=sr.solve(p,support,head,w,i%2==0,valid,rules,smooth)
   check(got.is_equal_approx(expected) and s.engaged==sr.engaged and is_equal_approx(s.blend,sr.blend),"Stock state/transform parity %s %d"%[rules,i])
 var swim=Swim.new();var reference=Swim.new();reference.native=null
 for i in 2000:
  var head:=Transform3D(Basis(Vector3.UP,.2),Vector3(0,1.7,0))
  var left:=Vector3(-.2,1.3+sin(i*.12)*.12,sin(i*.15)*.2)
  var right:=Vector3(.2,1.3+cos(i*.12)*.12,cos(i*.15)*.2)
  if i%173==0:left=Vector3(INF,0,0)
  var dt:=.2 if i%179==0 else .011
  var got:Vector3=swim.sample(head,left,right,dt,i%193!=0)
  var expected:Vector3=reference.sample(head,left,right,dt,i%193!=0)
  check(got.is_equal_approx(expected) and is_equal_approx(swim.strength,reference.strength),"Stroke parity %d"%i)
 for i in 500:
  var v:=Vector3(rng.randf_range(-20,20),rng.randf_range(-20,20),rng.randf_range(-20,20))
  var bounded:=v.limit_length(12);var expected:Vector3=(bounded*lerpf(1.,4.8,clampf((bounded.length()-.65)/1.35,0,1))).limit_length(40)
  check(Throw.launch(v).distance_to(expected)<.00002,"Throw gain/speed cap parity")
 check(Throw.launch(Vector3(NAN,0,0))==Vector3.ZERO,"Invalid tracked velocity rejected")
 # Real engine sweep parity against an obstacle, including start overlap.
 var world:=Node3D.new();root.add_child(world)
 var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,4,.2);shape.shape=box;body.add_child(shape);world.add_child(body);body.position=Vector3(0,0,-2)
 await physics_frame;await physics_frame
 var space:=world.get_world_3d().direct_space_state
 for start in [Vector3.ZERO,Vector3(0,0,-2),Vector3(5,0,0)]:
  var native:PackedVector3Array=Throw.arc(space,start,Vector3(0,1,-5),1.)
  var script:=arc_reference(space,start,Vector3(0,1,-5),1.)
  check(native.size()==script.size(),"Swept arc sample count parity")
  if native.size()==script.size():
   for i in native.size():check(native[i].distance_to(script[i])<.00002,"Swept arc collision position parity")
 world.free()
 print(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
 quit(0 if failures.is_empty() else 1)
func arc_reference(space:PhysicsDirectSpaceState3D,start:Vector3,velocity:Vector3,duration:float)->PackedVector3Array:
 var result:=PackedVector3Array([start]);var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.12
 query.shape=sphere;query.collision_mask=1;query.margin=.001;query.transform=Transform3D(Basis.IDENTITY,start)
 if not space.intersect_shape(query,1).is_empty():return result
 for i in ceili(minf(duration,2.)*30):
  velocity.y-=20./30.;var end:=start+velocity/30.;query.transform.origin=start;query.motion=end-start
  var sweep:=space.cast_motion(query)
  if sweep[0]<1.:
   result.append(start.lerp(end,maxf(0,sweep[0])));break
  start=end;result.append(start)
 return result
