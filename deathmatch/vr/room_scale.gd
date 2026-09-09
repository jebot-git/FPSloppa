extends RefCounted
## Fixed server limits shared by room-scale prediction and authoritative movement.
const DEADZONE:=.02
const MAX_OFFSET:=.75
const MAX_REQUEST:=.08 # At 30 input updates/sec: at most 2.4 m/s.
static func request(head: Vector3) -> Vector3:
	var horizontal:=Vector3(head.x,0,head.z)
	if not head.is_finite() or horizontal.length()>MAX_OFFSET: return Vector3.ZERO
	return horizontal.normalized()*clampf(horizontal.length()-DEADZONE,0,MAX_REQUEST)
static func validate(value: Variant,pose: Dictionary) -> Vector3:
	if not value is Vector3 or not value.is_finite() or pose.is_empty(): return Vector3.ZERO
	var target:=request(pose.head.origin)
	return target.normalized()*clampf(value.dot(target.normalized()),0,target.length())
static func move_capsule(actor: CharacterBody3D,requested: Vector3,yaw: float,delta: float) -> Vector3:
	var turn:=Basis(Vector3.UP,yaw)
	var before:=actor.position
	actor.move_and_collide(turn*requested*minf(delta*30,1))
	return turn.inverse()*(actor.position-before)
static func rebase_pose(pose: Dictionary,shift: Vector3) -> void:
	for key in ["head","left","right","weapon"]:
		pose[key].origin-=shift
	for key in pose.get("body",{}):
		if pose.body[key] is Transform3D: pose.body[key].origin-=shift
