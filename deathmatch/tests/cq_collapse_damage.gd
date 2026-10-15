extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_collapse_fixture.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func actor(parent:Node3D,at:Vector3)->CharacterBody3D:
 var body:=CharacterBody3D.new();body.position=at;body.collision_layer=2;body.collision_mask=1
 var shape:=CollisionShape3D.new();var capsule:=CylinderShape3D.new();capsule.radius=.3;capsule.height=1.65;shape.shape=capsule;shape.position.y=.83;body.add_child(shape);parent.add_child(body);return body
func hull(parent:Node3D,at:Vector3)->CharacterBody3D:
 var body:=CharacterBody3D.new();body.position=at
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,1.5,3);shape.shape=box;shape.position.y=.75;body.add_child(shape);parent.add_child(body);return body
func run()->void:
 for hz in [30,60]:
  Engine.physics_ticks_per_second=hz
  var f:Dictionary=Fixture.make(root,false);f.service.set_process(false)
  var core=ClassDB.instantiate("FPSAuthority");f.game.authority=core
  check(core.configure_world(f.game) and core.configure_tick_rate(hz) and core.configure_cq({"auto_respawn":false}) and core.configure_frames(true),"Real native collapse fixture at "+str(hz))
  var inside:=actor(f.world,f.origin+Vector3(0,.15,0));var outside:=actor(f.world,f.origin+Vector3(26,.15,0))
  check(core.attach_actor(1,inside,inside.get_child(0),0,4,PackedInt32Array([100,100,100,100]))>0,"Inside native player admitted")
  check(core.attach_actor(2,outside,outside.get_child(0),1,4,PackedInt32Array([100,100,100,100]))>0,"Outside native player admitted")
  var vehicle:=hull(f.world,f.origin+Vector3(2,.15,1));var other:=hull(f.world,f.origin+Vector3(26,.15,1))
  check(core.attach_vehicle(1,vehicle,0.,0)>=0 and core.attach_vehicle(2,other,0.,1)>=0,"Native hulls admitted")
  for i in 6:await physics_frame;check(core.advance(),"Native initial tick")
  var before:Dictionary=Codec.decode_frame(core.snapshot())
  f.service.apply_breaks(Fixture.support_ids(f.service,0,1),f.origin,false)
  check(core.inspect(1).dead and not core.inspect(2).dead,"Native callback kills only inside player despite spawn protection")
  for i in 6:await physics_frame;check(core.advance(),"Native collapse publication tick")
  var after:Dictionary=Codec.decode_frame(core.snapshot())
  check(after.vehicles[before.vehicles.keys()[0]].hp==before.vehicles.values()[0].hp-100,"Native snapshot reflects 100 collapse hull damage")
  check(after.vehicles[before.vehicles.keys()[1]].hp==before.vehicles.values()[1].hp,"Outside native hull is unaffected")
  check(after.events.values().any(func(e):return e.kind==9 and e.actor==1 and (e.detail&3)==3 and ((e.detail>>8)&255)==11),"Collapse publishes gibbed death with environmental damage kind")
  f.service.collapse_building(0,false)
  check(f.game.collapse_calls.size()==1,"Repeated collapse never reapplies native occupant damage")
  f.game.authority=null;core=null;f.game.free();await process_frame
 print("CQ_COLLAPSE_DAMAGE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
