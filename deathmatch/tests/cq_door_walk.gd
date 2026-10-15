extends SceneTree
const Map=preload("res://tools/voxel_battle/map.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
var failures:Array=[]
var checks:=0
func _initialize():run.call_deferred()
func run():
 Engine.physics_ticks_per_second=600;Engine.time_scale=10
 var map:=Map.new();root.add_child(map);map.build(false,true)
 var actor:=Fighter.new();actor.setup(999,"Standing entry probe",Color.WHITE);root.add_child(actor);actor.quake_movement=true;actor.update_height(2.0,true)
 await physics_frame;await physics_frame
 for building in map.layout.buildings:
  for side in [-1.,1.]:
   var base:Vector3=Map.Landscape.CENTERS[building.kind]+building.center
   var at:Vector3=base+Vector3(0,.13,side*(building.size.y*.5+1.3))
   var floor:Dictionary=map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*3,1))
   if not floor.is_empty():at.y=floor.position.y+.015
   actor.position=at;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view()
   for frame in 65:
    await physics_frame;actor.simulate(Vector2(0,-side),0,true,1.0/60,false)
   checks+=1
   if absf(actor.position.z-base.z)>building.size.y*.5-.6:
    failures.append({"kind":building.kind,"role":building.role,"side":side,"start":str(at-base),"end":str(actor.position-base)})
 print("CQ_DOOR_WALK ",JSON.stringify({"checks":checks,"failures":failures}));map.queue_free();actor.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
