extends SceneTree
const Compiler=preload("res://deathmatch/avatars/surface_compiler.gd")
const OUT="res://test-results/vrm-optimization/"
var rigs: Array=[]
func _initialize():run.call_deferred()
func stats(values: Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[ceili(values.size()*.95)-1]}
func run():
	preload("res://deathmatch/avatars/visual_loader.gd").compile_surfaces=false
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.3,4.3);camera.current=true
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202630");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);world.add_child(light)
	var library=preload("res://deathmatch/avatars/library.gd").new()
	var geometry_cache: Dictionary={}
	var originals: Dictionary={};var compiled: Dictionary={};var counts:=[]
	for sample in ["sample_d","sample_f","sample_g"]:library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
	for i in 8:
		var actor:=Node3D.new();actor.position=Vector3((i%4-1.5)*.85,0,-floori(i/4.0)*1.2);world.add_child(actor)
		var rig=library.create_avatar(["sample_d","sample_f","sample_g"][i%3]);actor.add_child(rig);rig.preview_mode=0;rig.set_weapon(-1);rig.set_process(false);rig.solver.active=false;rig.eyes.active=false;rig.motion.pause();rigs.append(rig)
		for mesh in rig.visual_meshes:originals[mesh]=mesh.mesh
		counts.append(Compiler.compile(rig.model,geometry_cache))
		for mesh in rig.visual_meshes:compiled[mesh]=mesh.mesh
	var reports:=[]
	for phase in ["original","compiled","compiled","original"]:
		for mesh in originals:mesh.mesh=compiled[mesh] if phase=="compiled" else originals[mesh]
		for frame in 120:await process_frame
		var cpu:=[];var gpu:=[];var wall:=[];var draws:=[];var last:=Time.get_ticks_usec()
		for frame in 360:
			await process_frame
			var now:=Time.get_ticks_usec();wall.append((now-last)/1000.0);last=now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			draws.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		var row:={"variant":phase,"wall_ms":stats(wall),"render_cpu_ms":stats(cpu),"gpu_ms":stats(gpu),"draw_calls":stats(draws)};reports.append(row);print("SURFACE_BENCHMARK ",JSON.stringify(row))
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"surfaces-"+phase+".png")
	FileAccess.open(OUT+"surface-render-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify({"reports":reports,"surface_counts":counts,"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"scope":"8 static skinned avatars; 1280x800 Mobile, no vsync, no XR/network/IK/springs; ABBA 120 warmup + 360 measured frames per phase"},"  "))
	originals.clear();compiled.clear();geometry_cache.clear();rigs.clear();world.free();library.free();quit()
