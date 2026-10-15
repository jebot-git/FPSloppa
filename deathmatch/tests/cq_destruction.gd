extends SceneTree
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
const Structures=preload("res://tools/streamed_heightfield/structures.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
class Game extends Node3D:
 var active:=true
 var map_epoch:=1
 var resident=null
class World extends Node3D:
 var layout:Dictionary={"boxes":[]}
 var wall_bodies:Dictionary={}
 var structures
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func ray(world:Node3D,a:Vector3,b:Vector3)->Dictionary:return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func box(world:Node3D,at:Vector3,size:Vector3)->StaticBody3D:
 var body:=StaticBody3D.new();body.position=at;var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider);world.add_child(body);return body
func run()->void:
 var game:=Game.new();root.add_child(game);var world:=World.new();game.add_child(world)
 var origin:Vector3=Landscape.CENTERS[0]
 world.layout.boxes=[{"kind":0,"center":Vector3(0,1.85,0),"size":Vector3(8.4,3.5,.24)}]
 world.wall_bodies[0]=box(world,origin+Vector3(0,1.85,0),Vector3(8.4,3.5,.24))
 box(world,origin+Vector3(0,-.4,0),Vector3(20,1,20))
 var builder=Structures.Builder.new();builder.box(Vector3(0,1.85,0),Vector3(8.4,3.5,.24),Color(.5,.55,.4))
 builder.box(Vector3(0,-.4,0),Vector3(20,1,20),Color(.3,.4,.3))
 var base:ArrayMesh=builder.finish()
 # The production bake carries custom channels. They must survive mesh surgery.
 var arrays:Array=base.surface_get_arrays(0);var custom:=PackedFloat32Array();custom.resize(arrays[Mesh.ARRAY_VERTEX].size()*4);custom.fill(.6)
 arrays[Mesh.ARRAY_CUSTOM0]=custom
 base=ArrayMesh.new();base.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
 world.structures=Structures.new();world.structures.meshes=[[base,base,base]];world.structures.placements=[{"kind":0,"position":origin}];world.add_child(world.structures);world.structures.setup()
 var service:=Destruction.new();game.add_child(service);service.setup(game,world,true,true);service.set_process(false)
 check(service.cells.size()==3,"Wall splits into three human-width deterministic sections")
 await physics_frame;await physics_frame
 var a:Vector3=origin+Vector3(0,1,2);var b:Vector3=origin+Vector3(0,1,-2)
 check(not ray(world,a,b).is_empty(),"Intact wall blocks entry and line of sight")
 service.enabled=false;service.impact(origin+Vector3(0,1,.13),120,5)
 check(service.broken.is_empty(),"Experiment is inert when disabled")
 service.enabled=true
 service.impact(origin+Vector3(0,1,.13),120,5)
 check(service.broken.size()==1,"Infantry ordnance opens a bounded section rather than whole building")
 service.flush_meshes();await physics_frame;await physics_frame
 check(ray(world,a,b).is_empty(),"Destroyed wall collision permits passage and line of sight")
 check(not ray(world,a+Vector3(3,0,0),b+Vector3(3,0,0)).is_empty(),"Adjacent wall sections retain collision")
 var mesh:ArrayMesh=world.structures.meshes[0][0];var render_arrays:Array=mesh.surface_get_arrays(0)
 check(render_arrays[Mesh.ARRAY_CUSTOM0].size()==render_arrays[Mesh.ARRAY_VERTEX].size()*4,"Baked float lighting channels remain aligned")
 check(world.structures.meshes[0][2]==world.structures.meshes[0][1],"Far LOD cannot refill the destroyed hole with a solid proxy")
 var faces:PackedVector3Array=mesh.get_faces();var blocked:=false
 for i in range(0,faces.size(),3):
  if Geometry3D.segment_intersects_triangle(a-origin,b-origin,faces[i],faces[i+1],faces[i+2])!=null:blocked=true
 check(not blocked,"Rendered near mesh and collision expose the same opening")
 check(service.debris.size()==8 and service.find_children("*","RigidBody3D",true,false).is_empty(),"Baked breakup uses eight animated meshes and no rigid bodies")
 service.apply_breaks(PackedInt32Array([1]),origin,false)
 check(service.broken.size()==1,"Duplicate network state does not reapply damage")
 check(service.candidates(origin,10,30,false).is_empty(),"Sub-threshold impacts cannot destroy walls")
 # A real player capsule can walk through the breach, not merely a ray.
 var actor=preload("res://deathmatch/fighter.gd").new();world.add_child(actor);actor.setup(99,"Breach capsule",Color.WHITE);actor.set_process(false);actor.position=origin+Vector3(0,.11,2);actor.update_height(1.7,true)
 for i in 65:await physics_frame;actor.simulate(Vector2(0,-1),0,false,1./60.)
 check(actor.position.z<origin.z-.5,"Standing player capsule traverses the created entry")
 actor.free()
 service.clear_state();await physics_frame;await physics_frame
 check(not ray(world,a,b).is_empty() and service.broken.is_empty(),"Round reset restores original mesh and collision")
 service.apply_breaks(PackedInt32Array([0]),origin,false)
 var reused:StaticBody3D=service.colliders[0]
 service.apply_breaks(PackedInt32Array([1]),origin,false)
 check(service.colliders[0]==reused,"Repeated wall impacts reuse replacement collision body")
 await physics_frame;await physics_frame
 check(ray(world,a,b).is_empty(),"Further hits disable remaining section collision")
 game.map_epoch+=1;service.sync_epoch();await physics_frame;await physics_frame
 check(service.broken.is_empty() and service.epoch==game.map_epoch and not ray(world,a,b).is_empty(),"Map epoch transition restores collision and clears old revisions")
 # All cells gone still has a valid floor mesh and collision parent.
 service.apply_breaks(PackedInt32Array([0,1,2]),origin,false);service.flush_meshes()
 check(service.broken.size()==3 and world.structures.meshes[0][0]!=base,"Multiple breaches accumulate without losing intact floors")
 print("CQ_DESTRUCTION ",JSON.stringify({"checks":checks,"failures":failures,"last_rebuild_us":service.rebuild_usec,"cells":service.cells.size(),"shard_cap":service.MAX_SHARDS}))
 game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
