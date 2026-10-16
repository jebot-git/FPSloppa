extends SceneTree
const Models=preload("res://deathmatch/conquest/classes/models.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 var detail:=OS.get_cmdline_user_args().has("--detail")
 root.size=Vector2i(1600,800) if detail else Vector2i(1600,1100)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("25323d");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;world.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=2.;world.add_child(light)
 var slots:Array=[4,1,14,3,12,13,9,10,16,5,11,15,2,0,7]
 if detail:slots=[9,14]
 for i in slots.size():
  var slot:int=slots[i];var model:Node3D=Models.weapon(slot,"cq_technician");world.add_child(model)
  model.position=Vector3((i%3-1)*1.7,(2-i/3)*.95,0);model.rotation.y=-PI/2+.4;model.scale=Vector3.ONE*.85
  if detail:model.position=Vector3((i-.5)*1.4,0,0)
  var label:=Label3D.new();label.text=Models.entry(slot,"cq_technician");label.font_size=28;label.pixel_size=.0014;label.position=model.position+Vector3(0,-.32,.1);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;world.add_child(label)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.0,7);camera.look_at(Vector3.ZERO);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.8 if detail else 6.;camera.make_current()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png('/tmp/cq-weapon-details.png' if detail else '/tmp/cq-weapon-tiers.png')
 world.free();quit()
