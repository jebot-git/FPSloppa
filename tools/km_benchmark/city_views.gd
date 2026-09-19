extends SceneTree
const BASE="res://maps/Benchmark1km/"
const OUT="res://test-results/city/"
func _initialize():run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world:=WorldEnvironment.new();world.environment=Environment.new();root.add_child(world)
	var level: Node3D=load(BASE+"zones-lightmap1.scn").instantiate();root.add_child(level)
	preload("res://tools/km_benchmark/presentation.gd").apply(root)
	var camera:=Camera3D.new();camera.far=1500;camera.fov=75;root.add_child(camera);camera.make_current()
	root.use_occlusion_culling=true;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=60
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"layout.json"))
	var views: Array=[]
	for zone in 16:
		var p: Vector3=preload("res://tools/km_benchmark/city_art.gd").v(layout.zones[zone].center)
		views.append({"name":"district_%02d"%zone,"from":p+Vector3(-12,5,0),"to":p+Vector3(-64,23,-64)})
	views.append({"name":"city_skyline","from":Vector3(-480,145,-480),"to":Vector3(-40,-80,-40)})
	views.append({"name":"gate","from":Vector3(-269,4,-370),"to":Vector3(-250,8,-375)})
	views.append({"name":"cathedral","from":Vector3(-342,14,-348),"to":Vector3(-447,26,-445)})
	views.append({"name":"closed_border","from":Vector3(-430,4,-480),"to":Vector3(-430,15,-500)})
	for view in views:
		camera.position=view.from;camera.look_at(view.to)
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUT+view.name+".png")==OK)
		print("CITY_VIEW ",view.name)
	level.free();camera.free();world.free();quit()
