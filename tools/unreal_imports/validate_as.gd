extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
var failures: Array=[]
func check(ok: bool,label: String):
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var path: String=OS.get_cmdline_user_args()[0];var id: String=path.get_file().get_basename()
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.map_catalog=g.map_catalog.filter(func(row):return row.id!=id)
 g.map_catalog.append({"id":id,"title":id,"path":path,"scene":path.get_basename()+".scn","sha256":FileAccess.get_sha256(path),"modes":["as"]})
 g.selected_map=id;g.start_host("UT AS validation",0,100,10,true,"as","quake");g.set_process(false);g.set_physics_process(false)
 check(g.current_map==id and g.active,"AS map starts")
 if not g.active:quit(1);return
 var runtime=g.get_node("Map/MapRuntime");runtime.set_physics_process(false)
 var nav=g.bots.navigation;var deadline:=Time.get_ticks_msec()+30000
 while not nav.ready() and Time.get_ticks_msec()<deadline:await physics_frame
 check(nav.ready(),"Navigation ready");nav.install_links()
 for step in 16384:
  nav.update_jump_links()
  if nav.jump_cursor>=nav.jump_candidates.size()*nav.jump_work_per_candidate() or nav.jump_links>=nav.maximum_jump_links():break
  if step%20==0:await physics_frame
 for frame in 8:await physics_frame
 var rules=g.match_mode.assault;var fortress=g.match_mode.fortress
 var marker_nav: Array=[]
 for point in g.spawn_points+rules.objectives.map(func(o):return o.position):
  var nearest: Vector3=NavigationServer3D.map_get_closest_point(g.bots.region.get_navigation_map(),point)
  marker_nav.append({"position":str(point),"nearest":str(nearest),"distance":point.distance_to(nearest)})
 check(rules.supported(),"Contiguous bounded objective sequence supported")
 var authored: Array=g.map_assault
 g.map_assault=[{"kind":"info_as_objective","step":1},{"kind":"info_as_objective","step":2}]
 check(rules.supported(),"Existing two-objective rules remain supported")
 g.map_assault.append({"kind":"info_as_objective","step":2})
 check(not rules.supported(),"Duplicate objective steps are rejected")
 g.map_assault=Array(range(9)).map(func(i):return {"kind":"info_as_objective","step":i+1})
 check(not rules.supported(),"Excessive objective sequence is rejected")
 g.map_assault=authored
 var points: Array=g.spawn_points.duplicate()
 for objective in rules.objectives:points.append(objective.position)
 var space=g.get_world_3d().direct_space_state;var checks: Array=[]
 for point in points:
  var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7;query.shape=capsule;query.collision_mask=1;query.transform.origin=point+Vector3.UP*.9
  var blocked: bool=not space.intersect_shape(query).is_empty()
  var floor=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point-Vector3.UP*.5,1))
  var safe: bool=not blocked and not floor.is_empty() and floor.normal.y>.65 and not nav.hazardous(point)
  checks.append({"point":[point.x,point.y,point.z],"safe":safe,"blocked":blocked,"floor":not floor.is_empty()})
  check(safe,"Unsafe marker "+str(point))
 var routes:=0;var total:=0;var missing: Array=[]
 for a in g.ctf_spawns[0].size():
  total+=1
  if not nav.path(g.ctf_spawns[0][a],rules.objectives[0].position).is_empty():routes+=1
  else:missing.append(["attacker",a,0])
 for i in range(rules.objectives.size()-1):
  total+=1
  if not nav.path(rules.objectives[i].position,rules.objectives[i+1].position).is_empty():routes+=1
  else:missing.append(["sequence",i,i+1])
 for a in g.ctf_spawns[1].size():
  for i in rules.objectives.size():
   total+=1
   if not nav.path(g.ctf_spawns[1][a],rules.objectives[i].position).is_empty():routes+=1
   else:missing.append(["defender",a,i])
 check(not missing.any(func(r):return r[0]!="defender"),"Missing mandatory attack routes")
 for a in g.ctf_spawns[1].size():
  check(missing.filter(func(r):return r[0]=="defender" and r[1]==a).size()<rules.objectives.size(),"Defender cannot reach any objective")
 for pid in g.players:g.players[pid].spectator=true
 var player: Dictionary=g.players[1];player.spectator=false;player.dead=false;player.team=0;player.vr_device=false;player.invulnerable=0
 var actor=g.fighters[1];var stages: Array=[]
 rules.tick(.01)
 for leg in 2:
  player.team=rules.attacking;player.dead=false;player.spectator=false
  for i in rules.objectives.size():
   var objective: Dictionary=rules.objectives[i];actor.position=objective.position
   player.team=1-rules.attacking
   check(not rules.activate(1),"Defender cannot activate objective")
   if int(objective.get("health",0))>0:
    var hp: int=fortress.buildings[100100+i].hp;fortress.damage_building(100100+i,1,hp)
    check(fortress.buildings.has(100100+i) and fortress.buildings[100100+i].hp==hp,"Defender cannot damage objective")
   player.team=rules.attacking
   if i+1<rules.objectives.size():
    var future: Dictionary=rules.objectives[i+1];actor.position=future.position
    check(not rules.activate(1),"Future switch remains locked")
    if int(future.get("health",0))>0:
     var hp: int=fortress.buildings[100101+i].hp;fortress.damage_building(100101+i,1,hp)
     check(fortress.buildings[100101+i].hp==hp,"Future destructible remains locked")
   actor.position=objective.position
   g.round_left=rules.budget-10.0*(i+1) if leg==0 else rules.budget-5.0*(i+1)
   if int(objective.get("health",0))>0:
    check(not rules.activate(1),"Destructible requires damage")
    fortress.damage_building(100100+i,1,int(objective.health)-1)
    check(rules.stage==i,"Destructible requires complete HP depletion")
    fortress.damage_building(100100+i,1,1)
   else:check(rules.activate(1),"Switch activates")
   check(rules.stage==i+1,"Objective advances exactly once");stages.append([leg,rules.stage])
  if leg==0:
   check(rules.switching and rules.first_finished,"First leg completes")
   rules.next_leg();check(rules.leg==1 and rules.stage==0 and rules.attacking==1,"Return leg resets objectives and swaps roles")
 check(rules.finished and g.match_mode.scores==[0,1],"Faster return attack wins")
 var restored=load("res://deathmatch/modes/assault.gd").new();restored.receive(rules.snapshot())
 check(restored.stage==rules.stage and restored.objectives.size()==rules.objectives.size() and restored.finished,"Multi-objective snapshot restores final state")
 var level=g.get_node("Map").get_child(0)
 var navmesh=g.bots.region.navigation_mesh
 var nav_vertices: Array=[];var nav_polys: Array=[];var nav_links: Array=[]
 for v in navmesh.get_vertices():nav_vertices.append([v.x,v.y,v.z])
 for i in navmesh.get_polygon_count():nav_polys.append(Array(navmesh.get_polygon(i)))
 for link in nav.links:nav_links.append({"start":[link.start.x,link.start.y,link.start.z],"end":[link.end.x,link.end.y,link.end.z],"kind":link.kind})
 FileAccess.open(path.get_base_dir()+"/nav-debug.json",FileAccess.WRITE).store_string(JSON.stringify({"vertices":nav_vertices,"polygons":nav_polys,"links":nav_links,"markers":marker_nav}))
 var report={"marker_nav":marker_nav,"id":id,"bsp_sha256":FileAccess.get_sha256(path),"checks":checks,"spawns":g.spawn_points.size(),"objectives":rules.objectives.size(),"stages":stages,"routes":routes,"total_routes":total,"missing_routes":missing,"links":nav.links.size(),"jumps":nav.jump_links,"baked_faces":level.get_meta("baked_light_faces",0),"invalid_light_faces":level.get_meta("baked_light_invalid_faces",0),"failures":failures}
 ResourceSaver.save(g.bots.region.navigation_mesh,path.get_base_dir()+"/navigation.res",ResourceSaver.FLAG_COMPRESS)
 FileAccess.open(path.get_base_dir()+"/runtime-validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("AS_RUNTIME ",JSON.stringify(report));g.free();await process_frame;quit(0 if failures.is_empty() else 1)
