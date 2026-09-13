extends SceneTree
var game
var failures: Array=[]
var report: Dictionary={"checks":[],"routes":[],"previews":[]}
var out: String
func q(x: float,y: float,z: float=0) -> Vector3:return Vector3(-y,z,-x)/32.0
func length_of(route: PackedVector3Array) -> float:
 var total:=0.0
 for i in range(1,route.size()):total+=route[i-1].distance_to(route[i])
 return total
func clear_ray(a: Vector3,b: Vector3) -> bool:
 return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()
func walk_route(nav: RID,side: int,lane: int,extraction: bool=false) -> void:
 var start:=q(side*840,side*lane,8);var goal:=q(side*1776,0,8)
 if extraction:start=q(side*1776,0,8);goal=q(-side*1104,-side*368,8)
 var route:=NavigationServer3D.map_get_path(nav,start,goal,true)
 var actor=preload("res://deathmatch/fighter.gd").new()
 actor.setup(9000,"Route probe",Color.WHITE);actor.collision_mask=1;actor.quake_movement=true;actor.speed_multiplier=.65
 game.add_child(actor);actor.position=start
 var step:=1;var frames:=0;var travelled:=0.0
 for frame in 1800:
  if step>=route.size():break
  await physics_frame
  var toward: Vector3=route[step]-actor.position
  if Vector2(toward.x,toward.z).length()<.35 and absf(toward.y)<.65:step+=1;continue
  var before: Vector3=actor.position
  actor.simulate(Vector2(0,-1),atan2(-toward.x,-toward.z),false,1.0/60,false)
  travelled+=actor.position.distance_to(before);frames+=1
 var ok: bool=actor.position.distance_to(goal)<1.0
 print("WALK_RESULT side=",side," lane=",lane," extraction=",extraction," step=",step,"/",route.size()," end=",actor.position," next=",route[mini(step,route.size()-1)] if not route.is_empty() else Vector3.ZERO)
 report.walks.append({"side":side,"lane":lane,"extraction":extraction,"pass":ok,"seconds":frames/60.0,"metres":travelled,"end":str(actor.position),"goal":str(goal)})
 check(ok,"Heavy walks %s on side %d without jumping"%["flag extraction" if extraction else "lane "+str(lane),side])
 actor.free()
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 report.checks.append({"check":label,"pass":ok})
 if not ok:failures.append(label)
 print("PASS " if ok else "FAIL ",label)
