extends SceneTree
## Real OpenXR render-only scene. No Arena, bot controller, navigation or fighters.
const Map=preload("res://tools/voxel_battle/map.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Preparation=preload("res://tools/voxel_battle/avatar_prepass.gd")
const Probe=preload("res://tools/voxel_battle/performance.gd")
class Holder extends Node3D:
	var rig
	func set_avatar(value, _hash: String) -> void:rig=value;add_child(rig)
class Avatars extends Node:
	var library
	var choices: Dictionary={}
	var load_queue: Array=[]
class Crowd extends Node3D:
	var headless:=false
	var avatars
	var players: Dictionary={}
	var fighters: Dictionary={}
var map
var crowd:=Crowd.new()
var xr: XRInterface
var origin: XROrigin3D
var camera: XRCamera3D
var point:=Vector3.ZERO
var ready:=false
var desired_view:=Transform3D.IDENTITY
var capture
var output:="res://test-results/valley-stereo"
var duration:=60.0
var probe:=Probe.new()
var visibility: Array=[]
var measured:=false
var elapsed:=0.0
func _initialize() -> void:run.call_deferred()
func _process(delta: float) -> bool:
	if not ready:return false
	# A fixed benchmark viewpoint keeps all avatars in the workload. OpenXR still
	# supplies both native eye projections, IPD, swapchains and frame pacing.
	var tracker=XRServer.get_tracker("head")
	if tracker!=null:
		var pose=tracker.get_pose("default")
		if pose!=null:origin.global_transform=desired_view*(XRServer.get_reference_frame()*pose.get_adjusted_transform()).affine_inverse()
	map.update_view(camera)
	if measured:
		elapsed+=delta;probe.record(delta,root.get_viewport_rid(),map,elapsed,"OpenXR stereo 32 animated avatars")
		var visible:=0
		for holder in crowd.fighters.values():
			if camera.is_position_in_frustum(holder.global_position+Vector3.UP*.85):visible+=1
		visibility.append(visible)
	return false
func choose_point() -> Vector3:
	var rng:=RandomNumberGenerator.new();rng.seed=20261012
	var space: PhysicsDirectSpaceState3D=map.get_world_3d().direct_space_state
	for attempt in 2048:
		var candidate:=Vector2(rng.randf_range(-235,235),rng.randf_range(-235,235))
		var positions: Array[Vector3]=[];var valid:=true;var low:=INF;var high:=-INF
		for i in 32:
			var x: float=candidate.x+(i%8-3.5)*2
			var z: float=candidate.y-int(i/8)*2.5
			var h:=Landscape.surface(x,z).x
			if Landscape.water_mask(x,z)>.01:valid=false;break
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,h+.3,z),Vector3(x,h-.5,z),1))
			if hit.is_empty() or hit.collider.name!="TerrainCollision":valid=false;break
			var bounds:=AABB(Vector3(x-.6,h+.2,z-.6),Vector3(1.2,1.7,1.2))
			for obstacle in map.geometry:
				if bounds.intersects(obstacle):valid=false;break
			if not valid:break
			positions.append(Vector3(x,h+.05,z));low=minf(low,h);high=maxf(high,h)
		if valid and high-low<2:
			var camera_position:=Vector3(candidate.x,Landscape.surface(candidate.x,candidate.y+10).x+1.7,candidate.y+10)
			for position in positions:
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(camera_position,position+Vector3.UP*.85,1)).is_empty():valid=false;break
		if valid and high-low<2:
			for i in 32:crowd.fighters[i].position=positions[i]
			return Vector3(candidate.x,Landscape.surface(candidate.x,candidate.y).x,candidate.y)
	push_error("No dry clear random crowd footprint found");quit(1);return Vector3.ZERO
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--seconds" and i+1<args.size():duration=maxf(1,float(args[i+1]))
		if args[i]=="--output" and i+1<args.size():output=args[i+1]
	if DisplayServer.get_name()=="headless":push_error("Stereo test requires Vulkan/OpenXR");quit(1);return
	xr=XRServer.find_interface("OpenXR")
	if xr==null or not xr.is_initialized():push_error("No initialized OpenXR runtime");quit(1);return
	XRServer.primary_interface=xr;root.use_xr=true
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	DirAccess.make_dir_recursive_absolute(output)
	preload("res://addons/vrm/vrm_secondary.gd").springs_enabled=false
	preload("res://deathmatch/avatars/visual_loader.gd").compile_surfaces=true
	root.add_child(crowd)
	crowd.avatars=Avatars.new();crowd.add_child(crowd.avatars)
	crowd.avatars.library=preload("res://deathmatch/avatars/library.gd").new();crowd.avatars.add_child(crowd.avatars.library)
	for i in 32:
		var sample: String=["sample_d","sample_f","sample_g"][i%3]
		var hash:=FileAccess.get_sha256(crowd.avatars.library.Paths.folder("vrm")+sample+".vrm")
		crowd.avatars.choices[i]={"hash":hash};crowd.players[i]={}
		var holder:=Holder.new();holder.name="Avatar%02d"%i;crowd.add_child(holder);holder.rotation.y=PI;crowd.fighters[i]=holder
	var preparation:=Preparation.new()
	if not preparation.prepare(crowd):quit(1);return
	assert(preparation.report.avatars==32 and preparation.report.inactive_spring_systems==32)
	map=Map.new();root.add_child(map);map.build(true)
	var env:=WorldEnvironment.new();root.add_child(env);env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.53,.67,.75)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.48,.57,.7);env.environment.ambient_light_energy=.6
	capture=preload("res://tools/voxel_battle/stereo_capture.gd").new();capture.effect_callback_type=CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	var sun:=DirectionalLight3D.new();root.add_child(sun);sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.2;sun.shadow_enabled=false
	await physics_frame;await physics_frame
	point=choose_point()
	origin=XROrigin3D.new();root.add_child(origin);camera=XRCamera3D.new();origin.add_child(camera);camera.near=.08;camera.far=1000;camera.current=true
	desired_view=Transform3D(Basis.IDENTITY,Vector3(point.x,Landscape.surface(point.x,point.z+10).x+1.7,point.z+10))
	await process_frame;await physics_frame
	origin.global_transform=desired_view*camera.transform.affine_inverse()
	ready=true
	print("STEREO_SCENE_READY point=",point," views=",xr.get_view_count()," avatars=32 AI=0 springs=off")
	# Streaming, shader, avatar LOD and pose warmup never enter measured samples.
	var deadline:=Time.get_ticks_msec()+90000
	while not map.terrain.settled() or (root.get_node("AvatarMeshLOD").task>=0 or not root.get_node("AvatarMeshLOD").pending.is_empty()):
		if Time.get_ticks_msec()>deadline:push_error("Stereo warmup timed out");quit(1);return
		await process_frame
	for i in 180:await process_frame
	probe.setup(output,root.get_viewport_rid());measured=true
	while elapsed<duration:await process_frame
	measured=false
	var performance:=probe.result()
	var report:={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"xr_interface":xr.get_name(),"xr_system":xr.get_system_info(),"views":xr.get_view_count(),"per_eye_size":str(xr.get_render_target_size()),"seed":20261012,"random_point_m":[point.x,point.y,point.z],"avatars":32,"ai_nodes":0,"navigation_baked":false,"animation":"live idle, humanoid IK, expressions, conservative full-detail XR pose policy","springs_enabled":false,"avatar_prepass":preparation.report,"fixed_head_view":true,"display_refresh_hz":xr.get_display_refresh_rate(),"seconds":elapsed,"avatar_centers_in_frustum":Probe.summary(visibility),"performance":performance,"limits":"One random map location, standing animated crowd; real OpenXR pacing/tracking and runtime foveation settings. No combat, AI, network or avatar movement. Render workload, not headset encode/decode or motion-to-photon latency."}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	# Attach capture only after timings are finalized; no extra pass during the test.
	env.compositor=Compositor.new();env.compositor.compositor_effects=[capture]
	capture.requested=true
	for frame in 3:await RenderingServer.frame_post_draw
	var rd:=RenderingServer.get_rendering_device()
	for eye in capture.textures.size():
		var texture: RID=capture.textures[eye]
		var format:=rd.texture_get_format(texture)
		print("STEREO_TEXTURE eye=",eye," format=",format.format," size=",format.width,"x",format.height)
		var image_format:=Image.FORMAT_RGBAH if format.format==RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT else Image.FORMAT_RGBA8
		var frame:=Image.create_from_data(format.width,format.height,false,image_format,rd.texture_get_data(texture,0))
		frame.convert(Image.FORMAT_RGBA8);frame.save_png(output+("/left.png" if eye==0 else "/right.png"))
		if eye==0:
			frame.resize(960,1056);frame.save_jpg(output+"/preview.jpg",.85)
	capture.release()
	print("STEREO_RESULT ",JSON.stringify(report))
	if args.has("--keep-open"):return
	ready=false;quit()
