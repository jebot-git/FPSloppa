extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const DT:=1.0/60
var checks:=0
var failures:Array=[]
var world:Node3D
var actors:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func fighter(at:Vector3):
 var f=Fighter.new();world.add_child(f);f.setup(actors.size()+1,"Stack",Color.WHITE);f.set_process(false);f.position=at;f.configure_cs16(true);actors.append(f);return f
func settle(ticks:int=60):
 for i in ticks:
  await physics_frame
  for f in actors:
   if f.alive_state:f.simulate(Vector2.ZERO,f.rotation.y,false,DT)
func run():
 world=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,-.5,0),Vector3(40,1,40))
 var bottom=fighter(Vector3(0,.02,0));var upper=fighter(Vector3(.22,2,0));await settle()
 check(bottom.is_supported() and upper.is_supported() and absf(upper.position.y-bottom.position.y-1.655)<.01,"Off-centre player lands on a flat DE hull")
 var resting:Vector3=upper.position;await settle(120)
 check(upper.position.distance_to(resting)<.002,"Stack stays still without slipping down rounded shoulders")
 bottom.rotation.y=.73;await settle(30)
 check(upper.position.distance_to(resting)<.002,"Turning lower player leaves the flat support unchanged")
 var third=fighter(Vector3(.1,4,0));await settle(90)
 check(third.is_supported() and third.position.y>3.29 and third.position.y<3.34,"Three players can stack")
 third.show_alive(false,false);third.position=Vector3(8,0,0);await settle()
 upper.cs16_stamina=0
 await physics_frame;upper.simulate(Vector2.ZERO,0,false,DT,true)
 check(upper.velocity.y>7 and upper.position.y>resting.y+.1,"Player can jump from another player")
 await settle(100)
 check(upper.is_supported() and upper.position.distance_to(resting)<.015,"Player lands back on the stack")
 bottom.update_height(1.05,true);await settle(75)
 check(absf(upper.position.y-bottom.position.y-1.055)<.01,"Crouched base supports the upper player")
 bottom.update_height(1.65)
 check(bottom.collision_height==1.05,"Occupied headroom prevents uncrouching through a player")
 upper.cs16_stamina=0;await physics_frame;upper.simulate(Vector2.ZERO,0,false,DT,true)
 for i in 9:await physics_frame;upper.simulate(Vector2.ZERO,0,false,DT)
 bottom.update_height(1.65);await settle(100)
 check(bottom.collision_height==1.65 and upper.position.y>1.64,"Jumping partner creates room for a crouch-to-stand boost")
 for i in 35:
  await physics_frame;bottom.simulate(Vector2.ZERO,0,false,DT);upper.simulate(Vector2.RIGHT,0,false,DT)
 check(upper.position.x>1 and upper.position.y<1.4,"Walking off a stack resumes falling")
 upper.position=Vector3(0,2,0);upper.velocity=Vector3.ZERO;upper.reset_view();await settle(80)
 bottom.show_alive(false,false);await settle(80)
 check(upper.is_supported() and upper.position.y<.02,"Death immediately removes player support")
 bottom.position=Vector3(8,0,0);bottom.show_alive(true,false);await settle()
 check(upper.position.x<.01,"Respawning base does not carry the former passenger")
 bottom.position=Vector3(0,.02,0);bottom.update_height(1.05,true);bottom.velocity=Vector3.ZERO;bottom.reset_view()
 upper.position=Vector3(-.9,.02,0);upper.velocity=Vector3.ZERO;upper.reset_view();await settle(20)
 for i in 30:
  await physics_frame;bottom.simulate(Vector2.ZERO,0,false,DT);upper.simulate(Vector2.RIGHT,0,false,DT)
 check(upper.position.y<.05 and upper.position.x<-.58,"Walking into a crouched player cannot auto-step onto them")
 upper.position=Vector3(-.9,.02,0);upper.velocity=Vector3.ZERO;upper.reset_view();await settle(20)
 for i in 40:
  await physics_frame;bottom.simulate(Vector2.ZERO,0,false,DT);upper.simulate(Vector2.RIGHT if i<32 else Vector2.ZERO,0,false,DT,i==0)
 await settle(30)
 check(upper.is_supported() and upper.position.y>1.04 and upper.position.y<1.08,"A normal approach and jump builds a stack on a crouched teammate")
 bottom.configure_cs16(false)
 check(bottom.body_shape.shape is CapsuleShape3D,"Other modes retain their capsule collider")
 world.free();print("CS16 STACKING: ",checks," checks, ",failures.size()," failures");quit(1 if failures else 0)