func shot(camera: Camera3D,p: Vector3,yaw: float,label: String) -> void:
 camera.position=p+Vector3.UP*1.48;camera.rotation=Vector3(0,yaw,0);camera.make_current()
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var path:=out+"-"+label+".png";root.get_texture().get_image().save_png(path);report.previews.append(path)
func run() -> void:
 var args:=OS.get_cmdline_user_args();var path: String=args[0];out=args[1]
 root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
 var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
 report.map=key;report.sha256=hash
 game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-fo.scn","sha256":hash}];game.selected_map=key
 game.start_host("Playtest",0,100,10,true,"tf")
 check(game.active,"Offline TF match starts")
 if not game.active:finish();return
 if game.hud:game.hud.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 check(game.ctf_spawns[0].size()>0 and game.ctf_spawns[1].size()>0,"Both teams have native spawns")
 check(game.map_objectives.size()==2 and game.tf_capture.size()==2,"Native flags and capture zones for both teams")
 check(game.tf_resupply[0].size()>0 and game.tf_resupply[1].size()>0,"Both teams have resupply")
 for attempt in 1200:
  if game.bots.ready_to_walk:break
  await create_timer(.05).timeout
 check(game.bots.ready_to_walk,"Bot navigation bake completes")
 await physics_frame;await physics_frame
 var nav: RID=game.bots.region.get_navigation_map();NavigationServer3D.map_force_update(nav)
 await create_timer(.3).timeout
 NavigationServer3D.map_force_update(nav)
 print("NAV_POLYGONS ",game.bots.region.navigation_mesh.get_polygon_count()," iteration ",NavigationServer3D.map_get_iteration_id(nav))
 for team in [0,1]:
  for p in game.ctf_spawns[team]:
   for goal in game.match_mode.bases+game.match_mode.captures:
    var route:=NavigationServer3D.map_get_path(nav,p,goal,true)
    var ok: bool=route.size()>1 and route[-1].distance_to(goal)<1.5 and route[0].distance_to(p)<1.5
    report.routes.append({"team":team,"start":str(p),"goal":str(goal),"points":route.size(),"metres":length_of(route),"pass":ok})
 check(report.routes.all(func(r):return r.pass),"Bot walking routes connect every spawn to both flags and captures")
 var camera: Camera3D=game.get_node("Overview")
 report.flag_routes=[]
 for side in [-1,1]:
  var path_route:=NavigationServer3D.map_get_path(nav,q(1776*side,0,.1),q(-1104*side,-368*side,.1),true)
  report.flag_routes.append({"side":side,"metres":length_of(path_route),"heavy_seconds_without_combat":length_of(path_route)/6.11,"scout_seconds_without_combat":length_of(path_route)/11.75})
 print("FLAG_ROUTES ",JSON.stringify(report.flag_routes))
 check(absf(report.flag_routes[0].metres-report.flag_routes[1].metres)<1.0,"Mirrored flag extraction paths differ by less than one metre")
 # At the rear defensive socket, both doors are within current sentry range.
 # Check LOS independently: range cannot make it shoot through partitions.
 report.sentry=[]
 for side in [-1,1]:
  var socket:=q(1840*side,160*side,0)+Vector3.UP*1.1
  for door in [q(1568*side,320*side,0),q(1568*side,-320*side,128),q(1456*side,0,0)]:
   var target: Vector3=door+Vector3.UP*.825
   report.sentry.append({"side":side,"target":str(door),"metres":socket.distance_to(target),"visible":clear_ray(socket,target),"in_range":socket.distance_to(target)<18.0})
 check(report.sentry[0].in_range and report.sentry[1].in_range and report.sentry[3].in_range and report.sentry[4].in_range,"Existing 18 m sentry range reaches both vault approaches")
 check(not report.sentry[2].visible and not report.sentry[5].visible,"Vault partition blocks sentry fire into pump hall")
 check(not clear_ray(q(-840,0,48),q(840,0,48)),"Turbine breaks the direct base-to-base sniper sightline")
 # Full capsule clearance at all native spawns.
 var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.65
 for team in [0,1]:
  for point in game.ctf_spawns[team]:
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=point+Vector3.UP*.83;query.collision_mask=1
   check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Spawn capsule clear "+str(point))
 if DisplayServer.get_name()!="headless":
  for item in [[q(-760,-520,70),q(300,0,180),"turbine"],[q(1016,480,60),q(1792,0,80),"pump-hall"],[q(1640,240,54),q(1776,0,40),"flag-vault"],[q(-1500,-900,560),q(0,0,0),"overview"]]:
   camera.position=item[0];camera.look_at(item[1]);camera.make_current()
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"-"+item[2]+".png")
 game.match_mode.draw_objectives()
 for team in [0,1]:
  var p: Vector3=game.ctf_spawns[team][0]
  var toward: Vector3=game.match_mode.bases[1-team]-p
  if DisplayServer.get_name()!="headless":await shot(camera,p,atan2(-toward.x,-toward.z),"team"+str(team)+"-spawn")
  if DisplayServer.get_name()!="headless":await shot(camera,game.match_mode.bases[team],atan2(-toward.x,-toward.z),"team"+str(team)+"-flag")
 # Authoritative pickup, drop, capture and class resupply at actual map positions.
 for id in game.players:game.players[id].spectator=true
 game.players[1].spectator=false
 for team in [0,1]:
  game.players[1].team=team;game.players[1].dead=false
  game.fighters[1].position=game.match_mode.bases[1-team]
  game.match_mode.tick(.02)
  check(game.match_mode.flags[1-team].carrier==1,"Team %d can pick up enemy flag"%team)
  game.match_mode.drop(1)
  check(game.match_mode.flags[1-team].carrier==0,"Team %d drops flag"%team)
  game.match_mode.return_flag(1-team);game.match_mode.tick(.02)
  game.fighters[1].position=game.match_mode.captures[team];var before: int=game.match_mode.scores[team]
  game.match_mode.tick(.02)
  check(game.match_mode.scores[team]==before+1,"Team %d can score at native capture"%team)
  game.players[1].hp=10;game.fighters[1].position=game.tf_resupply[team][0]
  for n in 20:game.clock+=.1;game.match_mode.tick(.1)
  check(game.players[1].hp>10,"Team %d resupply heals"%team)
 # Exercise production sentry targeting at a real maintenance-lane emplacement.
 game.players[-1].team=0;game.players[1].team=1;game.players[1].armor=0;game.players[1].invulnerable=0
 game.players[1].tf_disguise={};game.players[1].dead=false
 var fortress=game.match_mode.fortress
 fortress.buildings[-9000]={"owner":-1,"team":0,"kind":"sentry","position":q(1400,700),"ready":0.0,"next":0.0,"expires":game.clock+30,"hp":150,"map_owned":true}
 for item in [[q(900,700),true,"Sentry fires at the maintenance entrance inside 18 m"],[q(760,700),false,"Sentry leaves the exposed yard outside 18 m to player defenders"],[q(1600,800),false,"Sentry cannot fire through the spawn screen"]]:
  game.clock+=1;game.players[1].hp=100;game.players[1].armor=0;game.fighters[1].position=item[0]
  fortress.tick_sentries()
  check((game.players[1].hp<100)==item[1],item[2])
 fortress.buildings.erase(-9000)
 # Production bot matches at all requested sizes. Reset equal class rosters.
 report.matches=[]
 # CharacterBody3D.move_and_slide uses the engine physics delta internally.
 # Keep it identical to the delta supplied to production movement/match code.
 Engine.physics_ticks_per_second=60
 report.walks=[]
 for side in ([] if args.has("--no-walks") else [-1,1]):
  for lane in ([] if args.has("--extraction") else [-720,0,720]):await walk_route(nav,side,lane)
  await walk_route(nav,side,0,true)
 var half:=0
 var counts: Array=[] if args.has("--static") else [8,12,12,16]
 if args.has("--players"):counts=[int(args[args.find("--players")+1])]
 for count in counts:
  var swapped: bool=args.has("--swapped") or count==12 and half==2
  half+=1
  game.match_mode.fortress.buildings.clear();game.bots.brains.clear()
  for id in range(-4,-count-1,-1):
   if not game.players.has(id):game._add_player(id,"Audit Bot "+str(-id))
  game.players[1].spectator=true
  var roster: Array=["scout","soldier","medic","engineer","heavy","demoman","pyro","sniper"]
  var starts: Dictionary={};var moved: Dictionary={}
  for id in game.players:
   if id>0:continue
   game.players[id].spectator=(-id>count)
   if game.players[id].spectator:continue
   game.players[id].team=((-id-1)%2+int(swapped))%2;game.players[id].tf_next=roster[((-id-1)/2) as int]
   game._spawn(id);starts[id]=game.fighters[id].position;moved[id]=0.0
  game.match_mode.scores=[0,0]
  for team in [0,1]:game.match_mode.return_flag(team)
  var kills_before:=0
  for id in starts:kills_before+=game.players[id].kills
  var seconds:=90 if count==12 else 30
  var pickups: Array=[0,0];var previous: Array=[0,0]
  for frame in seconds*60:
   await physics_frame;game._physics_process(1.0/60)
   for id in starts:moved[id]=maxf(moved[id],game.fighters[id].position.distance_to(starts[id]))
   for team in [0,1]:
    var carrier: int=game.match_mode.flags[team].carrier
    if carrier!=0 and carrier!=previous[team]:pickups[team]+=1
    previous[team]=carrier
  var kills_after:=0
  for id in starts:kills_after+=game.players[id].kills
  var row: Dictionary={"players":count,"teams_swapped":swapped,"simulated_seconds":seconds,"scores":game.match_mode.scores.duplicate(),"flag_pickups":pickups,"frags":kills_after-kills_before,"max_displacement":moved}
  report.matches.append(row)
  check(moved.values().all(func(d):return d>2.0),"All %d bots leave spawn"%count)
  check(game.fighters.values().all(func(actor):return actor.position.is_finite()),"%d-player simulation remains finite"%count)
  print("PRESSUREWORKS_MATCH ",JSON.stringify(row))

 finish()
func finish():
 report.failures=failures;FileAccess.open(out+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.free();quit(0 if failures.is_empty() else 1)
