extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures.append(label)
func run():
 var world:=Node3D.new();root.add_child(world)
 Fixture.box(world,Vector3(0,-.5,0),Vector3(8,1,12))
 for i in range(8): Fixture.box(world,Vector3(0,(i+1)*.125,-1.25-i*.5),Vector3(3,(i+1)*.25,.5))
 var actor=load("res://deathmatch/fighter.gd").new();actor.setup(1,"Steps",Color.WHITE);world.add_child(actor)
 actor.quake_movement=true;actor.position=Vector3(0,.02,.8)
 for i in range(12): await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
 var max_rise:=0.0;var max_view_jump:=0.0;var last_y:float=actor.position.y;var last_view:=last_y
 for i in range(57):
  await physics_frame
  actor.simulate(Vector2(0,-1),0,true,1.0/60)
  actor._process(1.0/60)
  max_rise=maxf(max_rise,actor.position.y-last_y);last_y=actor.position.y
  var view:float=actor.position.y+actor.view_offset
  max_view_jump=maxf(max_view_jump,absf(view-last_view));last_view=view
 check(actor.position.z<-3.4 and actor.position.y>1.2,"Ascending repeated stairs makes steady progress")
 check(max_rise<.3,"Step-up lands on actual tread instead of jumping full step height")
 check(max_view_jump<.2,"Stair camera transitions are smaller than physical risers")
 for i in range(57): await physics_frame;actor.simulate(Vector2(0,1),0,true,1.0/60)
 check(actor.position.z>0 and actor.position.y<.08 and actor.is_on_floor(),"Descending stairs stays grounded and returns to floor")
 for spec in [Vector2(.18,.3),Vector2(.3,.4),Vector2(.4,.5)]:
  var base:=Vector3(30+spec.x*100,0,0)
  Fixture.box(world,base+Vector3(0,-.5,0),Vector3(8,1,12))
  for i in 8:Fixture.box(world,base+Vector3(0,(i+1)*spec.x*.5,-1.0-i*spec.y),Vector3(3,(i+1)*spec.x,spec.y))
  actor.position=base+Vector3(0,.02,.2);actor.velocity=Vector3.ZERO;actor.reset_view()
  for i in 12:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
  for i in 42:await physics_frame;actor.simulate(Vector2(.12,-1),0,true,1.0/60)
  check(actor.position.z<-1.8 and actor.position.y>spec.x*3,"Oblique ascent clears risers %.2f / treads %.2f"%[spec.x,spec.y])
  for i in 60:await physics_frame;actor.simulate(Vector2(-.12,1),0,true,1.0/60)
  check(actor.position.z>0 and actor.position.y<.08,"Descent clears risers %.2f without sticking"%spec.x)
 # A wall above maximum step height cannot be climbed.
 Fixture.box(world,Vector3(2,.8,-1.5),Vector3(1,1.6,1))
 actor.position=Vector3(2,.02,0);actor.velocity=Vector3.ZERO;actor.reset_view()
 for i in range(45):await physics_frame;actor.simulate(Vector2(0,-1),0,true,1.0/60)
 check(actor.position.z>-.8 and actor.position.y<.1,"Tall obstacles cannot be climbed as stairs")
 actor.reset_view();check(actor.view_offset==0,"Teleport/spawn clears stair smoothing")
 world.free()
 print("STAIRS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
