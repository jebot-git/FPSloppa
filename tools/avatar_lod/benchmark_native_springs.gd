extends SceneTree
## Headless CPU comparison. Optional scripted reference is test-only.
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
var rigs: Array=[]
var phase:=0
var engine_steps:=0
func _initialize():run.call_deferred()
func _process(_delta: float) -> bool:
	phase+=1
	for i in rigs.size():
		var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
		pose.head.basis=Basis(Vector3.UP,sin((phase+i*19)*.015)*.4)
		pose.head.origin.x=sin((phase+i*7)*.02)*.08
		rigs[i].target_xr_pose=pose
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var variant:=args[0] if not args.is_empty() else "native"
	var legacy: Script=load(args[1]) if variant=="legacy" and args.size()>1 else null
	VRMSecondary.springs_enabled=true
	Engine.max_fps=0
	var world:=Node3D.new();root.add_child(world)
	var library:=Library.new()
	for sample in ["sample_d","sample_f","sample_g"]:library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
	for i in 8:
		var actor:=Node3D.new();world.add_child(actor);actor.position.x=i*2
		var rig=Loader.create_avatar(library,["sample_d","sample_f","sample_g"][i%3])
		if legacy:
			for secondary in rig.secondary_nodes:
				var path: NodePath=secondary.skeleton;var springs: Array=secondary.spring_bones
				secondary.set_script(legacy);secondary.skeleton=path;secondary.spring_bones=springs
		actor.add_child(rig);rig.preview_mode=0;rig.secondary_motion_enabled=variant!="off"
		rigs.append(rig)
		for secondary in rig.secondary_nodes:
			if secondary.native_simulator:
				assert(secondary.native_simulator.get_script()==null)
				secondary.native_simulator.modification_processed.connect(func():engine_steps+=1)
	for i in 60:await process_frame
	engine_steps=0
	var times: Array=[];var last:=Time.get_ticks_usec()
	for i in 360:
		await process_frame
		var now:=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	var active:=0;var chains:=0;var script_steps:=0
	for rig in rigs:
		for secondary in rig.secondary_nodes:
			chains+=secondary.spring_chain_count()
			if secondary.native_simulator and secondary.native_simulator.active:active+=1
			script_steps+=secondary.animation_ticks
	assert(engine_steps>0 and active==8 if variant=="native" else engine_steps==0)
	assert(script_steps>0 if variant=="legacy" else script_steps==0)
	times.sort()
	print("NATIVE_SPRING_BENCHMARK ",JSON.stringify({"variant":variant,"actors":8,"frames":360,"active_native_simulators":active,"native_steps":engine_steps,"script_steps":script_steps,"chains":chains,"median_ms":times[180],"p95_ms":times[341],"engine":Engine.get_version_info().string,"scope":"Headless CPU, fixed 90 FPS simulation delta, uncapped wall time; no rendering/network/XR hardware"}))
	rigs.clear();world.free();library.free();quit()
