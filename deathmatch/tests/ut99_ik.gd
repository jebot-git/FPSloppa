extends SceneTree
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const IK=preload("res://deathmatch/avatars/controller_arms.gd")
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
var cases:=0
func _initialize() -> void:
	for model in ["soldier","commando","sgirl","fcommando","boss"]:
		validate_model("res://deathmatch/avatars/models/base/"+model+".utavatar")
	print("UT99_IK_RESULT ",JSON.stringify({"failures":failures,"arm_cases":cases,"models":5}));quit(0 if failures.is_empty() else 1)
func validate_model(path:String) -> void:
	print("MODEL ",path)
	var decoded:=Format.read(path)
	if decoded.has("error"):push_error(decoded.error);quit(1);return
	var p:Dictionary=decoded.manifest.ik_profile
	var lengths_ok:=true;var bends_ok:=true;var finite_ok:=true;var anchors_ok:=true
	var targets:=[Vector3.ZERO,Vector3(0,1.1,-.2),Vector3(-.6,1.9,-.6),Vector3(.6,1.9,-.6),Vector3(0,5,0),Vector3(0,-5,0),Vector3(4,1,4),Vector3(-4,1,-4)]
	for frame in decoded.manifest.frames:
		for side in ["left","right"]:
			var root:=IK.socket(p,Vector3(frame,frame,0),0 if side=="left" else 3)
			for target in targets+[root]:
				cases+=1
				var r:=IK.solve_arm(p[side],root,target,side)
				lengths_ok=lengths_ok and absf(r.shoulder.distance_to(r.elbow)-r.upper_length)<.00001 and absf(r.elbow.distance_to(r.hand)-r.fore_length)<.00001
				var dot:float=(r.elbow-r.shoulder).normalized().dot((r.hand-r.elbow).normalized())
				var angle:=rad_to_deg(acos(clampf(dot,-1,1)))
				bends_ok=bends_ok and angle>=IK.MIN_ELBOW_BEND-.01 and angle<=IK.MAX_ELBOW_BEND+.01
				finite_ok=finite_ok and r.upper.is_finite() and r.fore.is_finite()
				anchors_ok=anchors_ok and (r.upper*IK.vec(p[side][0])).distance_to(root)<.00001 and (r.fore*IK.vec(p[side][1])).distance_to(r.elbow)<.00001
	check(lengths_ok,"Arm lengths are invariant over extreme targets and every animated socket")
	check(bends_ok,"Elbow bend remains within 15–145 degrees without hyperextension")
	check(finite_ok,"Coincident, unreachable and pole-aligned targets never produce nonfinite transforms")
	check(anchors_ok,"Shoulders remain attached to animated torso sockets; forearms attach to elbows")
	var neck_ok:=true;var head_ok:=true
	for frame in [25,60,137,283,343,525]:
		for target in targets:
			var neck:=IK.socket(p,Vector3(frame,frame,0),6)
			var h:=Transform3D(Basis.from_euler(Vector3(1.4,2.2,1)),target)
			var r:=IK.solve_head(p,neck,h)
			neck_ok=neck_ok and absf(r.neck_root.distance_to(r.head_pivot)-IK.vec(p.neck).distance_to(IK.vec(p.head)))<.00001
			head_ok=head_ok and r.head.is_finite() and absf(r.angles.x)<=deg_to_rad(50)+.00001 and absf(r.angles.y)<=deg_to_rad(75)+.00001 and absf(r.angles.z)<=deg_to_rad(25)+.00001
	check(neck_ok,"Neck IK keeps native segment length through crouch, run and death sockets")
	check(head_ok,"Head orientation respects 50° pitch, 75° yaw and 25° roll bounds")
	var counts:={0:0,1:0,2:0,3:0}
	for w in decoded.manifest.ik_weights:counts[int(w[0])]+=1
	check(counts[1]>40 and counts[2]>40 and counts[3]>40,"Complete left/right arms and head/neck regions replace sparse capsule masks")
