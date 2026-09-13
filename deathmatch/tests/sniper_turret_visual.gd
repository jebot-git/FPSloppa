extends SceneTree
const Art=preload("res://deathmatch/art.gd")
func _initialize():run.call_deferred()
func run() -> void:
 root.size=Vector2i(1500,1000)
 var stage:=Node3D.new();root.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("141c24");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);stage.add_child(sun)
 var cam:=Camera3D.new();stage.add_child(cam);cam.position=Vector3(0,0,6);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=4.9;cam.position.y=-.35
 for row in 2:
  for i in 3:
   var mount:=Node3D.new();stage.add_child(mount);mount.position=Vector3((i-1)*1.8,.6-row*1.55,0);mount.rotation_degrees=Vector3(12,[-70,180,65][i],0)
   var model:=Art.weapon(9 if row==0 else 5,2,"ut99" if row==0 else "sentry");mount.add_child(model)
   if row==1:
    model.scale=Vector3.ONE*.7
    Art.box(mount,Vector3(0,-.7,0),Vector3(1,.3,.8),Art.material(Color("8c3039"),.35))
    Art.box(mount,Vector3(0,-.4,0),Vector3(.25,.45,.25),Art.material(Color("8c3039"),.35))
   var label:=Label3D.new();label.text=("SNIPER" if row==0 else "SENTRY")+" · "+["SIDE","FRONT","REAR"][i];label.position=Vector3((i-1)*1.8,-row*1.55-.38,0);label.font_size=32;label.pixel_size=.002;stage.add_child(label)
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/weapon-variants/sniper-turret.png")
 print("SNIPER_TURRET_VISUAL_COMPLETE");stage.free();quit()
