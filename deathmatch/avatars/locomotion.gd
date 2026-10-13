extends RefCounted
## Continuous eight-direction procedural gait, independent of render/physics rate.
const DIRECTIONS=["forward","forward_right","right","back_right","back","back_left","left","forward_left"]
var phase:=0.0
var direction:=Vector3.FORWARD
var direction_name:="forward"
var gait_name:="idle"
var amount:=0.0
var stance_blend:=0.0
var prone_blend:=0.0
var air_blend:=0.0
var air_lift:=0.0
var landing:=0.0
var was_grounded:=true
var offsets: Dictionary={"left":Vector3.ZERO,"right":Vector3.ZERO}
var bob:=0.0

func update(delta: float,movement: Vector3,stance: String,grounded: bool,_body: Dictionary,_assist: bool) -> void:
	delta=clampf(delta,0,.1)
	var flat:=Vector3(movement.x,0,movement.z)
	var speed:=flat.length()
	var moving:=speed>.15
	if moving:
		var wanted:=flat.normalized()
		var angle:=lerp_angle(atan2(direction.x,-direction.z),atan2(wanted.x,-wanted.z),1-exp(-16*delta))
		direction=Vector3(sin(angle),0,-cos(angle))
		direction_name=DIRECTIONS[posmod(roundi(atan2(direction.x,-direction.z)/(PI/4)),8)]
	amount=move_toward(amount,minf(speed/3.0,1.0) if grounded else 0.0,delta*7)
	stance_blend=move_toward(stance_blend,1.0 if stance=="crouch" else 0.0,delta*6)
	prone_blend=move_toward(prone_blend,1.0 if stance=="prone" else 0.0,delta*5)
	air_blend=move_toward(air_blend,0.0 if grounded else 1.0,delta*9)
	air_lift=move_toward(air_lift,.30 if movement.y>0 else .07,delta*1.8)
	if grounded and not was_grounded:landing=.16
	else:landing=maxf(0,landing-delta)
	was_grounded=grounded
	var run:=clampf((speed-5.2)/4.2,0,1)
	var rate:=lerpf(1.15,2.05,run)
	if stance=="prone":rate=.8*clampf(speed/1.5,.3,1)
	elif stance=="crouch":rate=1.15*clampf(speed/3.0,.3,1)
	if moving and grounded:phase=fmod(phase+delta*rate,1.0)
	gait_name=("jump" if movement.y>0 else "fall") if not grounded else stance if stance!="stand" else "idle" if not moving else "run" if run>.25 else "walk"
	bob=(absf(sin(phase*TAU))*lerpf(.018,.030,run)-run*.08)*amount*(1-prone_blend)
	for side in ["left","right"]:
		var t:=fmod(phase+(.5 if side=="right" else 0),1.0)
		# Longer planted phase, shorter curved swing; right and left alternate.
		var swing:=maxf(0,(t-.6)/.4)
		var travel:=1.0-2.0*t/.6 if t<.6 else -cos(swing*PI)
		var stride:=lerpf(.28,.40,run)*lerpf(1.0,.6,stance_blend)*lerpf(1.0,.42,prone_blend)
		var offset:=direction*travel*stride*amount
		# Lateral shuffle never crosses one foot through the other.
		var sign_side:=-1.0 if side=="left" else 1.0
		offset.x=sign_side*maxf(-.04,sign_side*offset.x)
		offset.y=sin(swing*PI)*lerpf(.11,.23,run)*amount*lerpf(1.0,.35,prone_blend)
		offset+=Vector3(sign_side*.04,air_lift,.15 if movement.y>0 else .05)*air_blend
		offset.z+=1.15*prone_blend
		offset.x+=sign_side*.10*prone_blend
		offsets[side]=offset
