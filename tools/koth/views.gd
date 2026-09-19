extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func run() -> void:
 root.size=Vector2i(1200,720);root.content_scale_size=root.size
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.music.stop() # Keep unrelated looping music out of this visual/gong test.
 game.selected_map="koth_solstice";game.start_host("Hill views",0,100,30,true,"koth")
 game.hud.hide();game.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for id in ["koth_solstice","koth_torture","koth_hyperborea","koth_alichar"]:
  if not OS.get_cmdline_user_args().is_empty() and not id in OS.get_cmdline_user_args():continue
  game._load_map(id);game.match_mode.kind="koth";game.match_mode.reset()
  await physics_frame;await physics_frame
  var mode=game.match_mode;var space=game.get_world_3d().direct_space_state
  for index in mode.hills.size():
   mode.hill_index=index;mode.hill=mode.hills[index];mode.hill_remaining=30-index*9;mode.draw_objectives()
   if not is_instance_valid(mode.hill_label) or not mode.hill_label.text.contains("MOVES IN"):failures.append(id+" timer label")
   var focus: Vector3=mode.hill+Vector3.UP*1.3;var camera_point: Vector3=focus+Vector3(0,3,8);var best:=-1.
   for heading in 16:
    var offset:=Vector3(0,3,9).rotated(Vector3.UP,heading*TAU/16)
    var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(focus,focus+offset,1))
    var distance: float=offset.length() if hit.is_empty() else focus.distance_to(hit.position)
    if distance>best:best=distance;camera_point=focus+offset.normalized()*maxf(1,distance-.5)
   game.camera.global_position=camera_point;game.camera.look_at(focus);game.camera.fov=80
   for frame in 8:await process_frame
   RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png("res://test-results/koth-rotation/"+id+"-hill-"+str(index+1)+".png")
   print("KOTH_VIEW ",id," ",index+1," ",mode.hill_label.text)
 game._end_round();await process_frame
 if not game.round_clock.gong.playing or game.round_clock.gong.bus!="ArenaEffects":failures.append("Round-end gong playback")
 FileAccess.open("res://test-results/koth-rotation/views.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures},"  "))
 print("KOTH_VIEWS_RESULT ",JSON.stringify(failures));game.round_clock.clear();game.disconnect_game();await create_timer(.2).timeout;game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
