extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_collapse_fixture.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 var f:Dictionary=Fixture.make(root,true)
 var camera:=Camera3D.new();f.game.add_child(camera);camera.global_position=f.origin+Vector3(0,2,12);camera.look_at(f.origin+Vector3.UP);camera.make_current()
 var capture:=AudioEffectCapture.new();capture.buffer_length=.5;AudioServer.add_bus_effect(0,capture)
 await physics_frame;await physics_frame;await process_frame
 f.service.apply_breaks(Fixture.support_ids(f.service,0,1),f.origin,true)
 await create_timer(.3).timeout
 var samples:=capture.get_buffer(capture.get_frames_available());var peak:=0.
 for sample in samples:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
 var audible:bool=samples.size()>100 and peak>.001
 var dust:bool=f.service.dust_pool.any(func(effect):return effect.node.visible and effect.age>0. and effect.age<2.4)
 var pooled:bool=f.service.collapse_visuals.size()==1 and f.service.collapse_visuals[0].node==f.service.prepared[0]
 print("CQ_COLLAPSE_EFFECTS ",JSON.stringify({"audible":audible,"peak":peak,"samples":samples.size(),"dust_visible":dust,"prebuilt_mesh":pooled}))
 f.service.clear_state();AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1);f.game.free()
 await process_frame;await process_frame;await process_frame
 quit(0 if audible and dust and pooled else 1)
