extends SceneTree
const Presentation=preload("res://deathmatch/native/cq_presentation.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var failures:Array[String]=[]
var checks:=0
var authority
var world:Node3D
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func tick()->void:
 await physics_frame
 check(authority.advance(),"Jolt native entity tick")
func run()->void:
 Engine.physics_ticks_per_second=30
 world=Node3D.new();root.add_child(world)
 var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.5,100);collision.shape=box;floor.position.y=-.25;floor.add_child(collision);world.add_child(floor)
 authority=ClassDB.instantiate("FPSAuthority");check(authority.configure_world(world),"cold world reference");check(authority.configure_cq({"auto_respawn":false}),"CQ mode");authority.configure_frames(true)
 var tank:=CharacterBody3D.new();var tc:=CollisionShape3D.new();var hull:=BoxShape3D.new();hull.size=Vector3(2.2,1,4.8);tc.shape=hull;tc.position.y=.5;tank.add_child(tc);world.add_child(tank)
 check(authority.attach_vehicle(1,tank,0.)==0,"Jolt vehicle attachment")
 var actor:=CharacterBody3D.new();actor.collision_layer=2;actor.collision_mask=3;actor.position=Vector3(3,0,0);var ac:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.3;cylinder.height=1.65;ac.shape=cylinder;ac.position.y=.83;actor.add_child(ac);world.add_child(actor)
 var life:int=authority.attach_actor(1,actor,ac,0,1<<2,PackedInt32Array([100,100,100,100]));check(life>0,"actor attachment")
 check(authority.request_action(1,life,0,0),"board action")
 for index in 50:
  var command:Dictionary={"life":life,"seq":index,"move":Vector2(0,-1),"yaw":0.,"pitch":0.,"weapon":4,"fire":index>20,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false,"view_time":maxf(0,index/30.-.1)}
  check(authority.submit_packet(1,Codec.encode_input(command)),"CQI2 rewind packet accepted");await tick()
  if authority.snapshot().is_empty():continue
  var frame:Dictionary=Codec.decode_frame(authority.snapshot());check(not frame.is_empty(),"CQA2 all-section decode")
  if frame.is_empty():continue
  check(not Presentation.project(frame,0.,1,120.).is_empty(),"native client presentation projection")
  check(frame.players[1]["class"].role==0,"native class frame");check(frame.players[1].vehicle==0,"mounted pilot frame")
  check(frame.vehicles.size()==1,"native vehicle frame")
  if frame.vehicles.size():
   var row:Dictionary=frame.vehicles.values()[0];check(row.pilot==1 and row.life==life,"vehicle pilot lifecycle");check(row.visual_y-row.position.y<=.5001,"hover height bounded");if frame.tick==authority.metrics().tick:check(row.position.distance_to(tank.global_position)<.0001,"resident vehicle vs Jolt scene")
 check(tank.position.z<-.5,"real Jolt hull advances")
 check(authority.request_action(1,life,1,0),"dismount action")
 await tick();await tick()
 var final:Dictionary=Codec.decode_frame(authority.snapshot());check(final.players[1].vehicle==-1,"native dismount with exit collision query");check(actor.collision_layer==2,"pilot collision restored")
 # Frame parser rejects NaN entity data, truncation and oversized counts.
 var frame:PackedByteArray=authority.snapshot()
 for index in range(14,mini(frame.size(),118)):
  check(Codec.decode_frame(frame.slice(0,index)).is_empty(),"truncated frame rejected")
 # A prone corpse and a mounted pilot must not leave their short/disabled
 # collision shape behind when a new native life is created.
 var current:int=authority.inspect(1).life
 check(authority.submit_packet(1,Codec.encode_input({"life":current,"seq":100,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":4,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"blocked":false,"prone":true})),"prone before restart")
 await tick()
 check(ac.shape.height<.8,"real Jolt prone shape")
 check(authority.request_action(1,current,2,7),"prone suicide")
 await tick()
 check(authority.inspect(1).dead,"native death before restart")
 check(authority.request_restart(),"administrative restart")
 await tick();await tick()
 check(authority.inspect(1).life!=current and not authority.inspect(1).dead,"restart creates living generation")
 check(ac.shape.height>=1.65 and actor.collision_layer==2 and actor.collision_mask==3,"restart restores Jolt standing collision")
 check(ac.position.y>=.82,"restart restores collider centre")
 world.queue_free();await process_frame
 print("AUTHORITY_ENTITY_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
