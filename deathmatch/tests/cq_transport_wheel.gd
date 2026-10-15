extends SceneTree
const Wheel=preload("res://deathmatch/vr/transport_wheel.gd")
const Geometry=preload("res://deathmatch/conquest/classes/transport_geometry.gd")
class Controller extends Node3D:
 var grip:=0.
 var stick:=Vector2.ZERO
 var tracked:=true
 func get_float(_action):return grip
 func get_vector2(_action):return stick
 func get_has_tracking_data():return tracked
class Service extends RefCounted:
 var rows:Dictionary={0:{"kind":"transport","hp":100,"pilot":1,"yaw":0.}}
 var models:Dictionary={}
 func key_for(_id):return 0
 func view_row(key):return rows[key]
 func visual_basis(row):return Basis(Vector3.UP,row.yaw)
 func visual_origin(_row):return Vector3.ZERO
class Game extends Node:
 var battery_tanks=Service.new()
 var active:=true
 var menu_open:=false
 var local_yaw:=0.
 var bindings:Dictionary={"physical_transport_steering":true}
 func local_state():return {"dead":false}
class Rig extends Node3D:
 var game
 var left=Controller.new()
 var right=Controller.new()
 var head=Node3D.new()
 var hand_models:Array=[Node3D.new(),Node3D.new()]
 var hand_animators:Array=[{"curls":[]},{"curls":[]}]
 var simulated:=true
 var focused:=true
 var scores:=false
 var left_handed:=false
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var game:=Game.new();root.add_child(game)
 var rig:=Rig.new();game.add_child(rig);rig.game=game
 for n in [rig.left,rig.right,rig.head]+rig.hand_models:rig.add_child(n)
 var model:=Node3D.new();game.add_child(model);Geometry.prepare_seats(model);game.battery_tanks.models[0]=model
 var wheel:=Wheel.new();wheel.setup(rig);wheel.update(.016)
 var frame:Transform3D=wheel.frame()
 rig.left.global_position=frame*Vector3(-Geometry.WHEEL_RADIUS,0,0)
 rig.right.global_position=frame*Vector3(Geometry.WHEEL_RADIUS,0,0)
 wheel.update(.016);rig.left.grip=1.;wheel.update(.016)
 check(not wheel.hands[0].is_empty(),"left hand grips rim")
 check(wheel.command()==Vector2.ZERO,"centered wheel and idle throttle are neutral")
 rig.left.global_position=frame*Vector3(cos(PI+PI/4)*Geometry.WHEEL_RADIUS,sin(PI+PI/4)*Geometry.WHEEL_RADIUS,0);wheel.update(.016)
 check(absf(wheel.angle-PI/4)<.0001 and wheel.command().x<0,"counterclockwise hand movement steers left")
 check(rig.hand_models[0].global_position.distance_to(rig.left.global_position)<.001,"gripped hand follows exact wheel attachment")
 rig.right.stick=Vector2(0,1)
 check(wheel.command().y==-1,"right weapon-hand up gives full throttle while steering")
 rig.right.stick=Vector2(0,-1)
 check(wheel.command().y==1,"weapon-hand down brakes then reverses")
 rig.left_handed=true;rig.left.stick=Vector2(0,.59);rig.right.stick=Vector2.ZERO
 check(absf(wheel.command().y+.5)<.001,"left-handed weapon stick uses proportional throttle")
 rig.right.grip=1.;wheel.update(.016)
 check(not wheel.hands[1].is_empty(),"second hand attaches independently")
 var before:float=wheel.angle
 for pair in [[rig.left,PI+PI/4],[rig.right,0.]]:
  var at:float=pair[1]+.2;pair[0].global_position=frame*Vector3(cos(at)*Geometry.WHEEL_RADIUS,sin(at)*Geometry.WHEEL_RADIUS,0)
 wheel.update(.016)
 check(absf(wheel.angle-before-.2)<.001,"two-hand turn is averaged without double-counting")
 rig.left.grip=0.;wheel.update(.016)
 check(wheel.hands[0].is_empty() and not wheel.hands[1].is_empty(),"releasing one grip preserves other attachment")
 var previous_angle:float=wheel.angle;game.battery_tanks.rows[0].yaw=.25;wheel.update(.016);frame=wheel.frame()
 check(absf(wheel.angle-previous_angle)<.001 and absf(game.local_yaw-.25)<.001,"chassis rotation carries seated driver without moving the wheel relative to the cabin")
 rig.right.grip=0.
 check(wheel.command()==Vector2.ZERO,"releasing final grip immediately neutralizes input")
 wheel.update(.016);rig.right.position=Vector3(3,3,3);rig.right.grip=1.;wheel.update(.016)
 check(wheel.hands[1].is_empty(),"distant grip cannot attach")
 rig.right.grip=0.;wheel.update(.016);rig.right.global_position=frame*Vector3(Geometry.WHEEL_RADIUS,0,0);rig.right.grip=1.;wheel.update(.016)
 game.menu_open=true;wheel.update(.016)
 check(wheel.hands[1].is_empty() and wheel.command()==Vector2.ZERO,"menu releases wheel and blocks throttle")
 game.menu_open=false;wheel.update(.016)
 check(wheel.hands[1].is_empty(),"held grip does not reacquire after menu without release")
 rig.right.grip=0.;wheel.update(.016);rig.right.grip=1.;wheel.update(.016)
 rig.simulated=false;rig.right.tracked=false;wheel.update(.016)
 check(wheel.hands[1].is_empty() and wheel.command()==Vector2.ZERO,"tracking loss releases attached hand")
 rig.right.tracked=true;wheel.update(.016)
 check(wheel.hands[1].is_empty(),"tracking recovery requires a new grip edge")
 rig.simulated=true;game.bindings.physical_transport_steering=false;wheel.update(.016)
 check(wheel.hands[0].is_empty() and wheel.hands[1].is_empty() and wheel.command()==Vector2.ZERO,"optional stick mode releases wheel attachments and wheel input")
 game.bindings.physical_transport_steering=true
 game.battery_tanks.rows[0].pilot=99;wheel.update(.016)
 check(wheel.key==-1 and wheel.command()==Vector2.ZERO,"passenger cannot control driver wheel")
 check(Geometry.wheel_mesh.get_faces().size()/3==492 and Geometry.column_mesh.get_faces().size()/3==48,"shared cabin wheel and column total 540 triangles")
 check(model.has_node("SteeringWheelMount/Column"),"wheel has a fixed cabin column")
 print("CQ_TRANSPORT_WHEEL ",JSON.stringify({"checks":checks,"failures":failures}))
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
