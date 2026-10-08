extends RefCounted
## Smooth small ground-route corrections, without delaying stops or evasive input.
var samples:=0
var raw_turn:=0.
var smooth_turn:=0.
static func filtered(before: Vector3,wish: Vector3,delta: float) -> Vector3:
 if wish.length_squared()<.0001 or before.length_squared()<.0001 or before.dot(wish)<=0:return wish
 return before.lerp(wish,1-exp(-14*clampf(delta,0,.1))).limit_length(wish.length())
func apply(ai,id: int,brain: Dictionary,delta: float,previous_yaw: float):
 if not ai.game.match_mode.defusal.enabled():return
 var actor=ai.game.fighters[id];var s: Dictionary=ai.game.players[id]
 var wish: Vector3=Basis(Vector3.UP,s.yaw)*Vector3(s.move.x,0,s.move.y)
 var before: Vector3=brain.get("travel_smoothed",wish)
 var eligible: bool=brain.enemy==0 and not brain.get("wallbang_tracking",false) and actor.is_supported() and not actor.in_water and not s.jump and ai.game.clock>=brain.recover_until and ai.game.clock>=brain.dodge_until and ai.game.clock>=brain.pad_until and ai.game.clock>=brain.drop_until and brain.lift_link.is_empty()
 var result: Vector3=filtered(before,wish,delta) if eligible else wish
 if eligible and not result.is_zero_approx() and not result.is_equal_approx(wish):
  var ahead: Vector3=actor.position+result.normalized()*.8
  var floor: Dictionary=ai.navigation.ray(ahead+Vector3.UP*.6,ahead-Vector3.UP*2)
  if floor.is_empty() or floor.normal.y<.65 or ai.navigation.hazardous(floor.position) or not ai.navigation.ray(actor.position+Vector3.UP*.9,ahead+Vector3.UP*.9).is_empty():result=wish
 if eligible and wish.length()>.1 and before.length()>.1:
  var previous_raw: Vector3=brain.get("travel_raw",wish)
  if previous_raw.length()>.1:raw_turn+=previous_raw.angle_to(wish);smooth_turn+=before.angle_to(result);samples+=1
 brain.travel_smoothed=result;brain.travel_raw=wish
 if eligible and result.length()>.1:s.yaw=lerp_angle(previous_yaw,atan2(-result.x,-result.z),1-exp(-8*delta))
 var local: Vector3=Basis(Vector3.UP,-s.yaw)*result
 s.move=Vector2(local.x,local.z)
