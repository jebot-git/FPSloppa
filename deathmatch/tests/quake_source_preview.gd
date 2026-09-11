extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args();var path: String=args[0];var out: String=args[1]
 root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false);game.hud.hide()
 var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
 game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-qsrc.scn","sha256":hash}]
 if not game._load_map(key):game.free();quit(1);return
 await physics_frame;await physics_frame
 var camera: Camera3D=game.get_node("Overview");camera.make_current()
 if key.begins_with("tf_") or key.begins_with("threewave_"):
  game.match_mode.kind="tf" if key.begins_with("tf_") else "ctf"
  game.match_mode.reset();game.match_mode.draw_objectives()
  for team in [0,1]:
   await shot(game,camera,game.ctf_spawns[team][0],"spawn%d"%(team*2),out,false)
   await shot(game,camera,game.match_mode.bases[team],"spawn%d"%(team*2+1),out,true)
  game.free();quit();return
 for i in mini(4,game.spawn_points.size()):
  var index: int=i*game.spawn_points.size()/mini(4,game.spawn_points.size())
  camera.position=game.spawn_points[index]+Vector3.UP*1.48;camera.rotation=Vector3(0,game.spawn_yaws[index],0)
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"-spawn%d.png"%i)
 game.free();quit()

func shot(game,camera: Camera3D,p: Vector3,label: String,out: String,look_back: bool) -> void:
 var eye:=p+Vector3.UP*1.48
 var best:=Vector3.FORWARD;var distance:=-1.0
 for n in 16:
  var direction:=Vector3(sin(n*TAU/16),0,cos(n*TAU/16))
  var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+direction*8,1))
  var reach: float=8.0 if ray.is_empty() else eye.distance_to(ray.position)
  if reach>distance:distance=reach;best=direction
 camera.position=eye+best*minf(4.0,maxf(0,distance-.5)) if look_back else eye
 camera.look_at(eye if look_back and distance>.6 else camera.position+best)
 camera.make_current()
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"-"+label+".png")
