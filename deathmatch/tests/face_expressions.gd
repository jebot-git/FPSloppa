extends SceneTree
const Expressions=preload("res://deathmatch/vr/face_expressions.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
class FakeRig extends Node3D:
	var head:=Node3D.new()
	var focused:=true
	var game={"bindings":preload("res://deathmatch/settings/bindings.gd").new()}
	func _init():add_child(head)
	func controller(label: String,tracker: String,pose: String) -> XRController3D:
		var node:=XRController3D.new();node.name=label;node.tracker=tracker;node.pose=pose;add_child(node);return node
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var neutral:=PackedFloat32Array([0,0,0,0,0])
	check(Expressions.classify(0,0,0,0,0,0,0)==neutral,"Neutral or absent face data does not invent an expression")
	var samples: Array=[Expressions.classify(.9,0,0,0,0,0,0),Expressions.classify(0,0,.9,0,0,0,0),Expressions.classify(0,.8,0,.7,0,0,0),Expressions.classify(.4,0,0,0,0,0,0),Expressions.classify(0,0,0,.8,.8,.9,.6)]
	for i in 5:
		check(samples[i][i]>.2 and samples[i].count(0.0)==4,"Facial cues select only preset %d"%i)
	check(Expressions.classify(0,0,0,0,0,0,.9)==neutral,"Speaking with jaw open alone does not trigger surprise")
	var face_data: Dictionary={"look":Vector2.ZERO,"blink":Vector2(.6,.4),"gaze":true,"lids":true,"expression":PackedFloat32Array([2,1,0,0,0])}
	var safe:=Poses.validate_face(face_data)
	check(is_equal_approx(safe.expression[0],.5) and is_equal_approx(safe.expression[1],.5),"Replicated expression weights are bounded and normalized")
	face_data.expression=PackedFloat32Array([NAN,0,0,0,0]);check(Poses.validate_face(face_data).is_empty(),"Nonfinite expression data rejected")
	face_data.expression=PackedFloat32Array([1,0]);check(Poses.validate_face(face_data).is_empty(),"Incomplete expression payload rejected")
	var rig:=FakeRig.new();root.add_child(rig);var eyes=preload("res://deathmatch/vr/eyes.gd").new();rig.add_child(eyes);eyes.setup(rig)
	check(eyes.sample().is_empty(),"Unsupported headset has no expression or eye data")
	var tracker:=XRFaceTracker.new();tracker.name="/user/face_tracker";XRServer.add_tracker(tracker)
	tracker.set_blend_shape(XRFaceTracker.FT_MOUTH_CORNER_PULL_LEFT,.9);tracker.set_blend_shape(XRFaceTracker.FT_MOUTH_CORNER_PULL_RIGHT,.9)
	tracker.set_blend_shape(XRFaceTracker.FT_EYE_CLOSED_LEFT,.5)
	check(eyes.sample().expression[0]>.5 and eyes.sample().blink.x==.5,"Native tracker supplies happy approximation alongside measured blink")
	rig.game.bindings.face_expressions=false;check(not eyes.sample().has("expression") and eyes.sample().lids,"Disabling expressions preserves measured eyes")
	rig.focused=false;check(eyes.sample().is_empty(),"Tracking focus loss stops expression transmission")
	XRServer.remove_tracker(tracker);rig.free()
	var library=preload("res://deathmatch/avatars/library.gd").new();root.add_child(library)
	var bundled: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json")).map(func(row):return row.hash)
	var available:=0
	for hash in library.entries:
		if not hash in bundled:continue
		var parent:=Node3D.new();root.add_child(parent);var avatar=library.create_avatar(hash);parent.add_child(avatar)
		var count:=0
		for i in range(7,12):
			if not avatar.eyes.binds[i].is_empty():count+=1
		available+=count
		check(count>0,"Bundled VRM declares expression presets: "+library.entries[hash].title)
		avatar.xr_pose=Poses.neutral();avatar.xr_pose.face={"look":Vector2.ZERO,"blink":Vector2.ZERO,"gaze":false,"lids":false,"expression":samples[0]}
		avatar.eyes._process_modification_with_delta(.05)
		check(avatar.eyes.expression_weights[0]>0 and avatar.eyes.expression_weights[0]<.65,"Expression transitions are smoothed and conservative")
		if not avatar.eyes.binds[7].is_empty():
			var bind: Array=avatar.eyes.binds[7][0]
			check(bind[0].get_blend_shape_value(bind[1])>0,"Declared happy/joy morph is visibly driven")
		# Exercise an overlapping VRM bind: smile, speech and blink must share one writer.
		if not avatar.mouth.binds[0].is_empty():
			var shared: Array=avatar.mouth.binds[0][0];var saved: Array=avatar.eyes.binds[7]
			avatar.eyes.binds[7]=[shared];avatar.eyes._process_modification_with_delta(.1)
			var expression_only: float=shared[0].get_blend_shape_value(shared[1]);avatar.mouth.speak(PackedFloat32Array([.3,0,0,0,0]));avatar.mouth._process(.02)
			check(shared[0].get_blend_shape_value(shared[1])>expression_only and shared[0].get_blend_shape_value(shared[1])<=.9991,"Overlapping speech and expression morphs compose without overwriting")
			avatar.eyes.binds[7]=saved
		avatar.xr_pose.clear();avatar.eyes._process_modification_with_delta(1)
		check(avatar.eyes.expression_weights==neutral,"Expression returns to neutral when tracking disappears")
		parent.free()
	check(available>0,"Optional expression support exists in shipped avatars")
	library.free();print("FACE_EXPRESSIONS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
