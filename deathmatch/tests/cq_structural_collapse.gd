extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_collapse_fixture.gd")
class Lights extends RefCounted:
 var fixture_groups:Array=[]
 var metadata:Dictionary={}
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func ray(world,a:Vector3,b:Vector3)->Dictionary:return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func rendered_hit(mesh:Mesh,a:Vector3,b:Vector3)->bool:
 var faces:PackedVector3Array=mesh.get_faces()
 for i in range(0,faces.size(),3):
  if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])!=null:return true
 return false
func run()->void:
 var f:Dictionary=Fixture.make(root);var service=f.service;service.set_process(false)
 var lenses:=MultiMeshInstance3D.new();lenses.position=f.origin;lenses.multimesh=MultiMesh.new();lenses.multimesh.transform_format=MultiMesh.TRANSFORM_3D;lenses.multimesh.mesh=BoxMesh.new();lenses.multimesh.instance_count=2;f.world.add_child(lenses)
 var lights:=Lights.new();lights.fixture_groups=[lenses];lights.metadata={"lamps":[]};f.world.lighting=lights
 for i in 2:
  var local:=Vector3(i*26.,3.1,0);lenses.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,local));var at:Vector3=f.origin+local
  lights.metadata.lamps.append({"kind":0,"position":[at.x,at.y,at.z]})
 check(service.integrity.buildings.size()==2,"Two buildings have independent integrity state")
 var building:Dictionary=service.integrity.buildings[0]
 check(building.stories.size()==3 and building.stories.all(func(columns):return not columns.is_empty()),"Bearing lanes exist on every storey")
 check(service.integrity.status(0,{}).remaining==1.,"Intact supports begin stable")
 await physics_frame;await physics_frame
 var first:Dictionary=building.stories[0][0]
 service.apply_breaks(first.cells,f.origin,true)
 check(service.collapsed.is_empty(),"A local breach retains enough support for a stable building")
 check(service.integrity.status(0,service.broken).remaining>.45,"Surviving bearing area stays above stability threshold")
 service.flush_meshes()
 var upper_a:Vector3=f.origin+Vector3(0,12,0);var upper_b:Vector3=f.origin+Vector3(0,1,0)
 check(not ray(f.world,upper_a,upper_b).is_empty(),"Upper floor collision exists before collapse")
 var actor=preload("res://deathmatch/fighter.gd").new();f.world.add_child(actor);actor.setup(99,"Collapse capsule",Color.WHITE);actor.set_process(false);actor.position=f.origin+Vector3(0,7.31,0);actor.update_height(1.7,true)
 for i in 8:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1./60.)
 check(absf(actor.position.y-(f.origin.y+7.3))<.1,"Player is supported by an upper floor before collapse")
 var failed:=Fixture.support_ids(service,0,1)
 var prepared_nodes:int=service.find_children("*","MeshInstance3D",true,false).size()
 service.apply_breaks(failed,f.origin,true)
 check(service.collapsed.has(0) and not service.collapsed.has(1),"Failed upper-storey supports collapse only their own building")
 check(service.integrity.status(0,service.broken).failed_floor==1,"Failure is detected above a still-supported ground storey")
 check(service.collapse_visuals.size()==1,"Live collapse starts a bounded nonphysical whole-building animation")
 check(service.collapse_visuals[0].node==service.prepared[0] and service.collapse_visuals[0].node.mesh==service.collapse_meshes[0],"Collapse reuses the prepared node and compact mesh")
 check(f.game.collapse_calls.size()==1,"Authority applies occupant damage exactly once")
 check(service.rubble[0].body.collision_layer==1 and service.rubble[1].body.collision_layer==0,"Only the collapsed building activates permanent rubble cover")
 check(service.collapse_effects_played==1 and service.dust_pool[0].node.visible,"Live collapse starts pooled sound and dust")
 check(service.find_children("*","MeshInstance3D",true,false).size()==prepared_nodes,"Impact does not instantiate animation or fragment mesh nodes")
 check(service.collapse_visuals[0].node.find_children("*","RigidBody3D",true,false).is_empty(),"Collapse creates no rigid-body simulation")
 service.flush_meshes();await physics_frame;await physics_frame
 check(ray(f.world,upper_a,upper_b).is_empty(),"Upper floors and roof collision cannot remain floating after collapse")
 check(not ray(f.world,f.origin+Vector3(0,1,0),f.origin+Vector3(0,-.3,0)).is_empty(),"Ground-level foundation remains walkable")
 var cover:Vector3=service.rubble[0].rows[0].center+f.origin
 check(ray(f.world,cover+Vector3(0,0,3),cover-Vector3(0,0,3)).get("collider")==service.rubble[0].body,"Rubble physically blocks low incoming fire")
 cover.y=f.origin.y+1.5
 check(ray(f.world,cover+Vector3(0,0,3),cover-Vector3(0,0,3)).get("collider")==service.rubble[0].body,"Tall broken wall protects a standing player's upper body")
 check(rendered_hit(service.rubble[0].visual.mesh,cover-f.origin+Vector3(0,0,3),cover-f.origin-Vector3(0,0,3)),"Visible broken slab matches the standing-height protection")
 cover.y=f.origin.y+2.
 check(ray(f.world,cover+Vector3(0,0,3),cover-Vector3(0,0,3)).is_empty(),"Rubble remains partial-height rather than recreating the building")
 for i in 35:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1./60.)
 check(actor.position.y<f.origin.y+6.,"Player loses upper-floor support rather than standing on a ghost floor")
 actor.free()
 var fixtures_hidden:bool=service.collapsed_fixtures.size()==1 and service.collapsed_fixtures[0].index==0
 # Dummy rendering does not retain MultiMesh transform buffers.
 if DisplayServer.get_name()!="headless":fixtures_hidden=fixtures_hidden and is_zero_approx(lenses.multimesh.get_instance_transform(0).basis.determinant()) and is_equal_approx(lenses.multimesh.get_instance_transform(1).basis.determinant(),1.)
 check(fixtures_hidden,"Building light lenses disappear without removing neighbour fixtures")
 check(f.ramp.collision_layer==0,"Substituted stair-ramp collision is removed with the building")
 var mesh:Mesh=f.world.structures.meshes[0][0]
 check(not rendered_hit(mesh,Vector3(0,12,0),Vector3(0,1,0)),"Rendered roof and floors disappear with their collision")
 check(not rendered_hit(f.world.structures.meshes[0][2],Vector3(0,12,0),Vector3(0,1,0)),"Distant LOD cannot recreate the collapsed building")
 check(not ray(f.world,upper_a+Vector3(26,0,0),upper_b+Vector3(26,0,0)).is_empty() and rendered_hit(mesh,Vector3(26,12,0),Vector3(26,1,0)),"Neighbouring building retains its floors and roof")
 check(Array(service.candidates(f.origin+Vector3(0,2,8),300,35,false)).all(func(id):return service.integrity.cell_building.get(id,-1)!=0),"Collapsed buildings cannot absorb later breach activations")
 var prior:int=service.collapse_visuals.size();service.collapse_building(0,true)
 check(service.collapse_visuals.size()==prior,"Repeated collapse state cannot replay the animation")
 check(f.game.collapse_calls.size()==1 and service.collapse_effects_played==1,"Duplicate state cannot repeat damage or effects")
 service._process(.7)
 check(service.collapse_visuals[0].node.global_position.y<f.origin.y-2.,"Reactive collapse sinks the remaining structure over time")
 service._process(.8);check(service.collapse_visuals.is_empty() and not service.prepared[0].visible,"Collapse animation returns its prebuilt mesh to hidden state")
 service.clear_state();service.flush_meshes();await physics_frame;await physics_frame
 check(service.collapsed.is_empty() and not ray(f.world,upper_a,upper_b).is_empty() and f.ramp.collision_layer==1,"Round reset restores floors, roof and stair collisions")
 check(service.rubble[0].body.collision_layer==0 and not service.rubble[0].visual.visible and not service.dust_pool[0].node.visible,"Round reset removes rubble cover and transient effects")
 check(service.collapsed_fixtures.is_empty() and is_equal_approx(lenses.multimesh.get_instance_transform(0).basis.determinant(),1.),"Round reset restores collapsed fixture transforms")
 # Two adjacent failed sides trigger instability before the global area threshold.
 var losses:Dictionary={}
 for column in building.stories[0]:
  if column.side in [0,2]:
   for id in column.cells:losses[id]=true
 var adjacent:Dictionary=service.integrity.status(0,losses)
 check(adjacent.failed_floor==0 and adjacent.remaining>=.45,"Two adjacent failed perimeter sides trigger collapse before total support is critical")
 var threshold=preload("res://tools/voxel_battle/structural_integrity.gd").new();var columns:Array=[];var threshold_losses:Dictionary={}
 for i in 100:columns.append({"side":i%4,"weight":1.,"cells":PackedInt32Array([i])})
 threshold.buildings=[{"stories":[columns]}]
 for i in 55:threshold_losses[i]=true
 check(threshold.status(0,threshold_losses).failed_floor<0,"Exactly 45 percent remaining support is still stable")
 threshold_losses[55]=true
 check(threshold.status(0,threshold_losses).failed_floor==0,"Less than 45 percent remaining support triggers collapse")
 print("CQ_STRUCTURAL_COLLAPSE ",JSON.stringify({"checks":checks,"failures":failures,"buildings":service.integrity.buildings.size(),"support_columns":building.stories.map(func(columns):return columns.size())}))
 f.game.queue_free();await process_frame;await process_frame
 # Allow the audio thread to release stopped pooled playbacks before teardown.
 await create_timer(.05).timeout
 quit(0 if failures.is_empty() else 1)
