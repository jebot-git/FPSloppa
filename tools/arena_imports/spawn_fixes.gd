extends SceneTree
func _initialize():run.call_deferred()
func run():
 var id: String=OS.get_cmdline_user_args()[0];var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=id;g.start_host("Spawn correction",0,100,10,true,"dm","quake");g.set_process(false);g.set_physics_process(false)
 for frame in 5:await physics_frame
 var space=g.get_world_3d().direct_space_state;var fixes: Array=[]
 for original in g.spawn_points:
  var found:=false
  for lift in [0.,.125,.25,.375,.5,.75,1.0,1.5,2.0]:
   var p: Vector3=original+Vector3.UP*lift;var q:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.7;q.shape=shape;q.collision_mask=1;q.transform.origin=p+Vector3.UP*.9
   if not space.intersect_shape(q).is_empty():continue
   var ground: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.15,p-Vector3.UP*2,1))
   if ground.is_empty() or ground.normal.y<.65:continue
   var candidate: Vector3=ground.position+Vector3.UP*.06;q.transform.origin=candidate+Vector3.UP*.9
   if not space.intersect_shape(q).is_empty() or g.bots.navigation.hazardous(candidate):continue
   fixes.append({"original":[original.x,original.y,original.z],"corrected":[candidate.x,candidate.y,candidate.z]});found=true;break
  if not found:fixes.append({"original":[original.x,original.y,original.z],"error":"No safe floor within two metres vertically"})
 FileAccess.open("res://test-results/arena-imports/"+id+"-spawn-fixes.json",FileAccess.WRITE).store_string(JSON.stringify(fixes,"  "));print("SPAWN_FIXES ",id," ",JSON.stringify(fixes));g.free();quit()
