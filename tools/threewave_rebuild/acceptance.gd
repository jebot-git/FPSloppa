extends SceneTree
var game
var failures: Array=[]
var report: Dictionary={"checks":[],"paths":[],"walks":[]}
var out: String
func _initialize():call_deferred("run")
func q(p: Array) -> Vector3:return Vector3(-p[1],p[2],-p[0])/32.0
func check(ok: bool,label: String):
 report.checks.append({"check":label,"pass":ok})
 if not ok:failures.append(label)
 print("PASS " if ok else "FAIL ",label)
func length_of(route: PackedVector3Array) -> float:
 var total:=0.0
 for i in range(1,route.size()):total+=route[i-1].distance_to(route[i])
 return total
func walk(nav: RID,start: Vector3,goal: Vector3,label: String,via: Array=[]) -> void:
 var route:=PackedVector3Array();var previous:=start
 var goals: Array=via.duplicate();goals.append(goal)
 for next_goal in goals:
  var part:=NavigationServer3D.map_get_path(nav,previous,next_goal,true)
  if part.is_empty() or part[-1].distance_to(next_goal)>1.2:
   print("INCOMPLETE_SEGMENT ",label," start=",previous," goal=",next_goal," end=",part[-1] if not part.is_empty() else Vector3.ZERO)
   check(false,"Complete navigation segment on "+label);return
  route.append_array(part);previous=next_goal
 var actor=preload("res://deathmatch/fighter.gd").new()
 actor.setup(9000,"CTF route probe",Color.WHITE);actor.collision_mask=1;actor.quake_movement=true
 game.add_child(actor);actor.position=start
 var step:=1;var frames:=0
 for frame in 7200:
  if step>=route.size():break
  await physics_frame
  var toward: Vector3=route[step]-actor.position
  if Vector2(toward.x,toward.z).length()<.35 and absf(toward.y)<.65:step+=1;continue
  actor.simulate(Vector2(0,-1),atan2(-toward.x,-toward.z),false,1.0/60,false);frames+=1
  if frames>240 and actor.position.y<game.fall_limit:break
 var ok: bool=route.size()>1 and actor.position.distance_to(goal)<1.2
 report.walks.append({"name":label,"pass":ok,"seconds":frames/60.0,"end":str(actor.position),"goal":str(goal),"step":step,"points":route.size(),"next":str(route[mini(step,route.size()-1)]) if not route.is_empty() else "empty"})
 check(ok,"Player capsule walks "+label+" without jumps or teleports")
 print("WALK ",JSON.stringify(report.walks[-1]));actor.free()
