extends SceneTree
const OUT="res://test-results/dust2-arches/"
const VIEWS={
	"b-doors":[[237,500,118],[237,458,200]],
	"long-inner":[[406,137,54],[433,137,150]],
	"long-outer":[[549,195,54],[508,177,170]],
	"b-tunnel":[[295,563,118],[355,563,210]],
	"upper-tunnel":[[468,517,118],[430,517,210]],
	"lower-tunnel":[[353,403,54],[353.5,350,150]],
	"ct-underpass":[[211,280,54],[211,241,150]]}
func _initialize():run.call_deferred()
func p(a: Array) -> Vector3:return Vector3((a[1]-300)*6,a[2],(400-a[0])*6)/32.0+Vector3.UP*.05
func run():
	var stage:=OS.get_cmdline_user_args()[0]
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var path: String=OUT+"before/de_dust2_rebuilt.bsp" if stage=="before" else "res://maps/de_dust2_rebuilt.bsp"
	world.add_child(load("res://deathmatch/maps/loader.gd").read(path))
	var env:=WorldEnvironment.new();env.name="Environment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.85,1);env.environment.ambient_light_energy=.6;world.add_child(env)
	load("res://deathmatch/maps/atmosphere.gd").apply(world,"de_dust2_rebuilt")
	var camera:=Camera3D.new();camera.fov=85;world.add_child(camera);camera.make_current()
	for name in VIEWS:
		camera.position=p(VIEWS[name][0]);camera.look_at(p(VIEWS[name][1]))
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+name+"-"+stage+".png")
	world.free();quit()
