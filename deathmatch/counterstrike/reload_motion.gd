extends RefCounted
## Measure fresh authority input samples. Common body translation is removed;
## duplicate packets, long gaps and tracking jumps cannot complete a gesture.
const MAX_GAP:=.16
const SCALE:=.65
static func sample(p: Dictionary,pose: Dictionary,weapon: Transform3D,hand: Transform3D,stamp: float) -> Dictionary:
	var current:={"time":stamp,"hand":weapon.affine_inverse()*hand.origin,"weapon":pose.weapon.origin-pose.head.origin,"support":hand.origin-pose.head.origin,"raw_weapon":pose.weapon.origin,"raw_support":hand.origin,"basis":pose.weapon.basis,"head_basis":pose.head.basis}
	var before: Dictionary=p.get("motion",{})
	if not before.is_empty() and stamp<=before.time:return {"valid":false,"duplicate":true}
	p.motion=current
	if before.is_empty():return {"valid":false}
	var dt: float=stamp-before.time
	var hand_step: Vector3=(current.hand-before.hand)*SCALE
	var weapon_step: Vector3=before.basis.inverse()*(current.weapon-before.weapon)
	var support_step: Vector3=before.basis.inverse()*(current.support-before.support)
	# Head motion alone must not look like a stationary hand flicking backwards.
	if current.raw_weapon.distance_to(before.raw_weapon)<weapon_step.length()*.35:weapon_step=Vector3.ZERO
	if current.raw_support.distance_to(before.raw_support)<support_step.length()*.35:support_step=Vector3.ZERO
	var valid: bool=dt>=.008 and dt<=MAX_GAP and hand_step.length()<.32 and weapon_step.length()<.32 and support_step.length()<.32
	if not valid:p.gestures={}
	var body_step: Vector3=before.head_basis.inverse()*before.basis*weapon_step
	return {"valid":valid,"dt":dt,"from":before.hand,"to":current.hand,"hand_step":hand_step,"weapon_step":weapon_step,"body_step":body_step,"support_step":support_step,"time":stamp}
static func side_flick(motion: Dictionary) -> bool:
	if not motion.get("valid",false):return false
	# Either lateral axis works, even with the pistol rolled or pointed up.
	var lateral:=maxf(absf(motion.weapon_step.x),absf(motion.body_step.x))
	return lateral>=.02 and lateral/motion.dt>=.65
static func swept(motion: Dictionary,point: Vector3,radius: float) -> bool:
	if not motion.get("valid",false):return false
	var segment: Vector3=motion.to-motion.from
	var along:=clampf((point-motion.from).dot(segment)/maxf(.00001,segment.length_squared()),0,1)
	return (motion.from+segment*along).distance_to(point)*SCALE<radius
static func slap(motion: Dictionary,point: Vector3,radius: float) -> bool:
	if not motion.get("valid",false) or motion.hand_step.length()<.022 or motion.support_step.length()/motion.dt<.50:return false
	if not swept(motion,point,radius):return false
	# Accept approach or pass-through, but not a hand simply withdrawing from
	# inside the forgiving palm-sized contact region.
	var segment: Vector3=motion.to-motion.from
	return (point-motion.from).dot(segment)>0
static func stroke(p: Dictionary,key: String,distance: float,motion: Dictionary,speed: float,travel: float) -> bool:
	if not motion.get("valid",false):return false
	if not p.has("gestures"):p.gestures={}
	var prior: Dictionary=p.gestures.get(key,{})
	if absf(distance)/motion.dt<speed:
		p.gestures.erase(key);return false
	if prior.is_empty() or motion.time-prior.time>MAX_GAP or signf(distance)!=signf(prior.distance):
		prior={"time":motion.time,"start":motion.time,"distance":0.0,"samples":0}
	prior.distance+=distance;prior.samples+=1;prior.time=motion.time
	if motion.time-prior.start>.24:prior.distance=distance;prior.samples=1;prior.start=motion.time
	p.gestures[key]=prior
	return prior.samples>=2 and absf(prior.distance)>=travel
