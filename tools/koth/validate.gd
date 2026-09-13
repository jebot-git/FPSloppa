extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
 g.map_catalog=g.map_catalog.filter(func(row):return row.get("distribution","")=="base" and not row.get("custom",false))
 var recipes=JSON.parse_string(FileAccess.get_file_as_string("res://tools/koth/recipes.json"));var report=[]
 check(g.maps_for_mode("koth").size()==4,"Exactly four KOTH maps offered")
 g.votes.allowed_modes=["dm","koth"]
 var votes=g.votes.match_choices().filter(func(r):return r.mode=="koth")
 g.mode_maplists["koth"]=["koth_torture","lqdm1"]
 check(g.maps_for_mode("koth")==["koth_torture","lqdm1"],"Explicit KOTH list permits optional maps")
 g.mode_maplists["koth"]=["koth_torture","koth_solstice"]
 check(g.maps_for_mode("koth")==["koth_torture","koth_solstice"],"Configured KOTH rotation order is preserved")
 g.mode_maplists["koth"]=["lqdm1","lqdm2"]
 check(g.maps_for_mode("koth")==["lqdm1","lqdm2"],"Personal KOTH maplist is preserved")
 g.mode_maplists.clear()
 check(votes.size()==4,"Lobby/mode vote offers only four KOTH maps")
 var ui=load("res://deathmatch/interface.gd").new();g.add_child(ui);ui.setup(g)
 ui.host_mode.choose("koth");ui.refresh_maps()
 check(ui.map_choice.items.size()==4,"Host menu offers only four KOTH maps")
 for row in recipes:
  g._load_map(row.id);g.match_mode.kind="koth";g.match_mode.reset()
  var hill: Vector3=g.match_mode.hill
  # Use the production map configuration, including per-mesh merge metadata.
  var ai=load("res://deathmatch/bots.gd").new();g.add_child(ai);ai.setup(g)
  # Region updates and map query snapshots synchronize on separate worker jobs.
  # A fixed number of accelerated frames can still query the previous map.
  var deadline:=Time.get_ticks_msec()+30000
  while NavigationServer3D.map_get_closest_point_owner(ai.region.get_navigation_map(),hill)!=ai.region.get_rid():
   if Time.get_ticks_msec()>deadline:check(false,row.id+" navigation synchronization timeout");ai.free();g.free();quit(1);return
   OS.delay_msec(1)
   await physics_frame
  check(ai.navigation.ready(),row.id+" navigation is synchronized")
  ai.navigation.install_links()
  for i in 1600:ai.navigation.update_jump_links();await physics_frame
  var region:NavigationRegion3D=ai.region
  var nav: RID=region.get_navigation_map();var space=g.get_world_3d().direct_space_state
  var floor=space.intersect_ray(PhysicsRayQueryParameters3D.create(hill+Vector3.UP*.5,hill-Vector3.UP*2,1))
  check(not floor.is_empty() and floor.normal.y>.9 and abs(floor.position.y-hill.y)<.2,row.id+" hill has level floor at marker height")
  var target:=NavigationServer3D.map_get_closest_point(nav,hill)
  print("NAV_TARGET ",row.id," ",target," hill ",hill)
  check(target.distance_to(hill)<.8,row.id+" hill is on navigation mesh")
  var distances=[];var teams=[[],[]];var accessible=0;var clear=0
  for team in 2:
   check(g.match_mode.spawns(team).size()>=2,row.id+" multiple team "+str(team)+" spawns")
   for spawn in g.match_mode.spawns(team):
    var path:=NavigationServer3D.map_get_path(nav,spawn,target,true,3)
    var reached=not path.is_empty() and path[-1].distance_to(target)<.6
    check(reached,row.id+" spawn "+str(spawn)+" reaches hill")
    var length=0.0
    for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
    teams[team].append(snappedf(length,.1));distances.append(length)
  for i in 8:
   var point=hill+Vector3(2.4,0,0).rotated(Vector3.UP,i*TAU/8)
   var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP*.5,1))
   if not hit.is_empty() and abs(hit.position.y-hill.y)<.2:accessible+=1
   var shape=CapsuleShape3D.new();shape.radius=.4;shape.height=1.8
   var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis(),point+Vector3.UP*.92)
   if space.intersect_shape(query,1).is_empty():clear+=1
  check(clear==8,row.id+" scoring circle has standing capsule clearance")
  check(accessible==8,row.id+" entire scoring circle has level ground")
  report.append({"map":row.id,"hill":str(hill),"team_route_metres":teams,"floor_samples":accessible,"standing_samples":clear})
  ai.free()
  await physics_frame
 FileAccess.open("res://test-results/koth/geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":report,"failures":failures},"  "))
 g.free();print("KOTH_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
