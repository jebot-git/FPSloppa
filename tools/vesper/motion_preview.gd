extends SceneTree
func _initialize():run.call_deferred()
func q(x: float,y: float,z: float)->Vector3:return Vector3(-y,z,-x)/32
func run() -> void:
 var args:=OS.get_cmdline_user_args();var path: String=args[0];var out: String=args[1]
 root.size=Vector2i(960,600);root.content_scale_size=root.size
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.set_physics_process(false);game.set_process(false);game.hud.hide()
 var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
 game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-fo.scn","sha256":hash}]
 if not game._load_map(key):game.free();quit(1);return
 game.match_mode.kind="tf";game.match_mode.reset();game.match_mode.draw_objectives()
 var camera: Camera3D=game.get_node("Overview")
 camera.position=q(1520,512,192);camera.look_at(q(1888,352,192));camera.make_current()
 var index: int=-1
 for i in game.gates.size():
  if game.gates[i].node.attributes.get("targetname","")=="blue_bell_lift_2":index=i
 assert(index>=0)
 var frame:=0
 for tick in 600:
  if tick==60:game._gate_state(index,true)
  if tick==360:game._gate_state(index,false)
  await physics_frame
  if tick%6==0:
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"-%04d.png"%frame);frame+=1
 game.queue_free();await process_frame;await process_frame;await process_frame
 quit()
