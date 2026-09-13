extends SceneTree
const Art=preload("res://deathmatch/art.gd")
func _initialize():run.call_deferred()
func run() -> void:
	var axe: bool="axe" in OS.get_cmdline_user_args()
	var flame: bool="flame" in OS.get_cmdline_user_args()
	root.size=Vector2i(1500,850)
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("141c24");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.65;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);stage.add_child(sun)
	var cam:=Camera3D.new();stage.add_child(cam);cam.position=Vector3(0,0,6);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=4.7
	for i in 3:
		var model:=Art.weapon(7 if flame else 0,2,"tf_flame" if flame else "quake" if axe else "ut99");stage.add_child(model);model.position=Vector3((i-1)*1.5,0,0);model.rotation_degrees=Vector3(10,[-70,180,65][i],-5);model.scale=Vector3.ONE*1.65
		var label:=Label3D.new();label.text=(["TF PYRO · SIDE","FRONT · MUZZLE","REAR · GRIP"] if flame else ["SIDE · CUTTING EDGE FORWARD","FRONT · NARROW BLADE PROFILE","REAR / GRIP"] if axe else ["SIDE · CHAINSAW RECEIVER","FRONT · PNEUMATIC RAM","GRIP / REAR"])[i];label.position=Vector3((i-1)*1.5,-.8,0);label.font_size=30;label.pixel_size=.002;stage.add_child(label)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/weapon-variants/"+("tf-flamethrower" if flame else "axe" if axe else "impact-hammer")+".png")
	print("HAMMER_VISUAL_COMPLETE");stage.free();quit()
