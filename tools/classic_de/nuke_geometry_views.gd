extends SceneTree
const OUT="res://test-results/nuke-geometry/"
const VIEWS={
 "heaven-stairs":[[586,311,64],[577,254,218]],
 "heaven-landing":[[535,242,247],[588,274,225]],
 "wall-panels":[[483,376,60],[497,399,95]],
 "hut-posts":[[466,352,70],[434,313,120]],
 "upper-supports":[[494,352,80],[450,265,240]]}
func _initialize():run.call_deferred()
func p(a: Array) -> Vector3:return Vector3((a[1]-300)*6,a[2],(400-a[0])*6)/32.0+Vector3.UP*.05
func run():
	var stage:=OS.get_cmdline_user_args()[0]
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var path: String=OUT+"before/de_nuke_rebuilt.bsp" if stage=="before" else "res://maps/de_nuke_rebuilt.bsp"
	world.add_child(load("res://deathmatch/maps/loader.gd").read(path))
	var env:=WorldEnvironment.new();env.name="Environment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.85,1);env.environment.ambient_light_energy=.6;world.add_child(env)
	load("res://deathmatch/maps/atmosphere.gd").apply(world,"de_nuke_rebuilt")
	var camera:=Camera3D.new();camera.fov=85;world.add_child(camera);camera.make_current()
	for name in VIEWS:
		camera.position=p(VIEWS[name][0]);camera.look_at(p(VIEWS[name][1]))
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+name+"-"+stage+".png")
	world.free();quit()
