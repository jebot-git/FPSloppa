extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
func _initialize():run.call_deferred()
func v(a):return Vector3(a[0],a[1],a[2])
func run():
 var key: String=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "ctf_t2_broadside"
 var p: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/T2Classic/"+key+"/probes.json"))
 print("BSP_VALIDATION ",Maps.validate("res://maps/"+key+".bsp"))
 var level:=Maps.read("res://maps/"+key+".bsp")
 if not level:quit(1);return
 root.add_child(level);await physics_frame;await physics_frame
 var space: PhysicsDirectSpaceState3D=level.get_world_3d().direct_space_state
 var capsule:=CapsuleShape3D.new();capsule.radius=.30;capsule.height=1.65
 var failures: Array=[];var checks:=0
 for category in ["spawns","flags","stations"]:
  for row in p[category]:
   if category=="stations" and row.kind=="vehicle":continue
   var point: Vector3=v(row.position)
   var q:=PhysicsShapeQueryParameters3D.new();q.shape=capsule;q.collision_mask=1;q.transform.origin=point+Vector3.UP*.85
   checks+=2
   if not space.intersect_shape(q).is_empty():failures.append([category,"blocked",row])
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,point-Vector3.UP*.4,1))
   if hit.is_empty():failures.append([category,"unsupported",row])
 var output:={"id":key,"checks":checks,"failures":failures}
 print("CLASSIC_INSPECT ",JSON.stringify(output))
 FileAccess.open("res://test-results/t2-classic/"+key+"/physics.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
 level.free();quit(0 if failures.is_empty() else 1)
