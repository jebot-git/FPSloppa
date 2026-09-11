extends SceneTree
var failures: Array=[]
var completions:=0
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	var rig=preload("res://deathmatch/vr/rig.gd").new();g.xr_rig=rig;g.add_child(rig);rig.setup(g,true);rig.set_process(false);rig.seated=false
	var owns_bus:=AudioServer.get_bus_index("ArenaEffects")<0
	if owns_bus:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"ArenaEffects")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("ArenaEffects"),true)
	rig.recenter();rig.left.position=Vector3(-.6,1.4,0);rig.right.position=Vector3(.6,1.4,0)
	rig.tracking.calibration_completed.connect(func():completions+=1)
	for i in 100:rig._process(.02)
	check(completions==0 and not rig.tracking.full_body_available(),"Real rig does not calibrate T-pose with controllers alone")
	var native:=XRBodyTracker.new();native.name="/user/body_tracker";native.has_tracking_data=true
	for pair in [[XRBodyTracker.JOINT_HIPS,Vector3(0,.92,0)],[XRBodyTracker.JOINT_LEFT_FOOT,Vector3(-.13,.08,0)],[XRBodyTracker.JOINT_RIGHT_FOOT,Vector3(.13,.08,0)]]:
		native.set_joint_transform(pair[0],Transform3D(Basis.IDENTITY,pair[1]));native.set_joint_flags(pair[0],XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
	XRServer.add_tracker(native)
	check(rig.tracking.full_body_available(),"Native hip and two foot poses satisfy full-body availability")
	for i in 100:rig._process(.02)
	check(completions==1 and rig.tracking.calibrated,"Full rig T-pose invokes native calibration automatically")
	check(is_instance_valid(rig.calibration_sound) and rig.calibration_sound.playing and rig.calibration_sound.stream.get_length()<.6,"Successful calibration plays the short local completion jingle")
	for i in 300:rig._process(.02)
	check(completions==1,"Holding the same pose never loops the jingle")
	XRServer.remove_tracker(native)
	var now: float=Time.get_ticks_msec()*.001
	for pair in [["hips",Vector3(0,.92,0)],["left_foot",Vector3(-.13,.08,0)],["right_foot",Vector3(.13,.08,0)],["left_elbow",Vector3(-.42,1.35,0)],["right_elbow",Vector3(.42,1.35,0)]]:
		rig.tracking.osc.samples[pair[0]]={"position":pair[1],"basis":Basis.IDENTITY,"time":now,"rotation_time":now}
	check(rig.tracking.full_body_available(),"Uncalibrated fresh OSC hip and feet also permit auto calibration")
	rig.tracking.calibrate(true)
	check(absf(rig.tracking.sample().left_elbow.origin.y-1.35)<.01,"T-pose calibration maps external elbows at shoulder height")
	rig.tracking.enabled=false;check(not rig.tracking.full_body_available(),"Disabled body tracking cannot auto calibrate")
	rig.calibration_sound.stop();await create_timer(.5).timeout
	g.free()
	if owns_bus:AudioServer.remove_bus(AudioServer.get_bus_index("ArenaEffects"))
	print("AUTO_CALIBRATION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
