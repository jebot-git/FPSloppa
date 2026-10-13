extends SceneTree
## Isolated weapon geometry comparison, not a 32-player match benchmark.
const NAMES=["pistol","scout_pistol","designator","carbine","massacre","smg","assault_rifle","beam_pistol","guided_launcher","burst_pistol"]
func _initialize() -> void:run.call_deferred()
func summary(values:Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Real renderer required");quit(1);return
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("28323a");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);world.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.9;camera.position=Vector3(0,.5,5);world.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	var rows:Array=[]
	for pass_index in 6:
		var baseline:bool=pass_index%2==0
		var holder:=Node3D.new();world.add_child(holder)
		var templates:Array=[]
		for name in NAMES:
			var doc:=GLTFDocument.new();var state:=GLTFState.new()
			var path:String="res://test-results/weapon-sources/optimization-baseline/"+name+".glb" if baseline else "res://deathmatch/weapons/cq/"+name+".glb"
			if not FileAccess.file_exists(path):push_error("Missing comparison asset: "+path);quit(1);return
			assert(doc.append_from_file(path,state)==OK)
			templates.append(doc.generate_scene(state))
		for i in 32:
			var model:Node3D=templates[i%10].duplicate();holder.add_child(model);model.rotation.y=-PI/2
			model.position=Vector3(-1.85+(i%8)*.48, .9-(i/8)*.6,0)
		for model in templates:model.free()
		for i in 90:await process_frame
		var cpu:Array=[];var gpu:Array=[];var wall:Array=[];var primitives:Array=[];var draws:Array=[];var previous:=Time.get_ticks_usec()
		for i in 240:
			await process_frame
			var now:=Time.get_ticks_usec();wall.append((now-previous)/1000.0);previous=now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var row:Dictionary={"variant":"baseline" if baseline else "optimized","pass":pass_index,"samples":240,"cpu_ms":summary(cpu),"gpu_ms":summary(gpu),"frame_ms":summary(wall),"draw_calls":summary(draws),"primitives":summary(primitives)}
		rows.append(row);print("CQ_WEAPON_PROFILE ",JSON.stringify(row))
		holder.free();for i in 5:await process_frame
	var report:Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1280,800],"msaa":4,"vsync":false,"weapons":32,"samples":rows}
	FileAccess.open("res://test-results/weapon-sources/optimization-profile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	world.free();quit()
