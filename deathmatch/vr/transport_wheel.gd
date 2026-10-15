extends RefCounted
## Local wheel interaction feeds the existing, validated native vehicle inputs.
const Geometry=preload("res://deathmatch/conquest/classes/transport_geometry.gd")
const MAX_ANGLE:=deg_to_rad(135.)
const GRAB_DISTANCE:=.085
var rig
var key:=-1
var angle:=0.
var previous_yaw:=0.
var hands:Array=[{},{}]
var pressed_before:Array=[true,true]
func setup(value)->void:rig=value
func driver_key()->int:
 if not rig or not rig.game.active:return -1
 var service=rig.game.battery_tanks
 var id:int=rig.game.multiplayer.get_unique_id()
 var result:int=service.key_for(id)
 if result<0:return -1
 var row:Dictionary=service.rows[result]
 return result if row.kind=="transport" and row.hp>0 and row.pilot==id else -1
func reset()->void:
 key=-1;angle=0.;hands=[{},{}];pressed_before=[true,true]
func frame()->Transform3D:
 var service=rig.game.battery_tanks;var row:Dictionary=service.view_row(key)
 return Transform3D(service.visual_basis(row),service.visual_origin(row))*Geometry.wheel_mount()
static func grip_point(local:Vector3)->Vector3:
 var radial:=Vector2(local.x,local.y)
 if radial.length_squared()<.000001:return Vector3(Geometry.WHEEL_RADIUS,0,0)
 radial=radial.normalized()*Geometry.WHEEL_RADIUS
 return Vector3(radial.x,radial.y,0)
static func throttle(axis:float)->float:
 return signf(axis)*clampf((absf(axis)-.18)/.82,0.,1.)
func physical_enabled()->bool:return rig.game.bindings.physical_transport_steering
func command()->Vector2:
 if not physical_enabled():return Vector2.ZERO
 if key<0 or driver_key()!=key or not rig.focused or rig.game.menu_open or rig.scores:return Vector2.ZERO
 var held:=false
 for i in 2:
  var hand=rig.left if i==0 else rig.right
  held=held or (not hands[i].is_empty() and (rig.simulated or hand.get_has_tracking_data()) and hand.get_float("grip")>.6)
 if not held:return Vector2.ZERO
 var weapon=rig.left if rig.left_handed else rig.right
 # OpenXR's positive stick Y is up; native forward movement uses negative Z.
 return Vector2(-angle/MAX_ANGLE,-throttle(weapon.get_vector2("primary").y) if rig.simulated or weapon.get_has_tracking_data() else 0.)
func update(delta:float)->void:
 var current:=driver_key()
 if current<0:
  reset();return
 var service=rig.game.battery_tanks;var row:Dictionary=service.view_row(current)
 var entering:bool=current!=key
 if entering:
  reset();key=current
  # Face the cabin on boarding, then follow chassis yaw without suppressing head rotation.
  previous_yaw=rig.head.global_basis.get_euler().y
 var turn:float=wrapf(row.yaw-previous_yaw,-PI,PI)
 previous_yaw=row.yaw
 if absf(turn)>.000001:
  var eye:Vector3=rig.head.global_position
  rig.game.local_yaw=wrapf(rig.game.local_yaw+turn,-PI,PI)
  rig.global_basis=Basis(Vector3.UP,rig.game.local_yaw)
  rig.global_position+=eye-rig.head.global_position
 var wheel_frame:=frame()
 var usable:bool=rig.focused and not rig.game.menu_open and not rig.scores and not rig.game.local_state().get("dead",true)
 var movement:=0.;var count:=0
 for i in 2:
  var controller=rig.left if i==0 else rig.right
  var tracked:bool=rig.simulated or controller.get_has_tracking_data()
  var pressed:bool=tracked and controller.get_float("grip")>.6
  var local:Vector3=wheel_frame.affine_inverse()*controller.global_position
  var raw_angle:float=atan2(local.y,local.x)
  if not usable or not physical_enabled() or not pressed:hands[i]={}
  elif hands[i].is_empty() and not pressed_before[i] and local.distance_to(grip_point(local))<=GRAB_DISTANCE:
   hands[i]={"anchor":raw_angle-angle,"previous":raw_angle,"basis":Basis(Vector3.BACK,-angle)*wheel_frame.basis.inverse()*controller.global_basis,"radial_valid":true}
   if not rig.simulated:controller.trigger_haptic_pulse("haptic",0.,.35,.045,0.)
  if not hands[i].is_empty():
   var radial_valid:bool=Vector2(local.x,local.y).length()>.07
   if radial_valid and hands[i].radial_valid:
    movement+=wrapf(raw_angle-hands[i].previous,-PI,PI);count+=1
   hands[i].previous=raw_angle;hands[i].radial_valid=radial_valid
  pressed_before[i]=pressed if usable and tracked and physical_enabled() else true
 if count>0:angle=clampf(angle+movement/count,-MAX_ANGLE,MAX_ANGLE)
 elif hands[0].is_empty() and hands[1].is_empty():angle=move_toward(angle,0.,4.*minf(delta,.05))
 var wheel:Node3D=service.models[key].get_node_or_null("SteeringWheelMount/Wheel") if service.models.has(key) else null
 if wheel:wheel.rotation.z=angle
 for i in 2:
  var controller=rig.left if i==0 else rig.right
  var model:Node3D=rig.hand_models[i]
  model.visible=usable and (rig.simulated or controller.get_has_tracking_data())
  if hands[i].is_empty():
   model.global_transform=controller.global_transform
  else:
   var at:float=hands[i].anchor+angle
   var basis:Basis=wheel_frame.basis*Basis(Vector3.BACK,angle)*hands[i].basis
   model.global_transform=Transform3D(basis,wheel_frame*Vector3(cos(at)*Geometry.WHEEL_RADIUS,sin(at)*Geometry.WHEEL_RADIUS,0))
   rig.hand_animators[i].curls=PackedFloat32Array([.8,.85,.95,.95,.95])
