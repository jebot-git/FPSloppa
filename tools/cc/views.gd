extends SceneTree
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1000,700);root.content_scale_size=root.size
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.15,.18);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
 var cam=Camera3D.new();world.add_child(cam);cam.fov=95;cam.make_current()
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
 for recipe in JSON.parse_string(FileAccess.get_file_as_string("res://tools/cc/recipes.json")):
  var id: String=recipe.id
  var row=catalog.filter(func(r):return r.id==id)[0]
  var level=load(row.scene).instantiate();world.add_child(level)
  var hill=Vector3(-recipe.center[1]*recipe.scale,recipe.center[2],-recipe.center[0]*recipe.scale)/32
  for i in 4:
   cam.position=hill+Vector3(0,2.2,5).rotated(Vector3.UP,i*PI/2)
   cam.look_at(hill+Vector3.UP*.5)
   for frame in 5:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/cc/"+id+"-after-"+str(i)+".png")
  level.free()
 world.free();quit.call_deferred()
