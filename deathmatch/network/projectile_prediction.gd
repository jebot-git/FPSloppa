extends RefCounted
## Bounded cosmetic flight. Never enters the authoritative projectile collection.
const Hit=preload("res://deathmatch/hit_detection.gd")
const Shots=preload("res://deathmatch/network/shot_prediction.gd")
const TIMEOUT=.5
const LIMIT=32
var flights:Dictionary={}
static func eligible(d:Dictionary) -> bool:
 return float(d.get("speed",0))>0 and float(d.get("charge",0))==0 and int(d.get("pellets",1))==1 and not d.get("guided",false)
func add(game,identity:Array,definition:Dictionary,start:Vector3,direction:Vector3) -> void:
 if flights.size()>=LIMIT or not eligible(definition) or flights.has(Shots.key(identity)):return
 var visual:Dictionary=definition.duplicate()
 if not visual.has("kind"):visual.kind=preload("res://deathmatch/lighting/weapon_emission.gd").kind(game.armory.effective(),identity[4])
 var node:Node3D=game._weapon_visuals().projectile(game.armory.effective(),visual)
 node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
 game.add_child(node);node.position=start
 if absf(direction.dot(Vector3.UP))<.99:node.look_at(start+direction)
 flights[Shots.key(identity)]={"identity":identity,"node":node,"position":start,"velocity":direction*float(definition.speed),"gravity":float(definition.get("gravity",0)),"radius":float(definition.get("radius",.1)),"age":0.,"stopped":false}
func take(identity:Array) -> Dictionary:
 var key:=Shots.key(identity);var flight:Dictionary=flights.get(key,{})
 flights.erase(key)
 return flight
func discard(key:String) -> void:
 if is_instance_valid(flights[key].node):flights[key].node.queue_free()
 flights.erase(key)
func reset() -> void:
 for key in flights.keys():discard(key)
func step(game,delta:float,serial:int,weapon:int,blocked:bool,outcomes:Array) -> void:
 for key in flights.keys():
  var p:Dictionary=flights[key];p.age+=delta
  var rejected:=false
  for result in outcomes:
   if result[0]==p.identity[1] and result[2]&(1<<p.identity[3]) and result[1]!="fired":rejected=true
  if blocked or rejected or p.identity[0]!=serial or p.identity[4]!=weapon or p.age>=TIMEOUT:
   discard(key);continue
  if p.stopped:continue
  var dt:=minf(delta,.05)
  var end:Vector3=p.position+p.velocity*dt-Vector3.UP*p.gravity*dt*dt*.5
  var fraction:float=Hit.world_fraction(game.get_world_3d().direct_space_state,p.position,end,p.radius)
  p.position=p.position.lerp(end,minf(1.,fraction));p.velocity.y-=p.gravity*dt
  # Stop at cover without speculative bounces, damage, decals or explosions.
  p.stopped=is_finite(fraction) and fraction<=1.
  p.node.position=p.position
