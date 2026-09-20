extends SceneTree
## Same geometry and LOD in both phases. Full tracking versus head/hands only.
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
const Metrics=preload("res://deathmatch/avatars/animation_metrics.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var rigs: Array=[]
var output:="/tmp/avatar-animation"
var map_name:="near"
var tracked:=16
var clock:=0.0
func _initialize() -> void:run.call_deferred()
func _process(delta: float) -> bool:
	clock+=delta
	for i in rigs.size():
		var t:=clock+float(i)*.37
		var pose:=Poses.neutral()
		pose.head.basis=Basis(Vector3.UP,sin(t*.6)*.15)
		pose.head.origin+=Vector3(sin(t)*.025,sin(t*2)*.035,0)
		pose.left.origin+=Vector3(0,sin(t*2)*.05,sin(t)*.07)
		pose.right.origin+=Vector3(0,cos(t*2)*.05,cos(t)*.07)
		pose.weapon=pose.right
		if i<tracked:
			pose.body={"hips":Transform3D(Basis(Vector3.UP,sin(t)*.08),Vector3(0,.92+sin(t*2)*.025,0)),"chest":Transform3D(Basis(Vector3.RIGHT,sin(t)*.06),Vector3(0,1.2,0)),"left_curls":PackedFloat32Array([.3,.4,.6,.7,.8]),"right_curls":PackedFloat32Array([.4,.5,.7,.8,.9])}
			for side in ["left","right"]:
				var sign_side:=-1.0 if side=="left" else 1.0
				pose.body[side+"_foot"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.13,.08+maxf(0,sin(t*3*sign_side))*.06,sin(t*3*sign_side)*.13))
				pose.body[side+"_knee"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.16,.5,-.2))
				pose.body[side+"_elbow"]=Transform3D(Basis.IDENTITY,Vector3(sign_side*.5,.95,.02))
				pose.body[side+"_hand"]=pose[side]
			pose.face={"look":Vector2(sin(t)*.1,cos(t)*.08),"blink":Vector2.ONE*maxf(0,sin(t*1.7))*.7,"gaze":true,"lids":true,"expression":PackedFloat32Array([maxf(0,sin(t*.6))*.4,0,0,0,0])}
		rigs[i].target_xr_pose=pose
		# Voice is independent of tracker ownership; half of ALL actors speak.
		if i%2==0:rigs[i].mouth.speak(PackedFloat32Array([.2+sin(t*5)*.15,.1,0,0,0]))
	return false
func summary(values: Array) -> Dictionary:
	values.sort();var total:=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"p95":values[ceili(values.size()*.95)-1],"p99":values[ceili(values.size()*.99)-1]}
func measure(optimized: bool,springs: bool=true) -> Dictionary:
	Metrics.enabled=false
	for rig in rigs:rig.animation_optimized=optimized;rig.secondary_motion_enabled=springs
	await create_timer(2).timeout
	for frame in 90:await process_frame
	Metrics.reset();Metrics.enabled=true
	for rig in rigs:
		rig.eyes.morph_writes=0
		for secondary in rig.secondary_nodes:secondary.animation_usec=0;secondary.animation_ticks=0;secondary.animation_resets=0
	var wall: Array=[];var gpu: Array=[];var cpu: Array=[];var last:=Time.get_ticks_usec()
	for frame in 360:
		await process_frame
		var now:=Time.get_ticks_usec();wall.append((now-last)/1000.0);last=now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	Metrics.enabled=false
	var timings: Dictionary={}
	for key in Metrics.samples:timings[key]={"ms_per_frame":Metrics.samples[key][0]/360000.0,"calls_per_frame":Metrics.samples[key][1]/360.0}
	var spring_usec:=0;var spring_ticks:=0;var resets:=0;var writes:=0;var sleeping:=0;var tiers: Dictionary={}
	var joints:=0;var pairs:=0
	for rig in rigs:
		writes+=rig.eyes.morph_writes
		if rig.animation_sleeping:sleeping+=1
		var tier: String=str(rig.distance_lod.tier);tiers[tier]=int(tiers.get(tier,0))+1
		for secondary in rig.secondary_nodes:
			spring_usec+=secondary.animation_usec;spring_ticks+=secondary.animation_ticks;resets+=secondary.animation_resets
			for spring in secondary.spring_bones_internal:
				joints+=spring.verlets.size();pairs+=spring.verlets.size()*(mini(4,spring.colliders.size()) if spring.simplified else spring.colliders.size())
	timings.spring={"ms_per_frame":spring_usec/360000.0,"ticks_per_frame":spring_ticks/360.0,"resets":resets,"resident_joints":joints,"resident_potential_pairs":pairs}
	return {"optimized":optimized,"secondary_enabled":springs,"full_tracking":tracked,"head_hands_only":32-tracked,"frames":360,"wall_ms":summary(wall),"gpu_ms":summary(gpu),"render_cpu_ms":summary(cpu),"scripts":timings,"morph_writes_per_frame":writes/360.0,"sleeping":sleeping,"tiers":tiers}
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>0:output=args[0]
	if args.size()>1:map_name=args[1]
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.position=Vector3(0,2.2,3.5);camera.fov=90
	var environment:=WorldEnvironment.new();world.add_child(environment);environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.03,.04,.06)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-25,0)
	var positions: Array[Vector3]=[]
	if map_name=="qsrc_dm6":
		light.free();positions=await preload("res://tools/avatar_lod/dm6_scene.gd").setup(self,world,camera,32)
		if positions.size()!=32:quit(2);return
	var library:=Library.new()
	for name_here in ["sample_d","sample_f","sample_g"]:library.entries[name_here]={"path":"res://vrm/"+name_here+".vrm"}
	for index in 32:
		var actor:=Node3D.new();world.add_child(actor);actor.position=Vector3((index%8-3.5)*.55,0,-floori(index/8.0)*.65)
		if not positions.is_empty():actor.position=positions[index]
		var rig=Loader.create_avatar(library,["sample_d","sample_f","sample_g"][index%3]);actor.add_child(rig)
		rig.set_weapon(2,"ut99");rig.speed=4;rig.movement=Vector3(0,0,-4);rig.gait.phase=index/32.0;rig.enable_distance_lod();rigs.append(rig)
	var reports: Array=[]
	for full_count in [16,23]:
		tracked=full_count
		var phases: Array=[[false,true],[true,true],[true,false]]
		if full_count==23:phases.reverse()
		for phase in phases:
			var enabled: bool=phase[0];var springs: bool=phase[1]
			var result:=await measure(enabled,springs);reports.append(result);print("ANIMATION_PHASE ",JSON.stringify(result))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"-%d-%s.png"%[full_count,"no-springs" if not springs else "optimized" if enabled else "baseline"])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+".png")
	var report:={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"map":map_name,"actors":32,"reports":reports,"scope":"1440x900 Vulkan Mobile, vsync off, same geometry/LOD throughout. 16/32 and 23/32 full body/eye/face tracking; others head/hands VR. Half speaking independently. Three shared VRMs, asynchronous motion, 360 measured frames after warmup. Synthetic render-only test, no network/gameplay/XR hardware. Nested morph time is included in eyes; aggregate script timings do not include engine skeleton/skinning cost. 23/32 rounds the 70% case up to 71.875%."}
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	rigs.clear();world.free();library.free();quit()
