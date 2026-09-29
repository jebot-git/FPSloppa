extends "res://tools/avatar_lod/benchmark_animation.gd"
## Read-only performance experiment. No gameplay settings are saved.
const Clips=preload("res://deathmatch/avatars/lod_clips.gd")
func run() -> void:
	output="res://test-results/frametime-study/avatars"
	DirAccess.make_dir_recursive_absolute("res://test-results/frametime-study")
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.position=Vector3(0,1.5,0);camera.fov=85
	var xr_camera:=XRCamera3D.new();world.add_child(xr_camera);xr_camera.position=camera.position;camera.make_current()
	var environment:=WorldEnvironment.new();world.add_child(environment);environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.03,.04,.06)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-25,0)
	var library:=Library.new()
	for sample in ["sample_d","sample_f","sample_g"]:library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
	tracked=8
	for index in 16:
		var actor:=Node3D.new();world.add_child(actor)
		var rig=Loader.create_avatar(library,["sample_d","sample_f","sample_g"][index%3]);actor.add_child(rig)
		rig.set_weapon(2,"ut99");rig.speed=4;rig.movement=Vector3(0,0,-4);rig.gait.phase=index/16.0;rig.enable_distance_lod();rigs.append(rig)
	var reports: Array=[]
	for scenario in ["near","desktop_far","xr_policy_far","xr_policy_far","desktop_far","near"]:
		if scenario=="xr_policy_far":xr_camera.make_current()
		else:camera.make_current()
		for index in rigs.size():rigs[index].get_parent().position=Vector3((index%8-3.5)*.65,0,-(4.0 if scenario=="near" else 28.0)-floori(index/8.0)*.8)
		var result: Dictionary=await measure(true,false)
		result.scenario=scenario;result.actors=16;result.head_hands_only=8;reports.append(result)
		print("FRAMETIME_PHASE ",JSON.stringify(result))
	# Measure a cold clip's complete synchronous work directly, outside frame totals.
	var bakes: Array=[]
	for index in 3:
		for direction in 8:
			var rig=rigs[index]
			var description:={"key":"run"+str(direction),"state":"run","direction":direction}
			var before:=Time.get_ticks_usec();var clip:=Clips.bake(rig,description)
			bakes.append({"model":rig.avatar_hash,"direction":direction,"bones":rig.skeleton.get_bone_count(),"ms":(Time.get_ticks_usec()-before)/1000.0,"tracks":clip.get_track_count()})
	var report:={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"frames_per_block":360,"reports":reports,"cold_clip_bakes":bakes,"scope":"16 avatars, three shared VRMs, eight full-body/face and eight head/hands, half speaking; springs disabled. Reversed scenario order. XR policy is a synthetic XRCamera3D without headset/runtime, NOT VR rendering or headset timing. No map, networking, audio or gameplay. Script scopes are nested; render CPU is rendering only. Uncontrolled OS/GPU clocks."}
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FRAMETIME_STUDY_DONE")
	rigs.clear();world.free();library.free();quit()
