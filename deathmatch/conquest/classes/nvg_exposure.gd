extends RefCounted
## Shared angular exposure policy. Transient flashes never request full-screen whiteout.
const LAMP_OUTER:=deg_to_rad(2.5)
const LAMP_INNER:=deg_to_rad(.6)
const SUN_OUTER:=deg_to_rad(1.0)
const SUN_INNER:=deg_to_rad(.25)
const MAX_SPOTS:=12
static func alignment(forward:Vector3,direction:Vector3,sun:bool=false)->float:
 if direction.length_squared()<.000001:return 0.
 return smoothstep(cos(SUN_OUTER if sun else LAMP_OUTER),cos(SUN_INNER if sun else LAMP_INNER),forward.normalized().dot(direction.normalized()))
static func noise(daylight:float,scout:bool)->float:
 return lerpf(.012 if scout else .045,.18 if scout else .65,smoothstep(.05,.9,clampf(daylight,0.,1.)))
static func spot(position:Vector3,size:float,strength:float,eye:Transform3D)->PackedFloat32Array:
 var local:Vector3=eye.affine_inverse()*position
 if local.z>=-.01 or local.length_squared()<.000001:return PackedFloat32Array()
 var angle:float=clampf(atan(maxf(.01,size)/local.length()),.004,.35)
 var direction:=local.normalized()
 return PackedFloat32Array([direction.x,direction.y,direction.z,cos(angle),cos(angle*.25),clampf(strength,0.,1.),0.,0.])
