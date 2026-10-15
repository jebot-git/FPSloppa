extends SceneTree
## Real GDExtension/Jolt cover callback at both supported simulation rates.
const Cover=preload("res://tools/voxel_battle/grass_cover.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var checks:=0
var failures:Array=[]
class World extends Node3D:
 func grass_cover_at(point:Vector3)->bool:return Cover.contains(point)
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var tile:Dictionary=Cover.tile(Vector2i(13,35));var at:=Vector3.ZERO
 for cell in tile.candidates:
  var point:=Cover.root(tile,cell)
  if point.is_finite():at=point;break
 for hz in [30,60]:
  Engine.physics_ticks_per_second=hz
  var world:=World.new();root.add_child(world)
  var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(120,.5,120);collision.shape=shape;floor.position=at-Vector3.UP*.25;floor.add_child(collision);world.add_child(floor)
  var authority=ClassDB.instantiate("FPSAuthority");check(authority.configure_world(world),"Native world callback bound")
  check(authority.configure_tick_rate(hz),"Supported native tick rate")
  check(authority.configure_cq({"auto_respawn":false}),"Native CQ spotting enabled");authority.configure_frames(true)
  var lives:Array=[]
  for i in 2:
   var actor:=CharacterBody3D.new();actor.position=at+Vector3(20 if i==0 else 0,0,0);actor.collision_layer=2;actor.collision_mask=1
   var collider:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.3;cylinder.height=1.65;collider.shape=cylinder;collider.position.y=.83;actor.add_child(collider);world.add_child(actor)
   lives.append(authority.attach_actor(i+1,actor,collider,i,1<<4,PackedInt32Array([100,100,100,100])))
  var frame:Dictionary={}
  for seq in hz/2:
   for id in [1,2]:check(authority.submit(id,{"life":lives[id-1],"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":4,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":id==2,"blocked":false}),"Accepted prone input")
   await physics_frame;check(authority.advance(),"Real Jolt authority advances")
   if not authority.snapshot().is_empty():frame=Codec.decode_frame(authority.snapshot())
  check(frame.players[2].height<=.7,"Native target is prone")
  # Ignore acquisition during the first 100ms posture/cover update; let memory expire.
  for seq in range(hz/2,hz*11):
   for id in [1,2]:authority.submit(id,{"life":lives[id-1],"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":4,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":id==2,"blocked":false})
   await physics_frame;authority.advance()
  frame=Codec.decode_frame(authority.snapshot())
  check(frame.players[2].spotted[0]<=frame.mode.time,"Actual grass callback prevents refreshing 20m target at %dHz"%hz)
  for seq in range(hz*11,hz*11+hz/3):
   for id in [1,2]:authority.submit(id,{"life":lives[id-1],"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":4,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false})
   await physics_frame;authority.advance()
  frame=Codec.decode_frame(authority.snapshot());check(frame.players[2].spotted[0]>frame.mode.time,"Standing restores spotting at %dHz"%hz)
  authority=null;world.free();await process_frame
 print("CQ_GRASS_NATIVE_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
