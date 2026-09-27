extends RefCounted
## Fixed server limits shared by room-scale prediction and authoritative movement.
const DEADZONE:=.02
const MAX_OFFSET:=.75
const MAX_REQUEST:=.08 # At 30 input updates/sec: at most 2.4 m/s.
const Hip=preload("res://deathmatch/vr/hip_mount.gd")
static var head_shape: SphereShape3D
static func anchor(pose: Dictionary) -> Vector3:
	return pose.body.hips.origin if Hip.tracked(pose) else pose.head.origin
static func pose_request(pose: Dictionary) -> Vector3:
	return request(anchor(pose)) if not pose.is_empty() else Vector3.ZERO
static func request(head: Vector3) -> Vector3:
	var horizontal:=Vector3(head.x,0,head.z)
	if not head.is_finite() or horizontal.length()>MAX_OFFSET: return Vector3.ZERO
	return horizontal.normalized()*clampf(horizontal.length()-DEADZONE,0,MAX_REQUEST)
static func validate(value: Variant,pose: Dictionary) -> Vector3:
	if not value is Vector3 or not value.is_finite() or pose.is_empty(): return Vector3.ZERO
	var target:=pose_request(pose)
	return target.normalized()*clampf(value.dot(target.normalized()),0,target.length())
static func move_capsule(actor: CharacterBody3D,requested: Vector3,yaw: float,delta: float) -> Vector3:
	var turn:=Basis(Vector3.UP,yaw)
	var before:=actor.position
	actor.move_and_collide(turn*requested*minf(delta*30,1))
	return turn.inverse()*(actor.position-before)
static func rebase_pose(pose: Dictionary,shift: Vector3) -> void:
	for key in ["head","left","right","weapon"]:
		pose[key].origin-=shift
	if pose.has("offhand_weapon"): pose.offhand_weapon.origin-=shift
	for key in pose.get("body",{}):
		if pose.body[key] is Transform3D: pose.body[key].origin-=shift

static func head_blocked(actor: CharacterBody3D,pose: Dictionary,yaw: float) -> bool:
	if pose.is_empty():return true
	var head: Vector3=actor.global_position+Basis(Vector3.UP,yaw)*pose.head.origin
	var from: Vector3=actor.global_position+Vector3.UP*actor.torso_height()
	var space:=actor.get_world_3d().direct_space_state
	if not Hip.tracked(pose):
		return head.distance_to(from)>1.3 or not space.intersect_ray(PhysicsRayQueryParameters3D.create(from,head,1)).is_empty()
	# Sweep a head-sized volume across the lean, not the capsule: low rails
	# remain leanable, but a fast pose update cannot tunnel through a tall wall.
	# FPSloppa preserves physical tracking and uses its established wall fade,
	# instead of pushing the real headset back as raifslop's local motor does.
	from=Vector3(actor.global_position.x,head.y,actor.global_position.z)
	if head_shape==null:head_shape=SphereShape3D.new()
	head_shape.radius=minf(.12,maxf(.015,pose.head.origin.y*.8))
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=head_shape;query.collision_mask=1;query.exclude=[actor.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,head)
	if not space.intersect_shape(query,1).is_empty():return true
	query.transform.origin=from;query.motion=head-from
	if not space.intersect_shape(query,1).is_empty():return true
	return space.cast_motion(query)[0]<.999
