extends SceneTree
const Runtime=preload("res://deathmatch/native/runtime.gd")
var authority
var world:Node3D
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func box(at:Vector3,size:Vector3)->Node3D:
 var body:=StaticBody3D.new();body.position=at;body.collision_layer=1
 var shape:=BoxShape3D.new();shape.size=size;var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);world.add_child(body);return body
func actor(id:int,at:Vector3,team:int=1)->Array:
 var body:=CharacterBody3D.new();body.position=at;body.collision_layer=2;body.collision_mask=3
 var shape:=CylinderShape3D.new();shape.radius=.3;shape.height=1.65;var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);world.add_child(body)
 var life:int=authority.attach_actor(id,body,collider,team,1<<2,PackedInt32Array([1000,1000,1000,1000]));check(life>0,"attach actor %d"%id);return [body,life]
func command(life:int,seq:int)->Dictionary:
 return {"life":life,"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":2,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false}
func tick()->void:
 await physics_frame
 check(authority.advance(),"one native tick inside physics frame")
func run()->void:
 Engine.physics_ticks_per_second=30
 check(Runtime.available("FPSAuthority"),"new authority registered")
 if not failures.is_empty():quit(1);return
 authority=ClassDB.instantiate("FPSAuthority");world=Node3D.new();root.add_child(world)
 check(authority.prepare_medic_test(1,-1).is_empty(),"medic fixture mutation unavailable to normal authority worlds")
 box(Vector3(0,-.5,0),Vector3(80,1,80))
 var first:=actor(1,Vector3.ZERO);var body:CharacterBody3D=first[0];var life:int=first[1]
 Engine.physics_ticks_per_second=60
 check(not authority.advance(),"reject mismatched host tick rate")
 Engine.physics_ticks_per_second=30
 await tick();await tick()
 check(authority.inspect(1).grounded,"Jolt ground contact")
 check(not authority.advance(),"reject duplicate advancement within same physics frame")
 var a:=command(life,0);a.crouch=true;check(authority.submit(1,a),"accept crouch");await tick();check(is_equal_approx(authority.inspect(1).height,1.05),"collider shrinks")
 var roof:=box(Vector3(0,1.4,0),Vector3(4,.2,4));await tick()
 a.seq=1;a.crouch=false;authority.submit(1,a);await tick();check(is_equal_approx(authority.inspect(1).height,1.05),"ceiling blocks standing growth")
 roof.queue_free();await tick();a.seq=2;authority.submit(1,a);await tick();check(is_equal_approx(authority.inspect(1).height,1.65),"can stand after roof removal")
 a.seq=3;a.prone=true;authority.submit(1,a);await tick();check(is_equal_approx(authority.inspect(1).height,.65),"prone collider")
 var state:Dictionary=authority.inspect(1);state.hp=0;check(authority.inspect(1).hp==100.,"inspection cannot mutate resident state")
 var snapshot:PackedByteArray=authority.snapshot();var original:=snapshot.duplicate();snapshot[0]=0;check(authority.snapshot()[0]==original[0],"published snapshot cannot mutate resident frame")
 for key in a:
  var invalid:=a.duplicate();invalid.erase(key);check(not authority.submit(1,invalid),"reject missing "+key)
 for field in ["move","yaw","pitch"]:
  var invalid:=a.duplicate();invalid.seq=100;invalid[field]=Vector2(NAN,0) if field=="move" else NAN;check(not authority.submit(1,invalid),"reject NaN "+field)
 var invalid:=command(life,100);invalid.xr={};check(not authority.submit(1,invalid),"unsupported XR is explicit rejection")
 var target:=actor(2,Vector3(0,0,-4),2);var target_life:int=target[1]
 a=command(life,4);a.fire=true;authority.submit(1,a);await tick();check(authority.inspect(2).hp==75.,"native hitscan resolves Jolt collider identity")
 var old_life:=life;check(authority.detach_actor(1,life),"detach actor");check(not authority.detach_actor(2,life),"cannot detach wrong life")
 body.queue_free();await tick();first=actor(1,Vector3(8,0,0));life=first[1];check(life!=old_life,"reconnected ID receives new life")
 check(not authority.submit(1,command(old_life,1000)),"old life input cannot control reconnect")
 var removed:CharacterBody3D=first[0];world.remove_child(removed);await tick();check(authority.inspect(1).is_empty(),"removed scene body is retired safely");removed.free()
 check(authority.inspect(2).life==target_life,"unrelated actor remains valid")
 # Compare against the actual shared GDScript CS movement reference, not a copied formula.
 var reference=preload("res://deathmatch/movement/cs16.gd")
 var walker:=actor(3,Vector3(20,0,20));var walker_life:int=walker[1]
 await tick();await tick()
 for index in 180:
  var before:Dictionary=authority.inspect(3)
  var c:=command(walker_life,index);c.move=Vector2(sin(index*.11),cos(index*.11))*.6;c.yaw=sin(index*.03);c.slow=index%50>25;c.crouch=index%90>60;c.prone=index%120>100
  check(authority.submit(3,c),"CS reference input %d"%index)
  await tick()
  var after:Dictionary=authority.inspect(3);var h:float=after.height
  var maximum:float=250./32*(.52 if c.slow else 1.)*(.18 if h<.8 else .333 if h<1.6 else 1.)
  var wish:Vector3=Basis(Vector3.UP,c.yaw)*Vector3(c.move.x,0,c.move.y)
  var expected:Vector2=reference.horizontal(Vector2(before.velocity.x,before.velocity.z),Vector2(wish.x,wish.z),maximum,true,1./30.)
  check(Vector2(after.velocity.x,after.velocity.z).distance_to(expected)<.0002,"CS reference horizontal parity %d"%index)
 world.queue_free();await process_frame
 print("AUTHORITY_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures,"physics":"Jolt"}));quit(0 if failures.is_empty() else 1)
