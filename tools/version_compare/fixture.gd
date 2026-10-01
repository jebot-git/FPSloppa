extends Node
## Common driver injected unchanged into both versions. Uses their own assets/code.
const Library=preload("res://deathmatch/avatars/library.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var rigs: Array=[]
var clock:=0.0
var root:Window
var output:String
var variant:String
var seconds:=20.0
var world:Node3D
var library
func _ready():
	root=get_tree().root
	process_priority=-100000
	run.call_deferred()
func _process(delta:float):
	clock+=delta
	for i in rigs.size():
		var t:=clock+i*.37
		var pose:=Poses.neutral()
		pose.head.basis=Basis(Vector3.UP,sin(t*.6)*.15)
		pose.head.origin+=Vector3(sin(t)*.025,sin(t*2)*.035,0)
		pose.left.origin+=Vector3(0,sin(t*2)*.05,sin(t)*.07)
		pose.right.origin+=Vector3(0,cos(t*2)*.05,cos(t)*.07)
		pose.weapon=pose.right
		pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.92,0)),"chest":Transform3D(Basis.IDENTITY,Vector3(0,1.2,0))}
		for side in ["left","right"]:
			var sign_side:=-1.0 if side=="left" else 1.0
			pose.body[side+"_foot"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.13,.08+maxf(0,sin(t*3*sign_side))*.06,sin(t*3*sign_side)*.13))
			pose.body[side+"_knee"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.16,.5,-.2))
		rigs[i].target_xr_pose=pose
func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()<2 or args[1] not in ["armed","unarmed"]:push_error("Expected output path and armed/unarmed");get_tree().quit(2);return
	output=args[0];variant=args[1]
	if args.size()>2:seconds=float(args[2])
	seed(20261001)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	world=Node3D.new();add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.7,4.4);camera.look_at(Vector3(0,1,0));camera.current=true;camera.fov=65
	var environment:=WorldEnvironment.new();world.add_child(environment);environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("202630")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-25,0)
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(20,20);world.add_child(floor_mesh)
	library=Library.new()
	for model in ["sample_d","sample_f","sample_g"]:library.entries[model]={"path":"res://vrm/"+model+".vrm"}
	var weapons: Array=[["doom",4],["doom",6],["quake",9],["ut99",3],["ut99",7],["tribes",2],["cs16",1],["cs16",5]]
	for i in 8:
		var actor:=Node3D.new();world.add_child(actor);actor.position=Vector3((i%4-1.5)*1.35,0,-floori(i/4.0)*1.8)
		var rig=library.create_avatar(["sample_d","sample_f","sample_g"][i%3])
		if not rig:push_error(library.last_error);get_tree().quit(2);return
		actor.add_child(rig)
		if variant=="armed":rig.set_weapon(weapons[i][1],weapons[i][0])
		else:
			rig.unarmed=true
			if rig.gun:rig.gun.free();rig.gun=null
			if rig.offhand_gun:rig.offhand_gun.free();rig.offhand_gun=null
			rig.weapon_id=-1
		rig.speed=3;rig.movement=Vector3(0,0,-3);rig.gait.phase=i/8.0;rig.enable_distance_lod();rigs.append(rig)
	await get_tree().create_timer(6).timeout
	clock=0.0
	var metadata:={"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"size":str(root.size),"native_pose":ClassDB.class_exists("FPSPose"),"variant":variant,"weapons":weapons if variant=="armed" else [],"msaa":root.msaa_3d,"render_scale":root.scaling_3d_scale,"vsync":DisplayServer.window_get_vsync_mode(),"render_thread_model":ProjectSettings.get_setting("rendering/driver/threads/thread_model",1)}
	var frames:Array=[]
	var start:=Time.get_ticks_usec();var last:=start
	var thread_path:="/proc/self/task/%d/schedstat"%OS.get_process_id()
	var cpu_start:=FileAccess.open(thread_path,FileAccess.READ).get_line().strip_edges().split(" ")[0].to_int()
	while (Time.get_ticks_usec()-start)<seconds*1000000:
		await get_tree().process_frame
		var now:=Time.get_ticks_usec()
		frames.append([float(now-last)/1000.0,RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])
		last=now
	var cpu_end:=FileAccess.open(thread_path,FileAccess.READ).get_line().strip_edges().split(" ")[0].to_int()
	metadata.main_cpu_ms_per_frame=float(cpu_end-cpu_start)/1000000.0/frames.size()
	metadata.physics_backend=world.get_world_3d().direct_space_state.get_class()
	metadata.measured_seconds=float(last-start)/1000000.0
	metadata.sleeping=rigs.filter(func(r):return r.animation_sleeping).size()
	metadata.lod_tiers=rigs.map(func(r):return r.distance_lod.tier)
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify({"metadata":metadata,"columns":["frame_ms","render_cpu_ms","gpu_ms","draw_calls","primitives"],"frames":frames}))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+".png")
	print("VERSION_BENCHMARK_COMPLETE ",output," frames=",frames.size()," main_cpu_ms=",metadata.main_cpu_ms_per_frame)
	rigs.clear();world.free();library.free()
	await get_tree().process_frame
	get_tree().quit()
