extends SceneTree
const Map=preload("res://tools/voxel_battle/map.gd")
const OUTPUT:="res://test-results/staged-jungle/stereo"
var map
var origin:XROrigin3D
var camera:XRCamera3D
var desired:=Transform3D.IDENTITY
var ready:=false
var effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new()
func _initialize()->void:run.call_deferred()
func _process(_delta:float)->bool:
	if not ready:return false
	var tracker=XRServer.get_tracker("head")
	if tracker:
		var pose=tracker.get_pose("default")
		if pose:origin.global_transform=desired*(XRServer.get_reference_frame()*pose.get_adjusted_transform()).affine_inverse()
	map.update_view(camera);return false
func run()->void:
	var xr=XRServer.find_interface("OpenXR")
	if not xr or not xr.is_initialized():push_error("OpenXR runtime unavailable");quit(1);return
	XRServer.primary_interface=xr;root.use_xr=true;root.msaa_3d=Viewport.MSAA_DISABLED
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var world:=WorldEnvironment.new();world.environment=Environment.new();root.add_child(world)
	map=Map.new();root.add_child(map);map.build(true,false);map.lighting.phase_override=0
	origin=XROrigin3D.new();root.add_child(origin);camera=XRCamera3D.new();origin.add_child(camera);camera.current=true;camera.far=2200
	var point:=Vector3(-1000,Map.Landscape.surface(-1000,-300).x+1.7,-300)
	desired=Transform3D(Basis.looking_at(Vector3(.8,-.08,-1)),point);ready=true
	world.compositor=Compositor.new();world.compositor.compositor_effects=[effect]
	var start:=Time.get_ticks_msec()
	while not map.terrain.settled():
		await process_frame
		if Time.get_ticks_msec()-start>90000:push_error("XR stream timeout");quit(1);return
	for name in ["standard","scout"]:
		effect.configure(6000,name=="scout",0,1);effect.enabled=true
		await create_timer(1).timeout
		var capture=preload("res://tools/voxel_battle/stereo_capture.gd").new();capture.effect_callback_type=CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT;world.compositor.compositor_effects=[effect,capture]
		capture.requested=true
		for frame in 3:await RenderingServer.frame_post_draw
		assert(capture.textures.size()==2,"NVG requires both native eye buffers")
		var rd:=RenderingServer.get_rendering_device()
		for eye in 2:
			var texture:RID=capture.textures[eye];var format:=rd.texture_get_format(texture)
			var image:=Image.create_from_data(format.width,format.height,false,Image.FORMAT_RGBA8,rd.texture_get_data(texture,0))
			assert(image.save_png(OUTPUT+"/"+name+("-left" if eye==0 else "-right")+".png")==OK)
		world.compositor.compositor_effects=[effect];RenderingServer.call_on_render_thread(capture.release)
		print("NVG_STEREO_CAPTURE ",name," ",xr.get_render_target_size())
	FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"xr_system":xr.get_system_info(),"views":xr.get_view_count(),"per_eye_size":str(xr.get_render_target_size()),"samples":["standard","scout"],"baked_only":true},"\t"))
	ready=false;map.terrain.shutdown();root.use_xr=false;xr.uninitialize();effect.enabled=false;RenderingServer.call_on_render_thread(effect.release);quit()
