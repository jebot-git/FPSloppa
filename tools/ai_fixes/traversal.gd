extends SceneTree
var game
var report:Dictionary={"probes":[],"trials":[]}
func _initialize():run.call_deferred()
func run():
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map="qsrc_dm3";game.start_host("Traversal observer",0,100000,60,true,"dm","quake")
 game.set_process(false);game.set_physics_process(false);game.dedicated=true
 for id in game.players:
  game.players[id].spectator=id!=-1;game._spawn(id)
 game.bots.free();game.bots=load("res://tools/ai_fixes/guided_ai.gd").new();game.add_child(game.bots);game.bots.setup(game)
 var deadline:=Time.get_ticks_msec()+30000
 while not game.bots.navigation.ready():
  if Time.get_ticks_msec()>deadline:push_error("Navigation timeout");quit(1);return
  await physics_frame
 game.bots.navigation.install_links()
 for i in 1600:game.bots.navigation.update_jump_links();await physics_frame
 var spots:Dictionary={"raised_spawn":Vector3(-24,6,-16),"water_exit":Vector3(2.5,-7.16,-42.24)}
 var targets:Array=[]
 for p in game.spawn_points:targets.append(p)
 for p in game.pickups:targets.append(p.position)
 for name_here in spots:
  var origin:Vector3=spots[name_here];var reachable:Array=[];var nearby:Array=[]
  for target:Vector3 in targets:
   if target.distance_to(origin)<3:continue
   var path:PackedVector3Array=game.bots.navigation.path(origin,target)
   if path.size()>1:reachable.append({"target":target,"distance":origin.distance_to(target),"points":path.size()})
  for radius in [1.0,2.0,4.0,6.0]:
   for i in 16:
    var probe:Vector3=origin+Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*radius
    var hit:Dictionary=game.bots.navigation.ray(probe+Vector3.UP*2,probe-Vector3.UP*12)
    if hit.is_empty():continue
    var point:Vector3=hit.position;var route:PackedVector3Array=game.bots.navigation.path(origin,point)
    nearby.append({"radius":radius,"floor":point,"capsule_clear":game.bots.navigation.landing_clear(point),"path_points":route.size(),"eye_line_clear":game.bots.navigation.ray(origin+Vector3.UP*.8,point+Vector3.UP*.8).is_empty()})
  reachable.sort_custom(func(a,b):return a.distance<b.distance)
  report.probes.append({"name":name_here,"origin":origin,"nav_projection":NavigationServer3D.map_get_closest_point(game.bots.region.get_navigation_map(),origin),"destinations_tested":targets.size(),"reachable_destinations":reachable,"nearby_floor":nearby})
  var goal:Vector3=reachable[0].target if not reachable.is_empty() else origin
  for random_seed in [7129,9137,12011]:
   for forced in [false,true]:
    seed(random_seed);game._spawn(-1)
    var actor=game.fighters[-1];var state:Dictionary=game.players[-1]
    actor.position=origin;actor.velocity=Vector3.ZERO;actor.reset_view();game.bots.brains[-1]=game.bots.new_brain(-1)
    var brain:Dictionary=game.bots.brains[-1]
    if forced:
     if reachable.is_empty():
      report.trials.append({"spot":name_here,"seed":random_seed,"forced_route":true,"skipped":"No strategic navigation path from start"});continue
     game.bots.diagnostic_goal=goal
    game.bots.diagnostic_enabled=forced
    var arrived:=-1.0
    var start:float=game.clock;var max_distance:=0.0;var trace:Array=[];var dry_seconds:=0.0
    while game.clock-start<(60 if forced else 30):
     await physics_frame;game._physics_process(1.0/60)
     if forced and arrived<0 and actor.position.distance_to(goal)<.65:arrived=game.clock-start
     max_distance=maxf(max_distance,actor.position.distance_to(origin))
     if not actor.in_water and not actor.underwater:dry_seconds+=1.0/60
     if int((game.clock-start)*60)%60==0:trace.append({"time":game.clock-start,"position":actor.position,"goal":brain.goal_key,"in_water":actor.in_water,"underwater":actor.underwater,"path_points":brain.path.size(),"move":state.move,"swim":state.swim})
     if state.dead:break
    var result:Dictionary={"arrival_seconds":arrived,"spot":name_here,"seed":random_seed,"forced_route":forced,"goal":goal,"seconds":game.clock-start,"final":actor.position,"max_displacement":max_distance,"dry_seconds":dry_seconds,"died":state.dead,"trace":trace}
    report.trials.append(result);print("NAV_TRIAL ",JSON.stringify(result))
 report.map_sha256=FileAccess.get_sha256("res://maps/qsrc_dm3.bsp")
 report.navigation_sha256=FileAccess.get_sha256("res://maps/navigation/qsrc_dm3.res")
 report.agent={"radius":game.bots.region.navigation_mesh.agent_radius,"height":game.bots.region.navigation_mesh.agent_height,"max_climb":game.bots.region.navigation_mesh.agent_max_climb}
 report.links=game.bots.navigation.links.size();report.jump_links=game.bots.navigation.jump_links
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
