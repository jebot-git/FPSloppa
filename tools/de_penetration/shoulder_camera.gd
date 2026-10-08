extends RefCounted
## Persistent spectator smoothing, with a swept sphere protecting the near plane.
var followed:=0
var position:=Vector3.ZERO
var yaw:=0.
var pitch:=0.
var orientation:=Quaternion.IDENTITY
var ready:=false
var maximum_step:=0.
var frames:=0
var cuts:=0
var clearance_corrections:=0
var clearance_failures:=0
var materials: Array=[]
var sphere:=SphereShape3D.new()
func collision_position(game,eye: Vector3,wanted: Vector3) -> Vector3:
 sphere.radius=.22
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.collision_mask=1;query.margin=.07
 query.transform.origin=eye;query.motion=wanted-eye
 var space=game.get_world_3d().direct_space_state
 var sweep: PackedFloat32Array=space.cast_motion(query)
 var result: Vector3=wanted
 if not sweep.is_empty() and sweep[0]<1.:
  result=eye+(wanted-eye)*maxf(0,sweep[0]-.025);clearance_corrections+=1
 query.transform.origin=result;query.motion=Vector3.ZERO
 if not space.intersect_shape(query,1).is_empty():
  clearance_corrections+=1
  var ray:=PhysicsRayQueryParameters3D.create(eye,wanted,1);ray.hit_back_faces=true;ray.hit_from_inside=true
  var hit: Dictionary=space.intersect_ray(ray)
  result=eye if hit.is_empty() else eye+(hit.position-eye)*.8
  query.transform.origin=result
  if not space.intersect_shape(query,1).is_empty():result=eye;clearance_failures+=1
 return result
func update(game,delta: float):
 var alive: Array=[]
 for id in game.players:
  var state: Dictionary=game.players[id]
  if id<0 and not state.dead and not state.spectator and game.fighters.has(id):alive.append(id)
 if alive.is_empty():return
 if not alive.has(followed):
  followed=0
  for id in alive:
   if id==game.match_mode.defusal.carrier:followed=id;break
  if followed==0:
   for id in alive:
    if game.players[id].team==0:followed=id;break
  if followed==0:followed=alive[0]
  ready=false;cuts+=1
 for id in game.fighters:
  var fighter=game.fighters[id]
  if "label" in fighter and is_instance_valid(fighter.label):fighter.label.visible=id!=followed
 var actor=game.fighters[followed];var state: Dictionary=game.players[followed]
 var dt:=clampf(delta,0.,.1)
 var eye: Vector3=actor.render_position()+Vector3.UP*actor.eye_height()
 if ready and position.distance_to(eye)>12.:ready=false;cuts+=1
 if ready:
  yaw=lerp_angle(yaw,float(state.yaw),1-exp(-5*dt));pitch=lerpf(pitch,clampf(state.pitch,-.7,.7),1-exp(-4*dt))
 else:yaw=state.yaw;pitch=clampf(state.pitch,-.7,.7)
 var forward: Vector3=Basis(Vector3.UP,yaw)*Vector3.FORWARD
 var right: Vector3=forward.cross(Vector3.UP)
 var desired: Vector3=collision_position(game,eye,eye-forward*2.7+right*.6+Vector3.UP*.55)
 var candidate: Vector3=position.lerp(desired,1-exp(-9*dt)) if ready else desired
 candidate=collision_position(game,eye,candidate)
 if ready:maximum_step=maxf(maximum_step,position.distance_to(candidate))
 position=candidate
 var target: Vector3=eye+forward*9+Vector3.UP*sin(pitch)*9
 var goal:=Basis.looking_at((target-position).normalized()).get_rotation_quaternion()
 orientation=orientation.slerp(goal,1-exp(-9*dt)) if ready else goal
 game.camera.global_transform=Transform3D(Basis(orientation),position)
 game.camera.fov=74;game.camera.near=.08
 # Close corridors safely retract the camera; hide only the followed body when necessary.
 if position.distance_to(eye)<.85:actor.hide()
 ready=true;frames+=1