func run():
 var args:=OS.get_cmdline_user_args();var key:=args[0];out=args[1]
 var path:="res://maps/"+key+".bsp";report.map=key;report.sha256=FileAccess.get_sha256(path)
 var authored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/CTFStudies/"+key+"/manifest.json"))
 root.size=Vector2i(1280,800)
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
 game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"res://maps/cache/"+key+".scn","sha256":report.sha256}];game.selected_map=key
 game.start_host("CTF audit",0,100,30,true,"ctf")
 check(game.active,"Offline CTF match starts")
 if not game.active:finish();return
 if game.hud:game.hud.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 check(game.ctf_spawns[0].size()==8 and game.ctf_spawns[1].size()==8,"Eight native spawns per team")
 check(game.map_objectives.size()==2,"Two native flag objectives")
 var level: Node=game.get_node("Map").get_child(0)
 if not OS.has_feature("dedicated_server"):
  check(level.get_meta("baked_light_faces",0)>0 and level.get_meta("baked_light_rgb",false),"Embedded RGB lightmaps load")
  check(level.get_meta("baked_light_invalid_faces",0)==0 and level.get_meta("baked_light_overflow_faces",0)==0,"Lightmap atlas has no invalid or overflowing faces")
 for attempt in 1200:
  if game.bots.ready_to_walk:break
  await create_timer(.05).timeout
 check(game.bots.ready_to_walk,"Baked navigation loads")
 await physics_frame;await physics_frame
 var nav: RID=game.bots.region.get_navigation_map();NavigationServer3D.map_force_update(nav)
 await create_timer(.3).timeout;NavigationServer3D.map_force_update(nav)
 var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.65
 for team in [0,1]:
  for point in game.ctf_spawns[team]:
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=point+Vector3.UP*.84;query.collision_mask=1
   check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Spawn capsule clear "+str(point))
   var floor_ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,point-Vector3.UP*.5,1)
   check(not game.get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty(),"Spawn has nearby ground "+str(point))
   for goal in game.match_mode.bases:
    var route:=NavigationServer3D.map_get_path(nav,point,goal,true)
    var ok: bool=route.size()>1 and route[-1].distance_to(goal)<1.2 and route[0].distance_to(point)<1.2
    report.paths.append({"team":team,"start":str(point),"goal":str(goal),"metres":length_of(route),"points":route.size(),"first":str(route[0]) if not route.is_empty() else "empty","last":str(route[-1]) if not route.is_empty() else "empty","pass":ok})
 check(report.paths.all(func(r):return r.pass),"Every spawn has a complete navigation path to both flags")
 # Exercise authoritative CTF rules at real objective coordinates.
 for id in game.players:game.players[id].spectator=true
 game.players[1].spectator=false;game.players[1].dead=false
 for team in [0,1]:
  game.players[1].team=team
  for flag in [0,1]:game.match_mode.return_flag(flag)
  game.fighters[1].position=game.match_mode.bases[1-team];game.match_mode.tick(.05)
  check(game.match_mode.flags[1-team].carrier==1,"Team %d takes enemy flag"%team)
  game.match_mode.drop(1);check(game.match_mode.flags[1-team].dropped,"Team %d drops enemy flag"%team)
  game.match_mode.return_flag(1-team);game.match_mode.tick(.05)
  var before: int=game.match_mode.scores[team]
  game.fighters[1].position=game.match_mode.bases[team];game.match_mode.tick(.05)
  check(game.match_mode.scores[team]==before+1,"Team %d captures at its own flag"%team)
 var camera: Camera3D=game.get_node("Overview")
 if DisplayServer.get_name()!="headless":
  game.match_mode.draw_objectives()
  var views: Array=authored.views.duplicate(true)
  for team in [0,1]:views.append([authored.spawns[team][0],authored.flags[team],"team%d-spawn"%team])
  for item in views:
   camera.position=q(item[0])+Vector3.UP*1.5;camera.look_at(q(item[1])+Vector3.UP*.8);camera.make_current()
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"-"+str(item[2]).replace(" ","-")+".png")
 if args.has("--walk"):
  Engine.physics_ticks_per_second=60
  for team in [0,1]:await walk(nav,game.match_mode.bases[team],game.match_mode.bases[1-team],"flag %d to %d"%[team,1-team])
 if args.has("--routes"):
  Engine.physics_ticks_per_second=60
  for lane in authored.routes:
   var points: Array=[]
   for p in lane.points:points.append(q(p)+Vector3.UP*.05)
   await walk(nav,points[0],points[-1],lane.name,points.slice(1,-1))
 if args.has("--bots"):
  # Both teams use the production AI and movement for a bounded live match.
  for id in range(-1,-9,-1):
   if not game.players.has(id):game._add_player(id,"CTF audit bot "+str(-id))
   game.players[id].spectator=false;game.players[id].team=(-id)%2;game._spawn(id)
  game.players[1].spectator=true;game.match_mode.scores=[0,0]
  for flag in [0,1]:game.match_mode.return_flag(flag)
  game.set_physics_process(true)
  var starts: Dictionary={};var excursions: Dictionary={};var flag_touches: Array=[0,0]
  for id in game.fighters:starts[id]=game.fighters[id].position;excursions[id]=0.0
  for second in 60:
   await create_timer(1).timeout
   for id in starts:
    if game.fighters.has(id):excursions[id]=maxf(excursions[id],game.fighters[id].position.distance_to(starts[id]))
   for team in [0,1]:
    if game.match_mode.flags[team].carrier!=0:flag_touches[team]+=1
  game.set_physics_process(false)
  var moved:=0
  for id in excursions:
   if id<0 and excursions[id]>2:moved+=1
  report.bot_match={"seconds":60,"players":8,"scores":game.match_mode.scores,"bots_displaced":moved,"maximum_displacements":excursions,"seconds_with_flag_carried":flag_touches}
  check(moved>=6,"At least six of eight production bots leave their initial spawn")
 finish()
func finish():
 report.failures=failures
 var file:=FileAccess.open(out+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("CTF_STUDY_RESULT ",report.map," failures=",failures)
 game.free();await process_frame;quit(0 if failures.is_empty() else 1)
