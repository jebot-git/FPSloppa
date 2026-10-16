extends RefCounted
## Local wheel interaction feeds the existing, validated native vehicle inputs.
const Bike=preload("res://deathmatch/conquest/classes/bike_geometry.gd")
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
 return result if row.kind in ["transport","bike"] and row.hp>0 and row.pilot==id else -1
func reset()->void:
 key=-1;angle=0.;hands=[{},{}];pressed_before=[true,true]
func is_bike()->bool:return key>=0 and rig.game.battery_tanks.rows.get(key,{}).get("kind","")=="bike"
func maximum_angle()->float:return deg_to_rad(35.) if is_bike() else MAX_ANGLE
func rotation_axis()->Vector3:return Vector3.UP if is_bike() else Vector3.BACK
func nearest_grip(local:Vector3)->Vector3:
 if is_bike():return Bike.grip(0 if local.x<0 else 1)
 return grip_point(local)
func grab_contact(local:Vector3)->bool:
 var grip:=nearest_grip(local)
 # A rearward capsule is reachable from the seated rider without moving the
 # displayed hand off the actual handle once attached.
 return local.distance_to(Geometry3D.get_closest_point_to_segment(local,grip,grip+Vector3.BACK*.20))<=.13 if is_bike() else local.distance_to(grip)<=GRAB_DISTANCE
func hand_angle(local:Vector3)->float:return atan2(-local.z,local.x) if is_bike() else atan2(local.y,local.x)
func frame()->Transform3D:
 var service=rig.game.battery_tanks;var row:Dictionary=service.view_row(key)
 return Transform3D(service.visual_basis(row),service.visual_origin(row))*(Bike.steering_mount() if is_bike() else Geometry.wheel_mount())
static func grip_point(local:Vector3)->Vector3:
 var radial:=Vector2(local.x,local.y)
 if radial.length_squared()<.000001:return Vector3(Geometry.WHEEL_RADIUS,0,0)
 radial=radial.normalized()*Geometry.WHEEL_RADIUS
 return Vector3(radial.x,radial.y,0)
static func throttle(axis:float)->float:
 return signf(axis)*clampf((absf(axis)-.18)/.82,0.,1.)
func physical_enabled()->bool:return is_bike() or rig.game.bindings.physical_transport_steering
func headlights_pressed()->bool:
 if key<0 or driver_key()!=key or not rig.focused or rig.game.menu_open or rig.scores:return false
 var hand=rig.left if rig.left_handed else rig.right
 return (rig.simulated or hand.get_has_tracking_data()) and hand.is_button_pressed("primary_click")
func command()->Vector2:
 if not physical_enabled():return Vector2.ZERO
 if key<0 or driver_key()!=key or not rig.focused or rig.game.menu_open or rig.scores:return Vector2.ZERO
 var held:=false
 for i in 2:
  var hand=rig.left if i==0 else rig.right
  held=held or (not hands[i].is_empty() and (rig.simulated or hand.get_has_tracking_data()) and hand.get_float("grip")>.6)
 if not held:return Vector2.ZERO
 var weapon=rig.left if rig.left_handed else rig.right
 var support=rig.right if rig.left_handed else rig.left
 var accelerate:float=throttle(weapon.get_float("trigger")) if rig.simulated or weapon.get_has_tracking_data() else 0.
 var brake:float=throttle(support.get_float("trigger")) if rig.simulated or support.get_has_tracking_data() else 0.
 # Positive travel input brakes/reverses. Brake has priority if both are held.
 return Vector2(-angle/maximum_angle(),brake if brake>0. else -accelerate)
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
  var raw_angle:float=hand_angle(local)
  if not usable or not physical_enabled() or not pressed:hands[i]={}
  elif hands[i].is_empty() and not pressed_before[i] and grab_contact(local):
   hands[i]={"anchor":raw_angle-angle,"previous":raw_angle,"basis":Basis(rotation_axis(),-angle)*wheel_frame.basis.inverse()*controller.global_basis,"radial_valid":true,"side":0 if local.x<0 else 1}
   if not rig.simulated:controller.trigger_haptic_pulse("haptic",0.,.35,.045,0.)
  if not hands[i].is_empty():
   var radial_valid:bool=(Vector2(local.x,local.z) if is_bike() else Vector2(local.x,local.y)).length()>.07
   if radial_valid and hands[i].radial_valid:
    movement+=wrapf(raw_angle-hands[i].previous,-PI,PI);count+=1
   hands[i].previous=raw_angle;hands[i].radial_valid=radial_valid
  pressed_before[i]=pressed if usable and tracked and physical_enabled() else true
 if count>0:angle=clampf(angle+movement/count,-maximum_angle(),maximum_angle())
 elif hands[0].is_empty() and hands[1].is_empty():angle=move_toward(angle,0.,4.*minf(delta,.05))
 var wheel:Node3D
 if service.models.has(key):wheel=service.models[key].find_child("Handlebars",true,false) if is_bike() else service.models[key].get_node_or_null("SteeringWheelMount/Wheel")
 if wheel:
  if is_bike():wheel.rotation.y=angle
  else:wheel.rotation.z=angle
 for i in 2:
  var controller=rig.left if i==0 else rig.right
  var model:Node3D=rig.hand_models[i]
  model.visible=usable and (rig.simulated or controller.get_has_tracking_data())
  if hands[i].is_empty():
   model.global_transform=controller.global_transform
  else:
   var at:float=hands[i].anchor+angle
   var basis:Basis=wheel_frame.basis*Basis(rotation_axis(),angle)*hands[i].basis
   model.global_transform=Transform3D(basis,wheel_frame*(Basis(Vector3.UP,angle)*Bike.grip(hands[i].side) if is_bike() else Vector3(cos(at)*Geometry.WHEEL_RADIUS,sin(at)*Geometry.WHEEL_RADIUS,0)))
   rig.hand_animators[i].curls=PackedFloat32Array([.8,.85,.95,.95,.95])
