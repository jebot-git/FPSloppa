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
 # A wall above maximum step height cannot be climbed.
 Fixture.box(world,Vector3(2,.8,-1.5),Vector3(1,1.6,1))
 actor.position=Vector3(2,.02,0);actor.velocity=Vector3.ZERO;actor.reset_view()
 for i in range(45):await physics_frame;actor.simulate(Vector2(0,-1),0,true,1.0/60)
 check(actor.position.z>-.8 and actor.position.y<.1,"Tall obstacles cannot be climbed as stairs")
 actor.reset_view();check(actor.view_offset==0,"Teleport/spawn clears stair smoothing")
 world.free()
 print("STAIRS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
