extends SceneTree
const OUT="res://test-results/de-study-comparison/"
const VIEWS={
	"nuke":{"eye":[461,286,86],"look":[426,320,70],"feature":"hut"},
	"inferno":{"eye":[474,571,155],"look":[574,571,155],"feature":"apartments"},
	"train":{"eye":[182,335,155],"look":[182,442,118],"feature":"upper-hall"},
	"aztec":{"eye":[264,248,-180],"look":[216,231,83],"feature":"canal-ramp"},
	"dust2":{"eye":[176,189,278],"look":[215,100,266],"feature":"unchanged-control"}}
func _initialize():run.call_deferred()
func p(a: Array) -> Vector3:return Vector3((a[1]-300)*6,a[2],(400-a[0])*6)/32.0+Vector3.UP*.05
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	for name in VIEWS:
		if not OS.get_cmdline_user_args().is_empty() and name not in OS.get_cmdline_user_args():continue
		var id: String="de_"+name+"_rebuilt"
		for stage in ["before","after"]:
			var world:=Node3D.new();root.add_child(world)
			var path: String=OUT+"before/"+id+"/"+id+".bsp" if stage=="before" else "res://maps/"+id+".bsp"
			var level=load("res://deathmatch/maps/loader.gd").read(path);world.add_child(level)
			var filtering=load("res://deathmatch/maps/filtering.gd").new();filtering.apply(level,2,true,0)
			var env:=WorldEnvironment.new();env.name="Environment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.48,.61,.72);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.85,1);env.environment.ambient_light_energy=.6;world.add_child(env)
			load("res://deathmatch/maps/atmosphere.gd").apply(world,id)
			env.environment.background_mode=Environment.BG_SKY
			var camera:=Camera3D.new();camera.fov=78;camera.far=500;world.add_child(camera);camera.make_current()
			camera.position=p(VIEWS[name].eye);camera.look_at(p(VIEWS[name].look))
			for frame in 8:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+name+"-"+stage+".png")
			print("COMPARISON_RENDER ",name," ",stage)
			world.free();await process_frame
	quit()
