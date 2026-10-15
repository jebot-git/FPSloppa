extends SceneTree
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func box(world:Node3D,at:Vector3,size:Vector3):
 var body:=StaticBody3D.new();body.position=at;world.add_child(body);var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
func _initialize():run.call_deferred()
func run():
 Engine.physics_ticks_per_second=30
 for mode in 3:
  var world:=Node3D.new();root.add_child(world);box(world,Vector3(0,-.5,0),Vector3(20,1,20))
  var rise:float=.3 if mode!=1 else .8
  box(world,Vector3(0,rise*.5,-2),Vector3(3,rise,2))
  if mode==2:box(world,Vector3(0,2.2,-1.5),Vector3(3,1,4))
  var actor:=CharacterBody3D.new();actor.position=Vector3(0,.02,1);actor.collision_layer=2;actor.collision_mask=3;actor.floor_snap_length=.55;world.add_child(actor)
  var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.3;shape.height=1.65;collision.shape=shape;collision.position.y=.83;actor.add_child(collision)
  var authority=ClassDB.instantiate("FPSAuthority");check(authority.configure_world(world),"step fixture world")
  authority.configure_cq({"auto_respawn":false});authority.configure_frames(true)
  var life:int=authority.attach_actor(1,actor,collision,0,1<<4,PackedInt32Array([100,100,100,100]))
  await physics_frame;await physics_frame
  var maximum:=0.
  for tick in 55:
   authority.submit_packet(1,Codec.encode_input({"life":life,"seq":tick,"move":Vector2(0,-1),"yaw":0.,"pitch":0.,"weapon":4,"fire":false,"jump":false,"reload":false,"slow":true,"crouch":false,"prone":false,"blocked":false}))
   await physics_frame;check(authority.advance(),"native step tick");maximum=maxf(maximum,actor.position.y)
  var frame:Dictionary=Codec.decode_frame(authority.snapshot())
  check(not frame.is_empty(),"stepped frame remains valid")
  if mode==0:check(actor.position.z< -3.5 and maximum>.25,"native standing actor walks a 30cm threshold without jump")
  elif mode==1:check(actor.position.z>-.8 and maximum<.2,"native step rejects 80cm obstacle")
  else:check(actor.position.z>-.8 and maximum<.2,"native step rejects riser under a low ceiling")
  authority=null;world.queue_free();await process_frame;await process_frame
 print("CQ_NATIVE_STEPS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
