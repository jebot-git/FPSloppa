extends SceneTree
const Poses=preload("res://deathmatch/vr/poses.gd")
const OSC=preload("res://deathmatch/vr/osc.gd")
const Visemes=preload("res://deathmatch/voice/visemes.gd")
class FakeRig extends Node3D:
	var origin:=Node3D.new()
	var focused:=true
	func _init() -> void: add_child(origin)
	func controller(label: String,tracker: String,pose: String) -> XRController3D:
		var node:=XRController3D.new();node.name=label;node.tracker=tracker;node.pose=pose;origin.add_child(node);return node
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func message(path: String,value: Vector3) -> PackedByteArray:
	var data:=PackedByteArray()
	for s in [path,",fff"]:
		data.append_array(s.to_ascii_buffer());data.append(0)
		while data.size()%4: data.append(0)
	var stream:=StreamPeerBuffer.new(); stream.big_endian=true
	stream.put_float(value.x);stream.put_float(value.y);stream.put_float(value.z)
	data.append_array(stream.data_array)
	return data
func run() -> void:
	var osc:=OSC.new()
	var packet:=message("/tracking/trackers/2/position",Vector3(.2,.1,.3))
	osc.parse(packet,1)
	check(osc.current(1.1).left_foot.origin.is_equal_approx(Vector3(.2,.1,-.3)),"SlimeVR OSC coordinate conversion")
	check(osc.current(1.3).is_empty(),"Stale Slime targets expire")
	var bundle:="#bundle".to_ascii_buffer();bundle.resize(16)
	var size:=StreamPeerBuffer.new();size.big_endian=true;size.put_u32(packet.size())
	bundle.append_array(size.data_array);bundle.append_array(packet);osc.parse(bundle,2)
	check(not osc.current(2).is_empty(),"OSC bundle decoding")
	osc.parse(message("/tracking/trackers/2/position",Vector3(NAN,0,0)),3)
	check(osc.current(3).is_empty(),"OSC rejects nonfinite values")
	osc.parse(bundle.slice(0,20),3)
	var pose:=Poses.neutral();pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.9,0)),"left_curls":PackedFloat32Array([0,.2,.4,.6,1])}
	check(Poses.validate(pose).body.size()==2,"Bounded body targets accepted")
	pose.body.hips.origin.x=100
	check(Poses.validate(pose).body.is_empty() and Poses.validate(pose).weapon==pose.weapon,"Bad cosmetic tracking discarded without changing legal aim")
	pose.body={"left_curls":PackedFloat32Array([NAN,0,0,0,0])}
	check(Poses.validate(pose).body.is_empty(),"Invalid finger curls rejected")
	var silence:=PackedVector2Array();silence.resize(320)
	check(Visemes.analyze(silence)==PackedFloat32Array([0,0,0,0,0]),"Silence closes mouth")
	var speech:=PackedVector2Array()
	for i in range(320): speech.append(Vector2.ONE*(sin(TAU*650*i/16000)*.15+sin(TAU*1400*i/16000)*.08))
	var weights:=Visemes.analyze(speech)
	check(weights[0]>.1 and weights[0]<1,"Speech produces bounded vowel weights")
	var quiet:=PackedVector2Array()
	for i in range(320):quiet.append(Vector2.ONE*sin(TAU*650*i/16000)*.03)
	var quiet_weights:=Visemes.analyze(quiet)
	check(quiet_weights[0]>.2 and quiet_weights[0]<weights[0],"Quiet speech has visible mouth movement below normal speech strength")
	var rig:=FakeRig.new();root.add_child(rig)
	var tracking=preload("res://deathmatch/vr/tracking.gd").new();rig.add_child(tracking);tracking.setup(rig)
	var vive:=XRPositionalTracker.new();vive.name="/user/vive_tracker_htcx/role/waist";vive.type=XRServer.TRACKER_CONTROLLER
	XRServer.add_tracker(vive)
	vive.set_pose("tracker_pose",Transform3D(Basis.IDENTITY,Vector3(0,.9,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	check(tracking.external().has("hips"),"Live Vive role pose ingestion")
	XRServer.remove_tracker(vive)
	var body:=XRBodyTracker.new();body.name="/user/body_tracker";body.has_tracking_data=true
	body.set_joint_transform(XRBodyTracker.JOINT_HIPS,Transform3D(Basis.IDENTITY,Vector3(0,.9,0)))
	body.set_joint_flags(XRBodyTracker.JOINT_HIPS,XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
	XRServer.add_tracker(body)
	check(tracking.sample().has("hips"),"Native XRBodyTracker joints reach avatar targets")
	body.has_tracking_data=false
	check(not tracking.sample().has("hips"),"Native tracking loss falls back")
	XRServer.remove_tracker(body)
	var hand:=XRHandTracker.new();hand.name="/user/hand_tracker/left";hand.has_tracking_data=true;hand.hand_tracking_source=XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
	hand.set_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST,Transform3D(Basis.IDENTITY,Vector3(-.3,1.2,-.3)))
	hand.set_hand_joint_flags(XRHandTracker.HAND_JOINT_WRIST,XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID|XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID)
	XRServer.add_tracker(hand)
	check(tracking.sample().has("left_hand") and tracking.sample().left_curls.size()==5,"Native optical wrist and finger path")
	hand.hand_tracking_source=XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
	check(not tracking.sample().has("left_hand") and tracking.sample().left_curls.size()==5,"Controller-inferred wrists preserve calibrated grip alignment")
	tracking.enabled=false
	check(tracking.sample().has("left_curls") and not tracking.sample().has("hips"),"Finger animation remains enabled independently of body tracking")
	tracking.enabled=true
	XRServer.remove_tracker(hand)
	tracking.osc.parse(message("/tracking/trackers/2/position",Vector3(.1,.1,.2)),Time.get_ticks_msec()*.001)
	tracking.calibrate()
	check(tracking.sample().get("left_foot",Transform3D.IDENTITY).origin.distance_to(Vector3(-.13,.08,0))<.001,"Slime target calibration")
	rig.free()
	var library=preload("res://deathmatch/avatars/library.gd").new();root.add_child(library)
	for hash in library.entries:
		var avatar=library.create_avatar(hash)
		var actor:=Node3D.new();root.add_child(actor);actor.add_child(avatar)
		for i in range(5): check(not avatar.mouth.binds[i].is_empty(),"VRM expression binding %s %d"%[library.entries[hash].title,i])
		avatar.mouth.speak(weights);avatar.mouth._process(.1)
		var bind: Array=avatar.mouth.binds[0][0]
		check(bind[0].get_blend_shape_value(bind[1])>0,"Mouth morph moves")
		for i in range(60):avatar.mouth._process(.02)
		check(bind[0].get_blend_shape_value(bind[1])<.001,"Mouth returns to rest after loss/silence")
		avatar.target_xr_pose=Poses.neutral();avatar.target_xr_pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.85,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.15,.2,-.2)),"chest":Transform3D(Basis(Vector3.UP,.3),Vector3(0,1.3,0))}
		avatar._process(.016);avatar.solver._process_modification_with_delta(.016)
		var finite:=true
		for i in range(avatar.skeleton.get_bone_count()): finite=finite and avatar.skeleton.get_bone_global_pose(i).is_finite()
		check(finite,"Tracked full-body IK remains finite")
		var foot_position: Vector3=avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(avatar.skeleton.find_bone("LeftFoot")).origin)
		check(foot_position.distance_to(Vector3(-.15,.2,-.2))<.08,"Tracked foot reaches its target")
		actor.free()
	library.free()
	var map=load("res://deathmatch/vr/actions.tres")
	check(map.find_interaction_profile("/interaction_profiles/htc/vive_tracker_htcx")!=null,"Vive tracker action bindings")
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.headless=false;game.spatial.setup(game)
	for kind in ["weapon_2","weapon_3","weapon_4","weapon_5","step","flesh","impact"]: check(game.spatial.choose(kind)!=null,"Recorded SFX "+kind)
	var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,2,1);shape.shape=box;wall.add_child(shape);wall.position=Vector3(300,1,300);root.add_child(wall)
	await physics_frame;await physics_frame
	check(game.spatial.occluded(Vector3(298,1,300),Vector3(302,1,300)),"Wall occludes spatial audio")
	check(not game.spatial.occluded(Vector3(298,4,300),Vector3(302,4,300)),"Clear path does not occlude")
	game.players[2]=game._new_state("Talker",2)
	var fighter=preload("res://deathmatch/fighter.gd").new();fighter.setup(2,"Talker",Color.WHITE);game.add_child(fighter);game.fighters[2]=fighter
	var mono:=PackedFloat32Array()
	for frame in speech: mono.append(frame.x)
	game.voice.set_process(false)
	game.voice.receive(2,1,preload("res://deathmatch/tests/opus_fixture.gd").packet(preload("res://deathmatch/tests/opus_fixture.gd").encoder()))
	check(game.voice.streams.has(2) and game.voice.streams[2].player is AudioStreamPlayer3D,"Received voice creates a positional audio source")
	await create_timer(.1).timeout # Steam Audio starts the inner generator on the mixer thread.
	game.clock+=.1;game.voice._process(.02)
	check(game.voice.streams[2].speaker.audio_stream_playback_opus!=null,"Received voice uses native Opus playback")
	game.voice.set_muted(2,true)
	check(not game.voice.streams.has(2),"Mute removes voice and pending visemes")
	wall.free();game.free()
	print("TRACKING_AUDIO_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
