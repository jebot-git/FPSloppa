extends SceneTree
const OUT="res://test-results/nuke-geometry/"
const VIEWS={
 "underground-landing":[[710,437,54],[735,485,-65]],
 "underground-side":[[697,480,54],[725,490,45]],
 "underground-bottom":[[734,550,-202],[734,440,0]],
 "t-spawn-corners":[[90,338,54],[230,345,54]],
 "ct-spawn-corners":[[756,249,54],[658,250,54]],
 "heaven-stairs":[[586,311,64],[577,254,218]],
 "heaven-landing":[[535,242,247],[588,274,225]],
 "wall-panels":[[483,376,60],[497,399,95]],
 "hut-posts":[[466,352,70],[434,313,120]],
 "upper-supports":[[494,352,80],[450,265,240]]}
func _initialize():run.call_deferred()
func p(a: Array) -> Vector3:return Vector3((a[1]-300)*6,a[2],(400-a[0])*6)/32.0+Vector3.UP*.05
func run():
	var stage:=OS.get_cmdline_user_args()[0]
	var args:=OS.get_cmdline_user_args()
	var output: String=args[2] if args.size()>2 else OUT
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var path: String=OUT+"before/de_nuke_rebuilt.bsp" if stage=="before" else "res://maps/de_nuke_rebuilt.bsp"
	if args.size()>1:path=args[1]
	world.add_child(load("res://deathmatch/maps/loader.gd").read(path))
	var env:=WorldEnvironment.new();env.name="Environment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.85,1);env.environment.ambient_light_energy=.6;world.add_child(env)
	load("res://deathmatch/maps/atmosphere.gd").apply(world,"de_nuke_rebuilt")
	var camera:=Camera3D.new();camera.fov=85;world.add_child(camera);camera.make_current()
	for name in VIEWS:
		camera.position=p(VIEWS[name][0]);camera.look_at(p(VIEWS[name][1]))
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(name+"-"+stage+".png"))
	world.free();quit()
