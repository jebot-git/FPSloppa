extends SceneTree
const CS=preload("res://deathmatch/movement/cs16.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var native=preload("res://deathmatch/native/movement.gd").create()
 check(native!=null,"native movement available")
 var rng:=RandomNumberGenerator.new();rng.seed=171020
 var maximum:=0.0
 for i in 2000:
  var velocity:=Vector2(rng.randf_range(-20,20),rng.randf_range(-20,20));var wish:=Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1)).limit_length(1)
  var speed:=rng.randf_range(.2,8);var ground:=i%2==0;var dt:float=1./[30,60,90,120][i%4];var stamina:=rng.randf_range(0,1.4);var edge:=i%3==0
  var a:Vector2=native.horizontal(velocity,wish,speed,ground,dt,stamina,edge);var b:=CS.horizontal(velocity,wish,speed,ground,dt,stamina,edge)
  maximum=maxf(maximum,a.distance_to(b))
 check(maximum<.00002,"shared horizontal kernel parity: "+str(maximum))
 var world:=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,-.5,0),Vector3(100,1,100))
 Fixture.box(world,Vector3(0,.1,-4),Vector3(4,.2,2))
 Fixture.box(world,Vector3(0,.3,-6),Vector3(4,.6,2))
 var reference:=Fighter.new();reference.native_movement=null;reference.setup(1,"Reference",Color.WHITE);world.add_child(reference);reference.set_process(false);reference.configure_cs16(true)
 var actual:=Fighter.new();actual.setup(2,"Native",Color.WHITE);world.add_child(actual);actual.set_process(false);actual.configure_cs16(true)
 # Separate collision layers prevent the two probes colliding with each other.
 reference.collision_mask=1;actual.collision_mask=1
 reference.position=Vector3(0,.01,2);actual.position=reference.position
 for i in 180:
  await physics_frame
  var input:=Vector2(0,-1) if i<90 else Vector2(.4,.3)
  var jump:=i==100
  reference.simulate(input,0,false,1./60,jump);actual.simulate(input,0,false,1./60,jump)
  if i%15==0:check(reference.position.distance_to(actual.position)<.01 and reference.velocity.distance_to(actual.velocity)<.02,"collision, stairs and jump parity "+str(i))
 var old:=Transform3D(Basis(Vector3.UP,3.1),Vector3(1,2,3));var next:=Transform3D(Basis(Vector3.UP,-3.1),Vector3(5,4,7))
 var out:Dictionary=native.vehicles(PackedInt64Array([1]),[[old,Vector3.FORWARD,3.1]],[[next,Vector3.RIGHT,-3.1]],PackedFloat64Array([10.,.1,1.,1.,0.]),10.05,.2)
 check(out[1][0].is_equal_approx(old.interpolate_with(next,.5)) and absf(absf(out[1][2])-PI)<.00001,"vehicle interpolation and wrapped yaw")
 var snap:Dictionary=native.vehicles(PackedInt64Array([1]),[[old,Vector3.FORWARD,3.1]],[[Transform3D(Basis.IDENTITY,Vector3(100,0,0)),Vector3.RIGHT,0.]],PackedFloat64Array([10.,.1,1.,1.,0.]),10.05,.2)
 check(snap[1][0].origin==Vector3(100,0,0),"vehicle teleport does not interpolate")
 world.free();print("CQ_NATIVE_MOTION ",JSON.stringify({"checks":checks,"failures":failures,"horizontal_error":maximum}));quit(0 if failures.is_empty() else 1)
