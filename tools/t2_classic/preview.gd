extends SceneTree
var g
func _initialize():run.call_deferred()
func vector(a):return Vector3(a[0],a[1],a[2])
func run():
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 var keys: Array=Array(OS.get_cmdline_user_args())
 if keys.is_empty():keys=preload("res://deathmatch/maps/t2_classic.gd").IDS
 for key in keys:
  g.selected_map=key;g.start_host("Classic preview",0,100,15,true,"st")
  g.set_process(false);g.set_physics_process(false);g.menu_open=false;g.hud.hide()
  for id in g.players:g.players[id].spectator=true
  if g.has_node("Menu"):g.get_node("Menu").hide()
  var probes=JSON.parse_string(FileAccess.get_file_as_string("res://maps/T2Classic/"+key+"/probes.json"))
  g.camera.far=3500;g.camera.make_current()
  for i in probes.views.size():
   g.camera.global_position=vector(probes.views[i].eye);g.camera.look_at(vector(probes.views[i].look))
   for frame in 8:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/t2-classic/"+key+"/view-"+str(i)+".png")
  g.disconnect_game();await physics_frame;await physics_frame
 g.queue_free();await process_frame;print("CLASSIC_PREVIEW_DONE");quit()
