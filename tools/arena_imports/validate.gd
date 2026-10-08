extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 if not ok:failures.append(label);print("FAIL ",label)
func run():
 var id: String=OS.get_cmdline_user_args()[0]
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.selected_map=id;g.start_host("Arena validation",0,100,10,true,"dm","quake");g.set_process(false);g.set_physics_process(false)
 check(g.current_map==id,"Map selected");check(g.spawn_points.size()>=2,"At least two DM starts")
 var runtime=g.get_node("Map/MapRuntime");runtime.set_physics_process(false)
 for frame in 8:await physics_frame
 var nav=g.bots.navigation
 var deadline:=Time.get_ticks_msec()+8000
 while not nav.ready() and Time.get_ticks_msec()<deadline:await physics_frame
 check(nav.ready(),"Navigation synchronized")
 nav.install_links()
 # Exercise the actual planner's bounded jump-link discovery, then synchronize.
 for step in 2048:
  nav.update_jump_links()
  if nav.jump_cursor>=nav.jump_candidates.size()*8 or nav.jump_links>=96:break
  if step%20==0:await physics_frame
 for frame in 4:await physics_frame
 var space=g.get_world_3d().direct_space_state;var spawn_checks: Array=[];var safe: Array=[]
 for point in g.spawn_points:
  var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7;query.shape=capsule;query.collision_mask=1;query.transform.origin=point+Vector3.UP*.9
  var blocked: bool=not space.intersect_shape(query).is_empty()
  var ground: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point-Vector3.UP*2,1))
  var hazardous: bool=nav.hazardous(point)
  var valid: bool=not blocked and not ground.is_empty() and ground.normal.y>.65 and not hazardous
  spawn_checks.append({"position":[point.x,point.y,point.z],"blocked":blocked,"floor":not ground.is_empty(),"hazard":hazardous,"safe":valid})
  if valid:safe.append(point)
 check(safe.size()==g.spawn_points.size(),"All spawn capsules clear, grounded and outside hazards")
 var total:=0;var reachable:=0;var missing: Array=[]
 for a in range(safe.size()):
  for b in range(safe.size()):
   if a==b:continue
   total+=1;var path: PackedVector3Array=nav.path(safe[a],safe[b])
   if not path.is_empty():reachable+=1
   elif missing.size()<40:missing.append([a,b])
 var pickup_routes:=0;var pickup_total:=0
 for pickup in g.pickups:
  var position: Vector3=pickup.position
  if nav.hazardous(position):continue
  pickup_total+=1
  for start in safe:
   if not nav.path(start,position).is_empty():pickup_routes+=1;break
 var unresolved:=0
 for volume in runtime.regions:
  if volume.kind=="trigger_teleport" and not runtime.destinations.has(volume.data.get("target","")):unresolved+=1
 check(unresolved==0,"Teleport destinations resolve")
 check(reachable>0,"Bots have routes between spawn areas")
 var report={"id":id,"bsp_sha256":g.map_sha,"spawns":spawn_checks,"pickups":g.pickups.size(),"spawn_route_pairs":total,"reachable_spawn_pairs":reachable,"unreachable_spawn_pairs_sample":missing,"reachable_pickups":pickup_routes,"tested_pickups":pickup_total,"nav_polygons":g.bots.region.navigation_mesh.get_polygon_count(),"traversal_links":nav.links.size(),"jump_links":nav.jump_links,"unresolved_teleports":unresolved,"failures":failures,"fully_connected":total>0 and reachable==total}
 FileAccess.open("res://test-results/arena-imports/"+id+"-gameplay.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("ARENA_GAMEPLAY_RESULT ",JSON.stringify(report));g.free();await process_frame;quit(0 if failures.is_empty() else 1)
