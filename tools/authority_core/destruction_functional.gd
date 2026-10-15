extends SceneTree
## End-to-end FPSAuthority/Jolt callback, including an early rocket-tank impact.
const Destruction=preload("res://tools/voxel_battle/destruction.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
const Presentation=preload("res://deathmatch/native/cq_presentation.gd")
class World extends Node3D:
 var active:=true
 var map_epoch:=1
 var resident=null
 var layout:Dictionary={"boxes":[]}
 var wall_bodies:Dictionary={}
 var structures=null
 var destruction
 var callbacks:=0
 func cq_ordnance_impact(at:Vector3,damage:float,radius:float)->void:
  callbacks+=1;destruction.impact(at,damage,radius)
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func box(parent:Node3D,at:Vector3,size:Vector3)->StaticBody3D:
 var body:=StaticBody3D.new();body.position=at;var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider);parent.add_child(body);return body
func run()->void:
 for hz in [30,60]:
  Engine.physics_ticks_per_second=hz
  var world:=World.new();root.add_child(world)
  box(world,Vector3(0,-.5,0),Vector3(200,1,200))
  world.wall_bodies[0]=box(world,Vector3(0,1.85,0),Vector3(8.4,3.5,.24))
  world.layout.boxes=[{"kind":0,"center":Vector3(0,1.85,0)-Landscape.CENTERS[0],"size":Vector3(8.4,3.5,.24)}]
  world.destruction=Destruction.new();world.add_child(world.destruction);world.destruction.setup(world,world,false,true)
  var authority=ClassDB.instantiate("FPSAuthority")
  check(authority.configure_world(world) and authority.configure_tick_rate(hz) and authority.configure_cq({"auto_respawn":false}),"Native destruction world configured at "+str(hz))
  authority.configure_frames(true)
  var tank:=CharacterBody3D.new();tank.position=Vector3(0,0,10)
  var tc:=CollisionShape3D.new();var hull:=BoxShape3D.new();hull.size=Vector3(4.5,1.7,4.8);tc.shape=hull;tc.position.y=.85;tank.add_child(tc);world.add_child(tank)
  check(authority.attach_vehicle(0,tank,0.,0)==0,"Native rocket tank attached")
  var actor:=CharacterBody3D.new();actor.position=Vector3(3.5,0,10);actor.collision_layer=2;actor.collision_mask=3
  var ac:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.3;cylinder.height=1.65;ac.shape=cylinder;ac.position.y=.83;actor.add_child(ac);world.add_child(actor)
  var life:int=authority.attach_actor(1,actor,ac,0,1<<2,PackedInt32Array([100,100,100,100]))
  check(life>0 and authority.request_action(1,life,0,0),"Native driver boards")
  for seq in hz:
   var input:Dictionary={"life":life,"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":4,"fire":seq>0,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false}
   check(authority.submit(1,input),"Native impact fixture input")
   await physics_frame;check(authority.advance(),"Native impact fixture tick")
   if world.callbacks>0:break
  check(world.callbacks>0 and not world.destruction.broken.is_empty(),"Real native impact opens authoritative wall collision before two seconds")
  var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,2),Vector3(0,1,-2),1))
  check(hit.is_empty(),"Native projectile creates real Jolt passage")
  # The old client classifier relied on a two-second arm value; impact-fused
  # barrage missiles still need correct travel, colour, motor sound and blast FX.
  var projected:Dictionary={"weapon":5,"gravity":20.,"radius":.3,"arm":0.,"position":Vector3(0,3,0),"velocity":Vector3(0,0,-316),"remaining":90.,"stuck":false,"owner":1,"team":0}
  var frame:Dictionary=Codec.decode_frame(authority.snapshot())
  check(not frame.is_empty(),"Native impact snapshot decodes")
  if not frame.is_empty():
   frame.projectiles={999:projected}
   var state:Array=Presentation.project(frame,0.,1,60.)
   check(state[10].ordnance[999].extra.get("battery_shot",false) and state[10].ordnance[999].definition.blast_radius==30.,"Impact-fused barrage retains native client classification")
  authority=null;world.free();await process_frame
 print("CQ_DESTRUCTION_NATIVE_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
