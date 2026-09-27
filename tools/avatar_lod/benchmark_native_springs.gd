extends SceneTree
## Headless CPU comparison. Optional archived secondary script is test-only.
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
var rigs: Array=[]
var phase:=0
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
	for i in 60:await process_frame
	var times: Array=[];var last:=Time.get_ticks_usec()
	for i in 360:
		await process_frame
		var now:=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	times.sort()
	print("NATIVE_SPRING_BENCHMARK ",JSON.stringify({"variant":variant,"actors":8,"frames":360,"median_ms":times[180],"p95_ms":times[341],"engine":Engine.get_version_info().string,"scope":"Headless CPU, fixed 90 FPS simulation delta, uncapped wall time; no rendering/network/XR hardware"}))
	rigs.clear();world.free();library.free();quit()
