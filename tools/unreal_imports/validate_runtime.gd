extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
func _initialize():run.call_deferred()
func run():
 var path: String=OS.get_cmdline_user_args()[0];var id: String=path.get_file().get_basename()
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.map_catalog.append({"id":id,"title":id,"path":path,"scene":path.get_basename()+".scn","sha256":FileAccess.get_sha256(path),"modes":["koth"]})
 g.selected_map=id;g.start_host("UT KOTH validation",0,100,10,true,"koth","quake");g.set_process(false);g.set_physics_process(false)
 if g.current_map!=id:push_error("Map load failed: "+id);quit(1);return
 var runtime=g.get_node("Map/MapRuntime");runtime.set_physics_process(false)
 var nav=g.bots.navigation;var deadline:=Time.get_ticks_msec()+20000
 while not nav.ready() and Time.get_ticks_msec()<deadline:await physics_frame
 assert(nav.ready());nav.install_links()
 for step in 4096:
  nav.update_jump_links()
  if nav.jump_cursor>=nav.jump_candidates.size()*8 or nav.jump_links>=nav.maximum_jump_links():break
  if step%20==0:await physics_frame
 for frame in 8:await physics_frame
 var space=g.get_world_3d().direct_space_state;var checks: Array=[];var failures: Array=[]
 for point in g.spawn_points+g.match_mode.hills:
  var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7;query.shape=capsule;query.collision_mask=1;query.transform.origin=point+Vector3.UP*.9
  var blocked: bool=not space.intersect_shape(query).is_empty()
  var floor=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point-Vector3.UP*.5,1))
  var safe: bool=not blocked and not floor.is_empty() and floor.normal.y>.65 and not nav.hazardous(point)
  checks.append({"point":[point.x,point.y,point.z],"safe":safe,"blocked":blocked,"floor":not floor.is_empty()})
  if not safe:failures.append("Unsafe marker "+str(point))
 var routes:=0;var missing: Array=[]
 for a in g.spawn_points.size():
  for b in g.match_mode.hills.size():
   var route: PackedVector3Array=nav.path(g.spawn_points[a],g.match_mode.hills[b])
   if not route.is_empty():routes+=1
   else:missing.append([a,b])
 var unresolved: Array=[]
 for volume in runtime.regions:
  if volume.kind=="trigger_teleport" and not runtime.destinations.has(volume.data.get("target","")):unresolved.append(volume.data.get("target",""))
 if not unresolved.is_empty():failures.append("Unresolved teleports")
 if routes!=g.spawn_points.size()*g.match_mode.hills.size():failures.append("Missing spawn-to-hill routes")
 var level=g.get_node("Map").get_child(0)
 var link_kinds: Dictionary={}
 for link in nav.links:link_kinds[link.kind]=int(link_kinds.get(link.kind,0))+1
 var hill_nav: Array=[]
 for h in g.match_mode.hills:hill_nav.append(h.distance_to(NavigationServer3D.map_get_closest_point(g.bots.region.get_navigation_map(),h)))
 var lift_info: Array=[]
 for lift in g.lifts:
  var b: AABB=runtime.node_bounds(lift.node);lift_info.append({"base":lift.base,"travel":lift.travel,"bounds":str(b)})
 var report={"lifts":lift_info,"link_kinds":link_kinds,"hill_nav_distance":hill_nav,"id":id,"bsp_sha256":FileAccess.get_sha256(path),"checks":checks,"spawns":g.spawn_points.size(),"hills":g.match_mode.hills.size(),"fixed":g.match_mode.hill_fixed,"routes":routes,"total_routes":g.spawn_points.size()*g.match_mode.hills.size(),"missing_routes":missing,"unresolved_teleports":unresolved,"links":nav.links.size(),"jumps":nav.jump_links,"baked_faces":level.get_meta("baked_light_faces",0),"invalid_light_faces":level.get_meta("baked_light_invalid_faces",0),"failures":failures}
 ResourceSaver.save(g.bots.region.navigation_mesh,path.get_base_dir()+"/navigation.res",ResourceSaver.FLAG_COMPRESS)
 FileAccess.open(path.get_base_dir()+"/runtime-validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("KOTH_RUNTIME ",JSON.stringify(report));g.free();await process_frame;quit(0 if failures.is_empty() else 1)
