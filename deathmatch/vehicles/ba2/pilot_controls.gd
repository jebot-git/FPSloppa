extends RefCounted
## Grip-held manual override. Input loss requires a fresh grip before reacquiring.
const RADIUS:=.08
const DEADZONE:=.18 # Approximately 1.5 cm of relaxed hand movement.
var held: Array=[false,false]
var previous: Array=[true,true]
var starts: Array=[Vector3.ZERO,Vector3.ZERO]
var axes: Array=[Vector2.ZERO,Vector2.ZERO]
var life:=-1
func begin(serial: int) -> void:
 if life==serial:return
 life=serial;reset()
func reset() -> void:
 held=[false,false];previous=[true,true];axes=[Vector2.ZERO,Vector2.ZERO]
func sample(side: int,hand: Vector3,centre: Vector3,grip: bool,trigger: bool,valid: bool) -> Array:
 if not valid or not hand.is_finite():
  held[side]=false;previous[side]=true;axes[side]=Vector2.ZERO
  return [false,Vector2.ZERO,false]
 if not grip:held[side]=false
 elif not previous[side] and hand.distance_to(centre)<.23:
  held[side]=true;starts[side]=hand
 previous[side]=grip
 if hand.distance_to(centre)>.5:held[side]=false
 var planar: Vector2=Vector2(hand.x-starts[side].x,starts[side].z-hand.z)/RADIUS
 # Each stick has one axis; cross-axis hand movement cannot dilute input.
 planar=Vector2(planar.x,0) if side==0 else Vector2(0,planar.y)
 var length:=planar.length()
 axes[side]=planar.normalized()*clampf((length-DEADZONE)/(1.-DEADZONE),0,1) if held[side] and length>DEADZONE else Vector2.ZERO
 return [held[side],axes[side],held[side] and trigger]
static func validated(value: Variant) -> Array:
 if not value is Array or value.size()!=2:return []
 var result: Array=[]
 for side in 2:
  var row=value[side]
  if not row is Array or row.size()!=3 or not row[0] is bool or not row[1] is Vector2 or not row[1].is_finite() or not row[2] is bool:return []
  var axis:Vector2=Vector2(clampf(row[1].x,-1,1),0) if side==0 else Vector2(0,clampf(row[1].y,-1,1))
  result.append([row[0],axis if row[0] else Vector2.ZERO,row[0] and row[2]])
 return result
static func tilt(axis: Vector2) -> Quaternion:
 var angle: float=axis.limit_length().length()*deg_to_rad(24)
 var direction:=axis.normalized()
 return Quaternion(Vector3.UP,Vector3(direction.x*sin(angle),cos(angle),-direction.y*sin(angle)))
