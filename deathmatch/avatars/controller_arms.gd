extends RefCounted
## Constrained head/neck + two-bone arms; torso sockets follow vertex animation.
## Only headset and controller poses are consumed. No body/finger tracking.
const MIN_ELBOW_BEND:=15.0
const MAX_ELBOW_BEND:=145.0
const MAX_SHOULDER_CONE:=125.0
const MAX_HEAD_TRANSLATION:=.065
static func vec(data:Array) -> Vector3:return Vector3(data[0],data[1],data[2])
static func socket(profile:Dictionary,frames:Vector3,index:int) -> Vector3:
	var a:Array=profile.sockets[clampi(int(frames.x),0,profile.sockets.size()-1)]
	var b:Array=profile.sockets[clampi(int(frames.y),0,profile.sockets.size()-1)]
	return Vector3(a[index],a[index+1],a[index+2]).lerp(Vector3(b[index],b[index+1],b[index+2]),clampf(frames.z,0,1))
static func cone(axis:Vector3,center:Vector3,limit:float) -> Vector3:
	axis=axis.normalized()
	var angle:=acos(clampf(center.dot(axis),-1,1))
	if angle<=limit:return axis
	var tangent:=axis-center*axis.dot(center)
	if tangent.length_squared()<.000001:tangent=Vector3.FORWARD
	return center*cos(limit)+tangent.normalized()*sin(limit)
static func transform_between(rest_start:Vector3,rest_end:Vector3,start:Vector3,end:Vector3) -> Transform3D:
	var q:=Quaternion((rest_end-rest_start).normalized(),(end-start).normalized())
	return Transform3D(Basis(q),start-q*rest_start)
static func solve_arm(points:Array,shoulder:Vector3,target:Vector3,side:String) -> Dictionary:
	var rest_shoulder:=vec(points[0]);var rest_elbow:=vec(points[1]);var rest_hand:=vec(points[2])
	var upper:=rest_shoulder.distance_to(rest_elbow);var fore:=rest_elbow.distance_to(rest_hand)
	# Avoid shoulder reversal through the back and deep hand penetration into chest.
	target.z=minf(target.z,shoulder.z+.12)
	target.x=minf(target.x,.20) if side=="left" else maxf(target.x,-.20)
	if absf(target.x)<.22 and target.y>.92 and target.y<1.52:target.z=minf(target.z,-.22)
	var displacement:=target-shoulder
	var axis:=cone(displacement.normalized() if displacement.length_squared()>.000001 else Vector3.DOWN,Vector3.DOWN,deg_to_rad(MAX_SHOULDER_CONE))
	var min_reach:=sqrt(upper*upper+fore*fore+2*upper*fore*cos(deg_to_rad(MAX_ELBOW_BEND)))
	var max_reach:=sqrt(upper*upper+fore*fore+2*upper*fore*cos(deg_to_rad(MIN_ELBOW_BEND)))
	var reach:=clampf(displacement.length(),min_reach,max_reach)
	var hand:=shoulder+axis*reach
	var pole:=Vector3(-1 if side=="left" else 1,-.35,.25)
	var bend:=pole-axis*pole.dot(axis)
	if bend.length_squared()<.000001:bend=Vector3.DOWN-axis*Vector3.DOWN.dot(axis)
	if bend.length_squared()<.000001:bend=Vector3.FORWARD
	bend=bend.normalized()
	var along:=(upper*upper-fore*fore+reach*reach)/(2*reach)
	var elbow:=shoulder+axis*along+bend*sqrt(maxf(0,upper*upper-along*along))
	return {"upper":transform_between(rest_shoulder,rest_elbow,shoulder,elbow),"fore":transform_between(rest_elbow,rest_hand,elbow,hand),"shoulder":shoulder,"elbow":elbow,"hand":hand,"target":target,"clamped":hand.distance_to(target)>.001,"upper_length":upper,"fore_length":fore}
static func solve_head(profile:Dictionary,neck:Vector3,head:Transform3D) -> Dictionary:
	var rest_neck:=vec(profile.neck);var rest_head:=vec(profile.head);var rest_eye:=vec(profile.eye)
	var angles:=head.basis.get_euler()
	angles.x=clampf(angles.x,deg_to_rad(-50),deg_to_rad(50))
	angles.y=clampf(angles.y,deg_to_rad(-75),deg_to_rad(75))
	angles.z=clampf(angles.z,deg_to_rad(-25),deg_to_rad(25))
	var rotation:=Basis.from_euler(angles)
	if profile.has("head_correction"):
		var q:Array=profile.head_correction
		rotation=rotation*Basis(Quaternion(q[0],q[1],q[2],q[3]))
	var shift:Vector3=(head.origin-Vector3(0,1.65,0)).limit_length(MAX_HEAD_TRANSLATION)
	var desired_eye:=neck+(rest_eye-rest_neck)+shift
	var desired_pivot:=desired_eye-rotation*(rest_eye-rest_head)
	var direction:=cone(desired_pivot-neck,Vector3.UP,deg_to_rad(40))
	var pivot:=neck+direction*rest_neck.distance_to(rest_head)
	var neck_transform:=transform_between(rest_neck,rest_head,neck,pivot)
	var head_transform:=Transform3D(rotation,pivot-rotation*rest_head)
	return {"neck":neck_transform,"head":head_transform,"neck_root":neck,"head_pivot":pivot,"eye":head_transform*rest_eye,"angles":angles}
static func write_transform(mesh:MeshInstance3D,name:String,value:Transform3D) -> void:
	var q:=value.basis.get_rotation_quaternion()
	mesh.set_instance_shader_parameter(name+"_q",Vector4(q.x,q.y,q.z,q.w))
	mesh.set_instance_shader_parameter(name+"_t",value.origin)
static func update(mesh:MeshInstance3D,profile:Dictionary,pose:Dictionary,frames:Vector3=Vector3.ZERO) -> bool:
	var head_active:=profile.has("sockets") and pose.has("head")
	var arms_active:bool=head_active and pose.has("left") and pose.has("right")
	mesh.set_instance_shader_parameter("tracked_arms",arms_active)
	mesh.set_instance_shader_parameter("tracked_head",head_active)
	if not head_active:return false
	var head_result:=solve_head(profile,socket(profile,frames,6),pose.head)
	write_transform(mesh,"neck",head_result.neck);write_transform(mesh,"head",head_result.head)
	if not arms_active:return false
	# Relative hand-to-head displacement maps controllers to the native model eye.
	# Head translation is bounded independently; it never moves shoulder anchors.
	var rest_eye:=vec(profile.eye)
	for side in ["left","right"]:
		var shoulder:=socket(profile,frames,0 if side=="left" else 3)
		var desired:Vector3=head_result.eye+pose[side].origin-pose.head.origin
		var solved:=solve_arm(profile[side],shoulder,desired,side)
		write_transform(mesh,side+"_upper",solved.upper);write_transform(mesh,side+"_fore",solved.fore)
	return true
