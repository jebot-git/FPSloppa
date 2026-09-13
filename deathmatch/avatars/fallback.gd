extends Node3D
## The download/error fallback uses the same gait as a loaded VRM.
var gait=preload("res://deathmatch/avatars/locomotion.gd").new()
const Death=preload("res://deathmatch/avatars/death_pose.gd")
var dead:=false:
	set(value):
		if dead==value:return
		dead=value;death_time=0.0;death_start.clear()
		if dead and is_inside_tree():death_basis=get_parent().global_basis.orthonormalized()
		if not dead:gait=preload("res://deathmatch/avatars/locomotion.gd").new();rotation=Vector3.ZERO
var death_time:=0.0
var death_basis:=Basis.IDENTITY
var death_start:Dictionary={}
var arm_rest:Dictionary={}

func animate_death(delta:float) -> void:
	if is_inside_tree():global_basis=death_basis
	var settled:=death_time>=Death.SETTLE_TIME
	death_time=minf(death_time+delta,Death.VISIBLE_TIME)
	$Upper/WeaponModel.hide()
	if settled:return
	var parts:Array[Node3D]=[$Upper,$Upper/Head,$LeftThigh,$LeftShin,$LeftBoot,$RightThigh,$RightShin,$RightBoot,$Upper/LeftArm,$Upper/LeftForearm,$Upper/RightArm,$Upper/RightForearm]
	if death_start.is_empty():
		for part in parts:death_start[part]=part.transform
	var pose:=Death.sample(death_time,clampf(death_start[$Upper].origin.y,.22,.78))
	$Upper.transform=Transform3D(pose.basis,pose.pelvis)
	$Upper/Head.rotation=Vector3(.15,.30,-.22)*pose.release
	for side in ["Left","Right"]:
		var key:String=side.to_lower();var sign_side:=-1.0 if side=="Left" else 1.0
		var hip:Vector3=pose.pelvis+pose.basis*Vector3(sign_side*.18,0,0)
		var foot:=Vector3(sign_side*.18,.10,0).lerp(pose[key+"_foot"],pose.release)
		var knee:Vector3=hip.lerp(foot,.5).lerp(pose[key+"_knee"],pose.release)
		segment(get_node(side+"Thigh"),hip,knee);segment(get_node(side+"Shin"),knee,foot)
		get_node(side+"Boot").position=foot+Vector3(0,-.01,-.05)
		var inverse:Transform3D=$Upper.transform.affine_inverse()
		var elbow:Vector3=inverse*pose[key+"_elbow"]
		segment(get_node("Upper/"+side+"Arm"),Vector3(sign_side*.32,.45,0),elbow)
		segment(get_node("Upper/"+side+"Forearm"),elbow,inverse*pose[key+"_hand"])
	var blend:=smoothstep(0.0,.30,death_time)
	for part in parts:part.transform=death_start[part].interpolate_with(part.transform,blend)

func animate(delta: float,movement: Vector3,stance: String,height: float,grounded: bool,body: Dictionary,assist: bool) -> void:
	if dead:
		animate_death(delta)
		return
	if arm_rest.is_empty():
		for side in ["Left","Right"]:
			for part in ["Arm","Forearm"]:
				var node:=get_node("Upper/"+side+part);arm_rest[node]=node.transform
	for node in arm_rest:node.transform=arm_rest[node]
	$Upper.rotation=Vector3.ZERO
	$Upper/Head.rotation=Vector3.ZERO
	gait.update(delta,movement,stance,grounded,body,assist)
	var pelvis:=Vector3(0,.78-(1.65-height)+gait.bob,0)
	pelvis.y=maxf(.30,pelvis.y)-gait.landing*.25
	pelvis=pelvis.lerp(Vector3(0,.32,.30),gait.prone_blend)
	if body.has("hips"):pelvis=body.hips.origin
	$Upper.position=pelvis
	$Upper.rotation.x=-deg_to_rad(77)*gait.prone_blend
	$Upper/Head.rotation.x=-$Upper.rotation.x
	$Upper/WeaponModel.rotation.x=-$Upper.rotation.x
	$Upper/WeaponModel.position=$Upper.transform.affine_inverse()*Vector3(.20,lerpf(.91-1.65+height,.38,gait.prone_blend),lerpf(-.22,-.60,gait.prone_blend))
	for side in ["Left","Right"]:
		var sign_side:=-1.0 if side=="Left" else 1.0
		var key: String=side.to_lower()
		var hip:=pelvis+Vector3(sign_side*.18,0,0)
		var foot: Vector3=Vector3(sign_side*.18,.10,0)+gait.offsets[key]
		if body.has(key+"_foot"):foot=body[key+"_foot"].origin+gait.offsets[key]*gait.assist_weight*.6
		var axis: Vector3=(foot-hip).normalized()
		var distance:=clampf(hip.distance_to(foot),.02,.719)
		foot=hip+axis*distance
		var pole:=Vector3.FORWARD.lerp(Vector3.DOWN,gait.prone_blend)
		var bend: Vector3=(pole-axis*pole.dot(axis)).normalized()
		if bend.length_squared()<.1:bend=Vector3.FORWARD
		var knee: Vector3=(hip+foot)*.5+bend*sqrt(maxf(0,.36*.36-distance*distance*.25))
		segment(get_node(side+"Thigh"),hip,knee)
		segment(get_node(side+"Shin"),knee,foot)
		get_node(side+"Boot").position=foot+Vector3(0,-.01,-.05)

func segment(mesh: Node3D,from: Vector3,to: Vector3) -> void:
	mesh.position=(from+to)*.5
	mesh.quaternion=Quaternion(Vector3.UP,(to-from).normalized())
	mesh.scale=Vector3(1,from.distance_to(to),1)
