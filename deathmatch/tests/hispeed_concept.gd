extends SceneTree
var game
var report: Dictionary={"checks":[],"routes":[]}
var failed:=false
var out: String
func _initialize():call_deferred("run")
func q(x: float,y: float,z: float=0) -> Vector3:return Vector3(-y,z,-x)/32.0+Vector3.UP*.05
func check(ok: bool,label: String) -> void:
 report.checks.append({"check":label,"pass":ok});failed=failed or not ok
 print("PASS " if ok else "FAIL ",label)
func run() -> void:
 var args:=OS.get_cmdline_user_args();var path: String=args[0];out=args[1]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
 var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
 game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-hispeed.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map=key
 game.start_host("Concept audit",0,100,7,true,"tf")
 if game.hud:game.hud.hide()
 check(game.active,"Offline TF concept starts")
 if not game.active:finish();return
 for id in game.players:game.players[id].spectator=true
 game.players[1].spectator=false;game.players[1].team=0;game.players[1].dead=false
 var actor=game.fighters[1];actor.quake_movement=true
 await physics_frame;await physics_frame
 # Follow actual collision using production movement. No teleport between route waypoints.
 actor.position=q(-2528,0);actor.velocity=Vector3.ZERO
 var route: Array=[q(-2400,0),q(-1800,0),q(-1744,128),q(-1592,128),q(-1592,-128),q(-1448,-128),q(-1448,128),q(-1304,128),q(-1304,-128),q(-1152,-128),q(-1120,0),q(-480,0),q(-464,224),q(128,224),q(128,0),q(856,0),q(856,-120),q(1072,-120,144),q(1200,0,144),q(1376,0,0),q(1496,0),q(1496,-120),q(1696,-120,144),q(1872,-32,144)]
 var reached:=true
 for target in route:
  var ok:=false
  for frame in 720:
   await physics_frame
   var delta: Vector3=target-actor.position
   if Vector2(delta.x,delta.z).length()<.25 and absf(delta.y)<.65:ok=true;break
   var direction:=Vector2(delta.x,delta.z).normalized()
   actor.simulate(direction,0,true,1.0/60)
  report.routes.append({"target":str(target),"end":str(actor.position),"pass":ok})
  print("ROUTE ",report.routes.size()," ",ok," ",actor.position)
  if not ok:reached=false;break
 check(reached,"Continuous ground route reaches upper access token through freight, acid catwalk and stairs")
 game.match_mode.tick(.02)
 check(game.match_mode.flags[1].carrier==1,"Walking into upper access token picks it up")
 # Native scoring must require the first objective.
 game.match_mode.return_flag(1);actor.position=game.match_mode.captures[0];game.match_mode.tick(.02)
 check(game.match_mode.scores[0]==0,"Lower console cannot score without access token")
 actor.position=game.match_mode.bases[1];game.match_mode.tick(.02)
 actor.position=game.match_mode.captures[0];game.match_mode.tick(.02)
 check(game.match_mode.scores[0]==1,"Upper token then lower console scores")
 if not DisplayServer.get_name()=="headless":
  root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
  var camera: Camera3D=game.get_node("Overview");camera.make_current();camera.fov=85
  game.match_mode.draw_objectives()
  for view in [
   ["train",q(-2700,620,670),q(-200,0,90)],
   ["freight",q(-2050,0,52),q(-1250,0,64)],
   ["tanker",q(-620,260,220),q(-40,0,120)],
   ["interior",q(352,60,52),q(752,0,70)],
   ["upper",q(1744,60,196),q(1968,-64,184)],
   ["cabin",q(1872,96,52),q(2016,-96,64)],
   ["roof",q(1072,0,372),q(2080,0,280)]]:
   camera.position=view[1];camera.look_at(view[2])
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"-"+view[0]+".png")
 finish()
func finish() -> void:
 report.failed=failed;FileAccess.open(out+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.free();quit(1 if failed else 0)
