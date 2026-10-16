extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_collapse_fixture.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var f:=Fixture.make(root);var service=f.service;service.set_process(false)
 var kernel=service.native_destruction
 check(kernel!=null,"native destruction available")
 var rng:=RandomNumberGenerator.new();rng.seed=171018
 for i in 50:
  var at:Vector3=f.origin+Vector3(rng.randf_range(-8,8),rng.randf_range(0,10),rng.randf_range(-9,9))
  var actual:PackedInt32Array=service.candidates(at,100,30,false)
  service.native_destruction=null
  var reference:PackedInt32Array=service.candidates(at,100,30,false)
  service.native_destruction=kernel
  check(actual==reference,"candidate ordering parity "+str(i))
 var ids:=Fixture.support_ids(service,0,1)
 service.apply_breaks(ids,f.origin,false)
 for id in service.integrity.buildings.size():
  check(kernel.status(id,PackedInt32Array(service.broken.keys()))==service.integrity.status(id,service.broken),"support failure parity")
 for lod in 2:
  var source:ArrayMesh=f.world.structures.meshes[0][lod]
  var actual:Array=service.replace_mesh(source,0,lod).surface_get_arrays(0)
  service.native_destruction=null
  var reference:Array=service.replace_mesh(source,0,lod).surface_get_arrays(0)
  service.native_destruction=kernel
  check(actual==reference,"collapsed geometry and all bake channels match "+str(lod))
 service.clear_state()
 # Partial breach exercises rebuilt box vertices and copied vertex attributes.
 service.apply_breaks(PackedInt32Array([service.integrity.buildings[0].cells[0]]),f.origin,false)
 var source:ArrayMesh=f.world.structures.meshes[0][0]
 var actual:Array=service.replace_mesh(source,0).surface_get_arrays(0)
 service.native_destruction=null
 var reference:Array=service.replace_mesh(source,0).surface_get_arrays(0)
 service.native_destruction=kernel
 check(actual==reference,"partial breach geometry and bake channels match")
 service.flush_meshes_async();check(not service.mesh_job.is_empty(),"visual replacement queued off main thread")
 service.clear_state() # Retire a pending result from the old round.
 var deadline:=Time.get_ticks_msec()+5000
 while not service.mesh_job.is_empty() and Time.get_ticks_msec()<deadline:
  await process_frame;service.flush_meshes_async()
 check(service.mesh_job.is_empty() and service.mesh_jobs_discarded==1 and service.broken.is_empty(),"reset discards stale geometry job")
 service.apply_breaks(ids,f.origin,false);service.flush_meshes_async()
 while (not service.mesh_job.is_empty() or not service.dirty.is_empty()) and Time.get_ticks_msec()<deadline:
  await process_frame;service.flush_meshes_async()
 check(service.dirty.is_empty() and service.mesh_job.is_empty(),"fresh geometry commits after reset")
 service.clear_state()
 var all: Array=service.integrity.buildings[0].cells
 service.apply_breaks(PackedInt32Array([all[0]]),f.origin,false);service.flush_meshes_async()
 service.apply_breaks(PackedInt32Array([all[1]]),f.origin,false)
 deadline=Time.get_ticks_msec()+5000
 while (not service.mesh_job.is_empty() or not service.dirty.is_empty()) and Time.get_ticks_msec()<deadline:
  await process_frame;service.flush_meshes_async()
 check(service.mesh_jobs_discarded==2 and service.dirty.is_empty(),"newer damage replaces stale in-flight mesh")
 # The immutable source cache is never overwritten with a previously breached mesh.
 var async_arrays:Array=f.world.structures.meshes[0][0].surface_get_arrays(0)
 var expected_arrays:Array=service.replace_mesh(service.native_mesh_sources[0][0],0).surface_get_arrays(0)
 check(async_arrays==expected_arrays,"asynchronous result contains latest complete breach state")
 print("CQ_NATIVE_DESTRUCTION ",JSON.stringify({"checks":checks,"failures":failures,"submitted":service.mesh_jobs_submitted,"discarded":service.mesh_jobs_discarded,"commit_usec":service.mesh_commit_usec}))
 f.game.free();quit(0 if failures.is_empty() else 1)
