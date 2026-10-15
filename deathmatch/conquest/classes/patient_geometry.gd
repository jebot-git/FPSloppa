extends RefCounted
## Centre line of the prone avatar, including its forward torso and head.
static func contact(at:Vector3,yaw:float,point:Vector3)->Vector3:
 var frame:=Basis(Vector3.UP,yaw)
 var local:Vector3=frame.inverse()*(point-at)
 return at+frame*Vector3(0,.35,clampf(local.z,-1.15,.30))
