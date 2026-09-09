extends RefCounted
# OpenXR supplies controller-inferred Index joints and optical/streamed hand joints
# through the same tracker. Missing joints fall back per finger, never per hand.
const FINGERS=[[2,3,4,5],[7,8,9,10],[12,13,14,15],[17,18,19,20],[22,23,24,25]]
const THUMB_INPUTS=["ax_touch","by_touch","primary_touch","secondary_touch","thumbrest_touch","ax_button","by_button","primary_click","secondary_click"]
static func controller_curls(controller: XRController3D) -> PackedFloat32Array:
	if not is_instance_valid(controller): return PackedFloat32Array([0,0,0,0,0])
	var thumb:=false
	for action in THUMB_INPUTS: thumb=thumb or controller.is_button_pressed(action)
	var grip:=clampf(maxf(controller.get_float("grip"),float(controller.is_button_pressed("grip_click"))),0,1)
	var trigger:=clampf(maxf(controller.get_float("trigger"),float(controller.is_button_pressed("trigger_click"))),0,1)
	if controller.is_button_pressed("trigger_touch"): trigger=maxf(trigger,.15)
	return PackedFloat32Array([.85 if thumb else 0.0,trigger,grip,grip,grip])

static func sample(controller: XRController3D,hand: XRHandTracker=null) -> PackedFloat32Array:
	var curls:=controller_curls(controller)
	if not hand or not hand.has_tracking_data: return curls
	for finger in range(5):
		var points: Array[Vector3]=[]
		for joint in FINGERS[finger]:
			if not hand.get_hand_joint_flags(joint)&XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID: break
			var point:=hand.get_hand_joint_transform(joint).origin
			if not point.is_finite(): break
			points.append(point)
		if points.size()!=4: continue
		var a:=points[1]-points[0]
		var b:=points[3]-points[2]
		if a.length()>.001 and b.length()>.001: curls[finger]=clampf(a.angle_to(b)/2.4,0,1)
	return curls
