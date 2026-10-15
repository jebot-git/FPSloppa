extends SceneTree
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
const View=preload("res://deathmatch/conquest/classes/battery_view.gd")
class Rig extends Node3D:
 var head:Camera3D
 var gun:Node3D
 var hand_models:Array=[]
class Game extends Node3D:
 var active:=true
 var clock:=1.
 var menu_open:=false
 var headless:=false
 var vr:=false
 var local_yaw:=0.
 var local_pitch:=0.
 var camera_eye_height:=1.5
 var viewmodel:Node3D
 var offhand_viewmodel:Node3D
 var camera:Camera3D
 var xr_rig:Rig
 var players:Dictionary={1:{}}
 var fighters:Dictionary={}
 func is_vr()->bool:return vr
 func _weapon_transform(_id:int)->Transform3D:
  return xr_rig.gun.global_transform if vr else Transform3D(Basis(Vector3.UP,local_yaw)*Basis(Vector3.RIGHT,local_pitch),Vector3.ZERO)
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var game:=Game.new();root.add_child(game);game.camera=Camera3D.new();game.add_child(game.camera);game.camera.make_current()
 game.xr_rig=Rig.new();game.add_child(game.xr_rig);game.xr_rig.head=Camera3D.new();game.xr_rig.add_child(game.xr_rig.head);game.xr_rig.gun=Node3D.new();game.xr_rig.add_child(game.xr_rig.gun)
 var service:=Tanks.new();game.add_child(service);service.setup(game);service.next_helper=INF
 var view:=View.new();service.add_child(view);view.setup(game,service);service.view=view
 for kind in ["light","heavy","rocket"]:
  service.rows[0]=service.spawn_row({"poi":"test","position":Vector3.ZERO,"yaw":0.,"kind":kind,"team":0});service.rows[0].pilot=1;service.body(0)
  for heading in [-1.2,0.,1.2]:
   game.local_yaw=heading;game.local_pitch=.8 # Exceeds light/heavy elevation limits.
   service.rendered_rows[0]=service.render_row(0,.5)
   var row:Dictionary=service.rendered_rows[0]
   view.update()
   check((-view.sensor.global_basis.z).distance_to(row.direction)<.0001,kind+" desktop camera follows the same render-frame boresight as the turret")
   check(view.sensor.global_position.distance_to(service.muzzle(row)+row.direction*.1)<.0001,kind+" desktop camera follows the rendered muzzle")
   check(view.viewport.get_camera_3d()==view.sensor,kind+" scope sensor remains current")
   check(absf(atan2(-row.direction.x,-row.direction.z)-heading)<.0001,kind+" fresh mouse yaw responds without waiting for a physics tick")
   if kind!="rocket":check(absf(rad_to_deg(asin(row.direction.y))-Tanks.PROFILES[kind].pitch_max)<.001,kind+" view and barrel share their elevation clamp")
  service.draw()
  var visible_aim:Node3D=service.models[0].find_child("Aim",true,false)
  check((-visible_aim.global_basis.z).distance_to(-view.sensor.global_basis.z)<.0001,kind+" actual rendered barrel and scope camera share one aim basis")
  check(service.models[0].physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,kind+" manually interpolated model avoids a second engine interpolation")
  service.models[0].free();service.models.erase(0)
  service.bodies[0].free();service.bodies.erase(0)
 # VR follows the gun controller, while head gaze remains independent.
 game.vr=true;game.local_yaw=0.;game.local_pitch=0.
 service.rows[0]=service.spawn_row({"poi":"test","position":Vector3.ZERO,"yaw":0.,"kind":"light","team":0});service.rows[0].pilot=1;service.body(0)
 game.xr_rig.head.rotation=Vector3(.1,.9,0);game.xr_rig.gun.rotation=Vector3(.2,-.7,0)
 var head_basis:Basis=game.xr_rig.head.global_basis
 var expected:Vector3=-game.xr_rig.gun.global_basis.z
 service.rendered_rows[0]=service.render_row(0,.5);view.update()
 check(service.rendered_rows[0].direction.distance_to(expected)<.0001,"VR visible turret follows weapon-hand controller rather than head")
 check(service.direction(1).distance_to(expected)<.0001,"VR authoritative aim uses the weapon-hand pose")
 check(game.xr_rig.head.global_basis.is_equal_approx(head_basis),"VR reticle does not steer the player's head camera")
 game.xr_rig.head.rotation.y=-1.1
 check(service.render_row(0,.5).direction.distance_to(expected)<.0001,"Turning head alone does not redirect VR turret")
 game.xr_rig.gun.rotation.y=.5
 check(service.render_row(0,.5).direction.distance_to(-game.xr_rig.gun.global_basis.z)<.0001,"Moving weapon hand redirects VR turret")
 check(view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"VR switches off the desktop camera feed")
 service.rows[0].position=Vector3(1,0,0);service.rows[0].visual_y=.25
 service.draw()
 check(game.xr_rig.global_position.distance_to(service.render_passenger_position(1,0))<.0001,"VR origin follows the same rendered hull as the tank")
 check(game.xr_rig.head.global_basis.is_equal_approx(Basis(Vector3.UP,-1.1)*Basis(Vector3.RIGHT,.1)),"VR hull-following does not override head orientation")
 service.models[0].free();service.models.erase(0)
 game.vr=false;service.bodies[0].free();service.bodies.erase(0)
 # Render the cabin and seated eye from exactly one interpolated hull pose.
 var row:=service.spawn_row({"poi":"test","position":Vector3.ZERO,"yaw":0.,"kind":"transport","team":0});row.pilot=1;row.seats[6]=1;row.seat_lives[6]=1
 service.rows[0]=row;service.body(0);service.remember_render(0,row)
 row.position=Vector3(1,0,0);row.visual_y=0.;row.yaw=.2
 var previous:=Vector3.INF
 for alpha in [0.,.25,.5,.75,1.]:
  var rendered:=service.render_row(0,alpha);service.rendered_rows[0]=rendered
  view.update()
  var seat:Vector3=service.visual_origin(rendered)+service.visual_basis(rendered)*Tanks.Transport.point(6,"seat")
  check(game.camera.global_position.distance_to(seat+Vector3.UP*game.camera_eye_height)<.0001,"Transport eye remains fixed to its rendered seat at interpolation fraction "+str(alpha))
  check(is_equal_approx(rendered.position.x,alpha),"Transport hull moves continuously between simulation poses")
  if previous.is_finite():check(game.camera.global_position.distance_to(previous)<.5,"Transport rendered eye has no full-tick jumps")
  previous=game.camera.global_position
 service.draw()
 var rendered_seat:Vector3=service.models[0].global_transform*Tanks.Transport.point(6,"seat")
 check(game.camera.global_position.distance_to(rendered_seat+Vector3.UP*game.camera_eye_height)<.0001,"Actual transport model and desktop cabin camera use the same frame pose")
 check(row.position==Vector3(1,0,0) and row.yaw==.2,"Rendering does not mutate authoritative vehicle state")
 row.position=Vector3(500,0,0);row.visual_y=0.
 check(service.render_row(0,.5).position==row.position,"Teleports snap rather than interpolating across the map")
 # Remote snapshots preserve a separate render interpolation history.
 row.position=Vector3(1,0,0);service.previous_render.clear();service.rendered_rows.clear()
 var packet:=service.rows.duplicate(true);packet[0].position=Vector3(2,0,0)
 service.receive(packet,0.)
 check(service.previous_render[0].remote and service.render_row(0,0.).position.x==1. and service.render_row(0,1.).position.x==2.,"Received snapshots interpolate from the prior rendered hull")
 view.deactivate();check(game.camera.cull_mask!=(1<<19),"Leaving vehicle restores normal camera visibility")
 service.reset();check(service.previous_render.is_empty() and service.rendered_rows.is_empty(),"Map reset removes interpolation history")
 game.queue_free();await process_frame;await process_frame
 print("CQ_VEHICLE_VIEW_MOTION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
