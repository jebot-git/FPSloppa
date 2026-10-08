extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map="de_varq_santorini";game.start_host("Bot wallbang checks",0,100,30,true,"de")
 game.set_physics_process(false);game.set_process(false)
 for frame in 8:await physics_frame
 var ai=game.bots;var pen=game.get_node("Map/MapRuntime").ballistics;var cover=pen.bsp_cover
 check(pen.ready,"Santorini penetration profile loaded")
 var space=game.get_world_3d().direct_space_state;var origin:=Vector3.ZERO;var point:=Vector3.ZERO;var found:=false
 for model in cover.models:
  for i in range(int(model.faces[0]),int(model.faces[0]+model.faces[1])):
   var face: Dictionary=cover.faces[i]
   if face.material!="wood":continue
   var normal: Vector3=cover.planes[face.plane].normal*(1 if face.side==0 else -1)
   if absf(normal.y)>.05:continue
   var center:=Vector3.ZERO
   for p in face.polygon:center+=p
   center=center/face.polygon.size()+model.node.global_position
   var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*.04,center-normal*.04,1))
   if hit.is_empty():continue
   var passage: Dictionary=pen.exit_surface(hit.position,-normal,39./32,space)
   if passage.is_empty():continue
   origin=center+normal*1.5;point=passage.position-normal*.8
   for id in game.players:game.players[id].spectator=id!=-1;game.fighters[id].position=Vector3(1000,1000,1000)
   game.fighters[-1].position=origin-Vector3.UP*game.fighters[-1].eye_height()
   if ai.wallbang.lane(ai,-1,point,6):found=true;break
  if found:break
 check(found,"Bot recognizes actual penetrable Santorini cover")
 if found:
  check(not ai.wallbang.lane(ai,-1,point,1),"Nonpenetrating pistol rejected")
  var s: Dictionary=game.players[-1];s.weapon=6;s.owned=[0,6];s.ammo=[100,100,100,100];s.dead=false;s.spectator=false
  game.match_mode.defusal.phase="live"
  var brain: Dictionary=ai.new_brain(-1);brain.enemy=0;brain.remembered_enemy=1;brain.seen_position=point-Vector3.UP*1.05;brain.last_seen_at=game.clock;brain.seen_at=game.clock-1
  ai.aim(-1,point,1.);s.fire=false;ai.combat(-1,brain,.2)
  check(s.fire,"Native combat suppresses last seen position without live enemy pose")
  brain.goal=game.fighters[-1].position+Vector3.RIGHT*10;brain.goal_kind="search"
  var saved_yaw: float=s.yaw;ai.steer(-1,brain,.2)
  check(is_equal_approx(s.yaw,saved_yaw),"Native movement retains suppression aim")
  var accelerated=ai.native_ai;ai.native_ai=null;s.fire=false;ai.combat(-1,brain,.2)
  check(s.fire,"GDScript combat uses the same wallbang decision")
  saved_yaw=s.yaw;ai.steer(-1,brain,.2)
  check(is_equal_approx(s.yaw,saved_yaw),"GDScript movement retains suppression aim");ai.native_ai=accelerated
  s.fire=false;brain.last_seen_at=game.clock-1.;ai.wallbang.apply(ai,-1,brain,.2);check(not s.fire,"Expired observation cannot initiate a wallbang")
  game.players[1].spectator=false;game.players[1].dead=false;game.players[1].team=s.team
  game.fighters[1].position=point-Vector3.UP*game.fighters[1].torso_height()
  check(not ai.wallbang.lane(ai,-1,point,6),"Teammate behind cover blocks wallbang decision")
 check(game.match_mode.defusal.classic_movement(),"Converted DE enables CS movement")
 check(game.fighters[-1].cs16_enabled,"Bot uses CS movement physics")
 var report={"failures":failures,"passed":failures.is_empty()}
 FileAccess.open("res://tools/de_penetration/bot-wallbang.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.free();quit(0 if failures.is_empty() else 1)
