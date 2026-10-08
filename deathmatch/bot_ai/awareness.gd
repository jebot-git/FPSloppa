extends RefCounted
## DE damage supplies a direction cue, never a hidden enemy position or fire permission.
var sightings: Dictionary={}
func visible(ai,id: int,other: int) -> bool:
 var game=ai.game;var origin: Vector3=ai.eye(id);var actor=game.fighters[other]
 if game.match_mode.defusal.utility.flash_amount(id)>.35:return false
 var torso: Vector3=ai.target_position(other)
 var side: Vector3=(torso-origin).cross(Vector3.UP).normalized()*.22
 for point in [torso,ai.eye(other),torso+side,torso-side]:
  if game.match_mode.defusal.utility.obscured(origin,point):continue
  # Teammates can block the shot without making the opponent invisible.
  # Actual firing keeps the existing separate friendly-fire lane check.
  if game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point,1)).is_empty():
   if not sightings.has(id):sightings[id]={}
   sightings[id][other]=point-actor.position
   return true
 return false
func observed(ai,id: int,brain: Dictionary):
 if ai.game.match_mode.kind!="de":return
 if brain.enemy!=0 and sightings.get(id,{}).has(brain.enemy):brain.exposed_offset=sightings[id][brain.enemy]
 sightings.erase(id)
func damaged(ai,victim: int,attacker: int,direction: Vector3):
 var game=ai.game
 if game.match_mode.kind!="de" or victim>=0 or victim==attacker or not ai.alive(victim) or not game.players.has(attacker) or game.match_mode.same_team(victim,attacker):return
 var bearing: Vector3=-direction; bearing.y=0
 if bearing.length_squared()<.01:return
 var state: Dictionary=game.players[victim]
 state.bot_hurt_direction=bearing.normalized();state.bot_hurt_until=game.clock+1.1;state.bot_hurt_serial=state.serial;state.bot_hurt_at=game.clock
 if ai.brains.has(victim):ai.brains[victim].next=game.clock;ai.brains[victim].plan_at=0.
func before(ai,id: int,brain: Dictionary,delta: float):
 brain.hurt_tracking=false
 var game=ai.game;var state: Dictionary=game.players[id]
 if game.match_mode.kind!="de" or state.get("bot_hurt_serial",-1)!=state.serial or float(state.get("bot_hurt_until",0))<=game.clock:return
 if float(brain.get("hurt_processed",-1))!=float(state.bot_hurt_at):
  brain.hurt_processed=state.bot_hurt_at;brain.next=game.clock;brain.plan_at=0.
 if brain.enemy!=0:return
 var bearing: Vector3=state.bot_hurt_direction
 state.yaw=lerp_angle(state.yaw,atan2(-bearing.x,-bearing.z),1-exp(-8*delta))
 brain.hurt_tracking=true
