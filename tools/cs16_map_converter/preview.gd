extends SceneTree
## Capture the actual imported scene with Vulkan, using source spawns and sites.
const Loader=preload("res://deathmatch/maps/loader.gd")
const Layout=preload("res://deathmatch/modes/defusal_maps.gd")
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()<2:quit(1);return
	var path:=args[0];var output:=args[1]
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	root.title="CS map conversion review"
	var level:=Loader.read(path)
	if not level:quit(1);return
	root.add_child(level)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.19,.25,.29)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.15
	level.add_child(environment)
	var camera:=Camera3D.new();camera.fov=85;level.add_child(camera);camera.make_current()
	var layout:=Layout.embedded(path);var views: Array=[]
	for role in 2:
		views.append({"name":"spawn_"+str(role),"position":Layout.vector(layout.starts[role][0])+Vector3.UP*1.6,"yaw":layout.start_yaws[role][0]})
	for i in 2:
		for yaw in [0,PI*.5,PI,PI*1.5]:
			views.append({"name":"site_"+str(i)+"_"+str(views.size()),"position":Layout.vector(layout.sites[i])+Vector3.UP*1.6,"yaw":yaw})
	for view in views:
		camera.position=view.position;camera.rotation=Vector3(-.05,view.yaw,0)
		for frame in 8:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view.name+".png"))
	print("CS_MAP_PREVIEW_PASS ",RenderingServer.get_current_rendering_method()," views=",views.size())
	level.free();quit()
