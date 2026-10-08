extends RefCounted
## Short suppression at a last observed position. Never query a hidden enemy pose.
const Penetration=preload("res://deathmatch/counterstrike/penetration.gd")
var attempts:=0
var firing_ticks:=0
func lane(ai,id: int,point: Vector3,weapon: int) -> bool:
 var game=ai.game
 var runtime=game.get_node_or_null("Map/MapRuntime")
 if runtime==null or not runtime.ballistics.ready or not Penetration.WEAPONS.has(weapon):return false
 var origin: Vector3=ai.eye(id);var offset: Vector3=point-origin;var distance:=offset.length()
 if distance<.1:return false
 var direction:=offset/distance;var profile: Array=Penetration.WEAPONS[weapon]
 if distance>minf(float(profile[2]),float(game.armory.data(weapon).range)):return false
 # Protect the whole firing lane, including teammates behind penetrable cover.
 for friend in game.players:
  if friend==id or not ai.alive(friend) or not game.match_mode.same_team(id,friend):continue
  var body: Vector3=ai.target_position(friend);var along: float=(body-origin).dot(direction)
  if along>0 and along<distance+1 and body.distance_to(origin+direction*along)<.85:return false
 var range_end: Vector3=origin+direction*float(game.armory.data(weapon).range)
 var space=game.get_world_3d().direct_space_state;var current:=origin;var power: float=profile[1]/32.;var layers:=0
 for step in int(profile[0])+1:
  var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(current,point,1))
  if hit.is_empty():return layers>0
  if step==int(profile[0]) or not runtime.ballistics.map_root.is_ancestor_of(hit.collider):return false
  var passage: Dictionary=runtime.ballistics.exit_surface(hit.position,direction,power,space)
  if passage.is_empty():return false
  current=passage.position;power-=passage.cost;layers+=1
  range_end=current+direction*(current.distance_to(range_end)*.5)
  if (range_end-point).dot(direction)<0:return false
 return false
func apply(ai,id: int,brain: Dictionary,delta: float) -> void:
 brain.wallbang_tracking=false
 var game=ai.game
 if not game.match_mode.defusal.enabled() or game.armory.effective()!="cs16":return
 var s: Dictionary=game.players[id]
 if game.match_mode.defusal.combat_blocked(id) or game.match_mode.defusal.utility.flash_amount(id)>.35:return
 var age: float=game.clock-brain.last_seen_at
 if age<0 or age>.65 or brain.remembered_enemy==0:return
 # Stored feet and a fixed torso offset avoid live hidden-target position/stance.
 var point: Vector3=brain.seen_position+Vector3.UP*1.05
 var hit: Dictionary=ai.navigation.ray(ai.eye(id),point)
 if hit.is_empty():return
 s.fire=false;s.alt_fire=false
 if not Penetration.WEAPONS.has(s.weapon) or game.clock<brain.seen_at+brain.reaction:return
 if game.clock>=float(brain.get("wallbang_check_at",-1)):
  brain.wallbang_check_at=game.clock+.15
  brain.wallbang_lane=lane(ai,id,point,s.weapon)
  brain.wallbang_weapon=s.weapon;brain.wallbang_origin=ai.eye(id);brain.wallbang_point=point;attempts+=1
 if not brain.get("wallbang_lane",false) or brain.get("wallbang_weapon",-1)!=s.weapon:return
 if ai.eye(id).distance_to(brain.wallbang_origin)>.3 or point.distance_to(brain.wallbang_point)>.3:return
 # Check teammate safety every frame even while geometry probes are throttled.
 for friend in game.players:
  if friend==id or not ai.alive(friend) or not game.match_mode.same_team(id,friend):continue
  var closest: Vector3=Geometry3D.get_closest_point_to_segment(ai.target_position(friend),ai.eye(id),point)
  if closest.distance_to(ai.target_position(friend))<.85:return
 brain.wallbang_tracking=true
 var aim_point: Vector3=brain.aiming.point(ai.eye(id),point,game.clock,game.fighters[id].velocity.length())
 s.fire=ai.aim(id,aim_point,1-exp(-brain.aiming.response*delta))
 if s.fire:firing_ticks+=1
