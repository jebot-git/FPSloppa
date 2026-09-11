extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class Driver extends Node:
 var actor
 func _physics_process(delta:float):actor.simulate(Vector2(0,-1),0,false,delta)
func _initialize():call_deferred("run")
func run():
 Engine.max_fps=144
 var world=Node3D.new();root.add_child(world);Fixture.box(world,Vector3(0,-.5,0),Vector3(8,1,30))
 var actor=preload("res://deathmatch/fighter.gd").new();actor.setup(1,"Motion",Color.WHITE);actor.quake_movement=true;world.add_child(actor);actor.position=Vector3(0,.01,10)
 var driver=Driver.new();driver.actor=actor;world.add_child(driver)
 actor.get_global_transform_interpolated()
 await create_timer(.25).timeout
 var raw_changes:=0;var render_changes:=0;var samples:=0
 var raw:Vector3=actor.position;var visual:Vector3=actor.render_position()
 var until=Time.get_ticks_msec()+650
 while Time.get_ticks_msec()<until:
  await process_frame
  var next_raw:Vector3=actor.position;var next_visual:Vector3=actor.render_position()
  if next_raw.distance_to(raw)>.0001:raw_changes+=1
  if next_visual.distance_to(visual)>.0001:render_changes+=1
  samples+=1;raw=next_raw;visual=next_visual
 var smooth:bool=render_changes>raw_changes*1.4 and samples>60
 print("PASS " if smooth else "FAIL ","Rendered locomotion advances between 60 Hz physics ticks at 144 Hz: ",JSON.stringify({"samples":samples,"physics_changes":raw_changes,"render_changes":render_changes}))
 driver.set_physics_process(false);actor.position+=Vector3(100,0,0);actor.reset_view()
 var reset:bool=actor.render_position().distance_to(actor.global_position)<.001
 print("PASS " if reset else "FAIL ","Teleport resets interpolation without streaking")
 world.free();quit(0 if smooth and reset else 1)
