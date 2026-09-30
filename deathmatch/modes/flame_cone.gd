extends RefCounted
## Five deterministic samples; a target receives one dose, never five pellets.
const OFFSETS=[Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]
static func direction(basis:Basis,pellet:int,angle:float) -> Vector3:
 var offset:Vector2=OFFSETS[pellet%OFFSETS.size()]*tan(deg_to_rad(angle))
 return (-basis.z+basis.x*offset.x+basis.y*offset.y).normalized()
static func first_hit(seen:Dictionary,hit:Dictionary) -> bool:
 if not hit.get("hit",false):return true
 var key:=str([hit.get("id",0),hit.get("building",""),hit.get("map_node","")])
 if seen.has(key):return false
 seen[key]=true;return true
