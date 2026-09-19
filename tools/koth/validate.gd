extends SceneTree
var failures: Array=[]
var checks: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
 var recipes=JSON.parse_string(FileAccess.get_file_as_string("res://tools/koth/recipes.json"));var report=[]
 check(g.maps_for_mode("koth").size()==4,"Exactly four KOTH maps offered")
 g.votes.allowed_modes=["dm","koth"]
 check(g.votes.match_choices().filter(func(row):return row.mode=="koth").size()==4,"Votes offer all four rebuilt KOTH maps")
 g.mode_maplists["koth"]=["koth_torture","koth_solstice"]
 check(g.maps_for_mode("koth")==["koth_torture","koth_solstice"],"Configured KOTH rotation order is preserved")
 g.mode_maplists.clear()
 for row in recipes:
  if not OS.get_cmdline_user_args().is_empty() and not row.id in OS.get_cmdline_user_args():continue
  g._load_map(row.id);g.match_mode.kind="koth";g.match_mode.reset()
  await physics_frame;await physics_frame
  var mode=g.match_mode;var sites: Array=mode.hills
  check(sites.size()>=3,row.id+" has at least three authored hill positions")
  check(g.map_objectives.get("hill_markers",[]).size()==3,row.id+" BSP supplies three ordered markers")
  var ai=load("res://deathmatch/bots.gd").new();g.add_child(ai);ai.setup(g)
  var deadline:=Time.get_ticks_msec()+30000
  while NavigationServer3D.map_get_closest_point_owner(ai.region.get_navigation_map(),sites[0])!=ai.region.get_rid():
   if Time.get_ticks_msec()>deadline:check(false,row.id+" navigation synchronization timeout");ai.free();g.free();quit(1);return
   await physics_frame
  ai.navigation.install_links()
  for frame in 1600:ai.navigation.update_jump_links();await physics_frame
  var nav: RID=ai.region.get_navigation_map();var space=g.get_world_3d().direct_space_state;var records: Array=[]
  for team in 2:check(mode.spawns(team).size()>=2,row.id+" has multiple team "+str(team)+" spawns")
  for index in sites.size():
   var hill: Vector3=sites[index];var label: String=row.id+" hill "+str(index+1)
   var floor=space.intersect_ray(PhysicsRayQueryParameters3D.create(hill+Vector3.UP*.5,hill-Vector3.UP*2,1))
   check(not floor.is_empty() and floor.normal.y>.9 and abs(floor.position.y-hill.y)<.2,label+" has level floor at marker height")
   var target:=NavigationServer3D.map_get_closest_point(nav,hill)
   check(target.distance_to(hill)<.8,label+" lies on baked navigation")
   var teams: Array=[[],[]]
   for team in 2:
    for spawn in mode.spawns(team):
     var path:=NavigationServer3D.map_get_path(nav,spawn,target,true,3)
     var reached: bool=not path.is_empty() and path[-1].distance_to(target)<.6
     check(reached,label+" reachable from team "+str(team)+" spawn "+str(spawn))
     var length:=0.
     for step in range(1,path.size()):length+=path[step-1].distance_to(path[step])
     teams[team].append(snappedf(length,.1))
   for other in sites:
    if other==hill:continue
    check(hill.distance_to(other)>12,label+" is separated from the other hill")
    var path:=NavigationServer3D.map_get_path(nav,other,target,true,3)
    check(not path.is_empty() and path[-1].distance_to(target)<.6,label+" reachable from previous hill")
   var accessible:=0;var clear:=0
   for sample in 16:
    var point: Vector3=hill+Vector3(2.95,0,0).rotated(Vector3.UP,sample*TAU/16)
    var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP*.5,1))
    if not hit.is_empty() and abs(hit.position.y-hill.y)<.2:accessible+=1
    var shape:=BoxShape3D.new();shape.size=Vector3(.8,1.8,.8)
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis(),point+Vector3.UP*.95)
    if space.intersect_shape(query,1).is_empty():clear+=1
   check(accessible==16,label+" entire scoring circle has level ground")
   check(clear==16,label+" entire scoring circle fits the player hitbox")
   check(not g.pickups.any(func(p):return Vector2(p.position.x-hill.x,p.position.z-hill.z).length()<3 and abs(p.position.y-hill.y)<2),label+" has no pickups inside the scoring circle")
   records.append({"hill":[hill.x,hill.y,hill.z],"team_routes":teams,"floor_samples":accessible,"standing_samples":clear})
  report.append({"map":row.id,"hills":records});ai.free();await physics_frame
 FileAccess.open("res://test-results/koth-rotation/geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":report,"checks":checks,"failures":failures},"  "))
 g.free();print("KOTH_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
