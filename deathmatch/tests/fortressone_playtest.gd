extends SceneTree
var game
var failures: Array=[]
var report: Dictionary={"checks":[],"routes":[],"previews":[]}
var out: String
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
 game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 check(game.ctf_spawns[0].size()>0 and game.ctf_spawns[1].size()>0,"Both teams have native spawns")
 check(game.map_objectives.size()==2 and game.tf_capture.size()==2,"Native flags and capture zones for both teams")
 check(game.tf_resupply[0].size()>0 and game.tf_resupply[1].size()>0,"Both teams have resupply")
 for attempt in 1200:
  if game.bots.ready_to_walk:break
  await create_timer(.05).timeout
 check(game.bots.ready_to_walk,"Bot navigation bake completes")
 await physics_frame;await physics_frame
 var nav: RID=game.bots.region.get_navigation_map();NavigationServer3D.map_force_update(nav)
 for team in [0,1]:
  for p in game.ctf_spawns[team]:
   for goal in game.match_mode.bases+game.match_mode.captures:
    var route:=NavigationServer3D.map_get_path(nav,p,goal,true)
    var ok: bool=route.size()>1 and route[-1].distance_to(goal)<1.5 and route[0].distance_to(p)<1.5
    report.routes.append({"team":team,"start":str(p),"goal":str(goal),"points":route.size(),"pass":ok})
 check(report.routes.all(func(r):return r.pass),"Bot walking routes connect every spawn to both flags and captures")
 var camera: Camera3D=game.get_node("Overview")
 game.match_mode.draw_objectives()
 for team in [0,1]:
  var p: Vector3=game.ctf_spawns[team][0]
  var toward: Vector3=game.match_mode.bases[1-team]-p
  await shot(camera,p,atan2(-toward.x,-toward.z),"team"+str(team)+"-spawn")
  await shot(camera,game.match_mode.bases[team],atan2(-toward.x,-toward.z),"team"+str(team)+"-flag")
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
 for id in game.players:game.players[id].spectator=false;game._spawn(id)
 var starts: Dictionary={};var max_distance: Dictionary={}
 for id in game.bots.brains:starts[id]=game.fighters[id].position;max_distance[id]=0.0
 # Twenty seconds of real production movement, combat and bot input.
 for frame in 1200:
  await physics_frame;game._physics_process(1.0/60)
  for id in starts:max_distance[id]=maxf(max_distance[id],game.fighters[id].position.distance_to(starts[id]))
 report.bot_max_displacement=max_distance
 check(max_distance.values().all(func(d):return d>2.0),"All three bots leave their spawn area")
 check(game.fighters.values().all(func(a):return a.position.is_finite()),"Bot simulation remains finite")
 finish()
func finish():
 report.failures=failures;FileAccess.open(out+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.free();quit(0 if failures.is_empty() else 1)
