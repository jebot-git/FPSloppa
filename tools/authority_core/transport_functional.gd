extends SceneTree
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
const Presentation=preload("res://deathmatch/native/cq_presentation.gd")
const Geometry=preload("res://deathmatch/conquest/classes/transport_geometry.gd")
var authority
var world:Node3D
var checks:=0
var failures:Array=[]
var actors:Array=[]
var lives:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func tick():
 await physics_frame;check(authority.advance(),"transport Jolt authority tick")
func command(id:int,seq:int,drive:float=0.,jump:bool=false):
 return {"life":lives[id-1],"seq":seq,"move":Vector2(0,drive),"yaw":0.,"pitch":0.,"weapon":4,"fire":id!=9,"jump":jump,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false}
func run():
 Engine.physics_ticks_per_second=30;world=Node3D.new();root.add_child(world)
 var floor:=StaticBody3D.new();var fc:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(120,1,120);fc.shape=box;floor.position.y=-.5;floor.add_child(fc);world.add_child(floor)
 authority=ClassDB.instantiate("FPSAuthority");check(authority.configure_world(world),"transport world");check(authority.configure_cq({"auto_respawn":false}),"transport CQ authority");authority.configure_frames(true)
 var truck:=CharacterBody3D.new();var hull:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Geometry.size();hull.shape=shape;hull.position.y=shape.size.y*.5;truck.add_child(hull);world.add_child(truck)
 check(authority.attach_vehicle(3,truck,0.,0)==0,"native Jolt transport with team")
 for i in 9:
  var actor:=CharacterBody3D.new();actor.collision_layer=2;actor.collision_mask=3;actor.position=Geometry.point(i if i<8 else 0,"entry")+Vector3(0,0,.05 if i==8 else 0);var collision:=CollisionShape3D.new();var capsule:=CylinderShape3D.new();capsule.radius=.3;capsule.height=1.65;collision.shape=capsule;collision.position.y=.825;actor.add_child(collision);world.add_child(actor);actors.append(actor)
  var life:int=authority.attach_actor(i+1,actor,collision,0 if i<8 else 1,1<<4,PackedInt32Array([100,100,100,100]));lives.append(life);check(life>0,"passenger actor attachment")
 for i in 8:
  check(authority.submit_packet(i+1,Codec.encode_input(command(i+1,0))),"pod boarding input")
  check(authority.request_action(i+1,lives[i],0,0),"pod boarding action");await tick()
 check(authority.submit_packet(9,Codec.encode_input(command(9,0))),"enemy input");check(authority.request_action(9,lives[8],0,0),"enemy boarding request");await tick()
 for tick_number in range(1,45):
  for i in 8:check(authority.submit_packet(i+1,Codec.encode_input(command(i+1,tick_number,-1 if i==6 else 1))),"passenger drive/fire packet")
  await tick()
 var light_command:Dictionary=command(7,45);light_command.offhand_fire=true
 check(authority.submit_packet(7,Codec.encode_input(light_command)),"driver headlight packet")
 await tick();await tick()
 var frame:Dictionary=Codec.decode_frame(authority.snapshot());check(not frame.is_empty(),"transport frame decode")
 if not frame.is_empty():
  var vehicle:Dictionary=frame.vehicles.values()[0];check(vehicle.kind==3 and vehicle.team==0 and vehicle.hp==100,"transport wire kind, team and 100 HP")
  check(vehicle.headlights and vehicle.grounded,"headlight and grounded bits decode independently")
  check(not frame.players[7].nvg,"headlight press does not toggle driver NVG")
  var projected:Array=Presentation.project(frame,0.,1,120.);check(not projected.is_empty(),"transport projection")
  # Explicit seat byte carries all eight seats.
  for i in 8:
   check(frame.players[i+1].vehicle==0 and frame.players[i+1].vehicle_seat==i,"pod index survives native binary snapshot")
   check(actors[i].collision_layer==0,"passenger Jolt collider disabled")
   var expected:Vector3=vehicle.position+Basis(Vector3.UP,vehicle.yaw)*Geometry.point(i,"seat")
   check(frame.players[i+1].position.distance_to(expected)<.001,"Jolt passenger seat follows hull")
  check(frame.players[9].vehicle==-1,"enemy not seated")
  check(authority.metrics().shots==0,"all mounted firing suppressed")
  check(truck.position.z<-.5,"rocket mobility drives actual Jolt transport")
  for part in projected:
   if part is Dictionary:
    for key in part:
     if str(key).begins_with("ctk:"):
      check(part[key].seats==[1,2,3,4,5,6,7,8],"eight occupant IDs projected for remote presentation")
      check(part[key].headlights,"headlights survive remote presentation projection")
 check(authority.submit_packet(4,Codec.encode_input(command(4,45,0,true))),"passenger jump packet")
 await tick();await tick()
 frame=Codec.decode_frame(authority.snapshot());check(frame.players[4].vehicle==-1 and frame.players[4].vehicle_seat==-1,"jump exits transport on native server")
 check(actors[3].collision_layer==2 and actors[3].collision_mask==3,"jump restores actual Jolt player collision")
 check(absf(actors[3].position.x)>Geometry.size().x*.5+.3,"dismount lands outside vehicle hull")
 authority.request_restart();await tick();await tick();frame=Codec.decode_frame(authority.snapshot());check(frame.vehicles.values()[0].team==0 and frame.vehicles.values()[0].pilot==0,"reset retains transport ownership and clears driver")
 world.queue_free();await process_frame
 print("AUTHORITY_TRANSPORT_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
