extends SceneTree
func _initialize():run.call_deferred()
func run():
 var path: String=OS.get_cmdline_user_args()[0]
 var level=preload("res://deathmatch/maps/loader.gd").read(path)
 if not level:quit(1);return
 root.add_child(level)
 var region:=NavigationRegion3D.new();root.add_child(region)
 var mesh:=NavigationMesh.new();mesh.agent_radius=.32;mesh.agent_height=1.7;mesh.agent_max_climb=.45;mesh.cell_size=.2;mesh.cell_height=.1
 var geometry:=NavigationMeshSourceGeometryData3D.new()
 NavigationServer3D.parse_source_geometry_data(mesh,geometry,level)
 NavigationServer3D.bake_from_source_geometry_data(mesh,geometry)
 var nav_map:=NavigationServer3D.map_create();NavigationServer3D.map_set_active(nav_map,true);NavigationServer3D.map_set_cell_size(nav_map,.2);NavigationServer3D.map_set_cell_height(nav_map,.1)
 region.set_navigation_map(nav_map);region.navigation_mesh=mesh
 var deadline:=Time.get_ticks_msec()+15000
 while NavigationServer3D.map_get_iteration_id(nav_map)==0 and Time.get_ticks_msec()<deadline:
  await create_timer(.1).timeout
 assert(NavigationServer3D.map_get_iteration_id(nav_map)>0,"Navigation did not synchronize")
 for i in 8:await physics_frame
 var space=level.get_world_3d().direct_space_state;var points: Array=[];var hills: Array=[];var checks: Array=[]
 for node in level.find_children("*","Node3D",true,false):
  if node.get_script()!=preload("res://deathmatch/maps/entity.gd"):continue
  var kind: String=node.attributes.get("classname","")
  if kind not in ["info_player_deathmatch","info_koth_control"]:continue
  var point: Vector3=node.global_position-Vector3.UP*.7
  var ground=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*4,1))
  var grounded: bool=not ground.is_empty() and ground.normal.y>.65
  var floor_point: Vector3=ground.position if grounded else point
  var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.7
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform.origin=floor_point+Vector3.UP*.9
  var blocked: bool=not space.intersect_shape(query,1).is_empty()
  checks.append({"kind":kind,"position":[point.x,point.y,point.z],"floor":[floor_point.x,floor_point.y,floor_point.z],"grounded":grounded,"blocked":blocked,"floor_delta":floor_point.y-point.y})
  if kind=="info_koth_control":hills.append(floor_point)
  else:points.append(floor_point)
 var nav_distances: Array=[]
 for point in points+hills:nav_distances.append(point.distance_to(NavigationServer3D.map_get_closest_point(region.get_navigation_map(),point)))
 var routes:=0
 for spawn in points:
  for hill in hills:
   var route:=NavigationServer3D.map_get_path(region.get_navigation_map(),spawn,hill,true)
   if not route.is_empty() and route[-1].distance_to(hill)<.8:routes+=1
 var report={"bsp_sha256":FileAccess.get_sha256(path),"checks":checks,"spawn_hill_routes":routes,"route_total":points.size()*hills.size(),"nav_polygons":mesh.get_polygon_count(),"nav_distances":nav_distances,"navigation_iteration":NavigationServer3D.map_get_iteration_id(region.get_navigation_map()),"baked_faces":level.get_meta("baked_light_faces",0),"invalid_light_faces":level.get_meta("baked_light_invalid_faces",0)}
 FileAccess.open(path.get_base_dir()+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("UT_CANDIDATE ",JSON.stringify(report));NavigationServer3D.free_rid(nav_map);quit()
