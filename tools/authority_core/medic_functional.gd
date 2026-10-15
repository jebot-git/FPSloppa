extends SceneTree
## Real Jolt + CQ wire interaction test, gated by the isolated medic fixture flag.
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Equipment=preload("res://deathmatch/avatars/equipment.gd")
var authority
var world:Node3D
var checks:=0
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func actor(id:int,at:Vector3)->void:
 var body:=CharacterBody3D.new();body.position=at;body.collision_layer=2;body.collision_mask=3
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.3;shape.height=1.65;collision.shape=shape;body.add_child(collision);world.add_child(body);body.name="Actor"+str(id)
 check(authority.attach_actor(id,body,collision,0,1<<2,PackedInt32Array([1000,1000,1000,1000]))>0,"attach training actor")
func command(life:int,pose:Dictionary)->Dictionary:
 return {"life":life,"seq":0,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":7,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false,"vr_device":true,"weapon_held":true,"xr":pose,"cq_drag":false,"swim":Vector3.ZERO}
func step(c:Dictionary)->void:
 check(authority.submit_packet(1,Codec.encode_input(c)),"production tracked packet admitted")
 c.seq+=1;await physics_frame;check(authority.advance(),"native Jolt tick")
func fixture()->Dictionary:
 var state:Dictionary=authority.prepare_medic_test(1,-1)
 check(not state.is_empty(),"isolated medic fixture ready")
 return state
func run():
 Engine.physics_ticks_per_second=30
 authority=ClassDB.instantiate("FPSAuthority");world=Node3D.new();world.set_meta("cq_medic_test",true);root.add_child(world)
 authority.configure_world(world);authority.configure_cq({"auto_respawn":false});authority.configure_frames(true)
 var floor_body:=StaticBody3D.new();floor_body.position.y=-.5;floor_body.collision_layer=1;var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(30,1,30);collider.shape=shape;floor_body.add_child(collider);world.add_child(floor_body)
 actor(1,Vector3.ZERO);actor(-1,Vector3(1,0,-1));await physics_frame
 var state:=fixture();var pose:Dictionary=Poses.neutral();pose.head.origin.y=1.4
 var contact:Vector3=state.patient.position-state.medic.position+Vector3.UP*.35
 pose.right=Transform3D(Basis(Vector3.UP,PI),contact-Basis(Vector3.UP,PI)*Equipment.injector_tip());pose.weapon=pose.right
 var c:=command(state.medic.life,pose);c.fire=true
 for i in 40:await step(c)
 check(world.get_node("Actor-1").collision_layer==0 and world.get_node("Actor-1").collision_mask==1,"incapacitated patient collides with world only")
 check(authority.inspect(-1).inject_progress>1.,"real tracked injector contact starts revival")
 c.xr.right.origin.x-=.4;c.xr.weapon=c.xr.right
 for i in 10:await step(c)
 check(authority.inspect(-1).inject_progress>1.5,"native attachment sustains administration with wrist drift")
 c.fire=false;await step(c);check(authority.inspect(-1).inject_progress==0.,"trigger release resets administration")
 c.xr.right.origin.x+=.4;c.xr.weapon=c.xr.right;c.fire=true
 for i in 94:await step(c)
 check(not authority.inspect(-1).incapacitated and authority.inspect(-1).hp==35.,"real Jolt patient revives after continuous three seconds")
 check(world.get_node("Actor-1").collision_layer==2 and world.get_node("Actor-1").collision_mask==3,"revival restores normal player collisions")
 state=fixture();pose=Poses.neutral();pose.head.origin.y=1.4
 contact=state.patient.position-state.medic.position+Vector3.UP*.35;pose.left.origin=contact;pose.offhand_weapon=pose.left
 c=command(state.medic.life,pose);c.weapon=4;c.cq_drag=true
 await step(c);var before:Vector3=authority.inspect(-1).position
 c.xr.left.origin.z+=.8;c.xr.offhand_weapon=c.xr.left
 for i in 12:await step(c)
 check(authority.inspect(-1).position.z>before.z+.2,"tracked grip actually drags patient through Jolt")
 check(world.get_node("Actor-1").collision_layer==0 and world.get_node("Actor-1").collision_mask==1,"dragging preserves world-only patient collisions")
 c.cq_drag=false;await step(c);var after:Vector3=authority.inspect(-1).position
 for i in 3:await step(c)
 check(authority.inspect(-1).position.distance_to(after)<.01,"releasing grip stops patient movement")
 state=fixture();pose=Poses.neutral();pose.left.origin=Vector3(-.3,1,-.2);pose.weapon=pose.left;pose.left_handed=true;pose.offhand_weapon=pose.right
 c=command(state.medic.life,pose);c.weapon=6;await step(c)
 check(authority.request_action(1,state.medic.life,0,0,6,1),"reliable physical box release admitted")
 await step(c);var frame:Dictionary=Codec.decode_frame(authority.snapshot());check(not frame.boxes.is_empty(),"native box appears in production snapshot")
 var key:int=frame.boxes.keys()[0]
 check(frame.boxes[key].position.y>.4 and authority.inspect(1).hp==35.,"medical box is airborne without healing")
 c.weapon=4
 for i in 30:await step(c)
 frame=Codec.decode_frame(authority.snapshot())
 check(frame.boxes[key].position.y<.15 and authority.inspect(1).hp>35.,"grounded box heals after Jolt landing")
 var ready:float=authority.inspect(1).class_state.box_ready
 check(absf(ready-frame.mode.time-14.)<.2,"physical release starts fifteen-second cooldown")
 c.weapon=6;c.xr.left.origin=Vector3(-.5,1,-.5);c.xr.weapon=c.xr.left;await step(c)
 check(authority.request_action(1,state.medic.life,1,0,6,1),"early replacement request admitted for native cooldown validation")
 for i in 2:await step(c)
 frame=Codec.decode_frame(authority.snapshot())
 check(frame.boxes.size()==1 and frame.boxes.has(key) and frame.boxes[key].position.y<.2,"cooldown prevents immediate redeployment")
 for i in 450:await step(c)
 check(authority.request_action(1,state.medic.life,2,0,6,1),"replacement request admitted after fifteen seconds")
 for i in 2:await step(c)
 frame=Codec.decode_frame(authority.snapshot())
 check(frame.boxes.size()==1 and not frame.boxes.has(key) and frame.boxes.values()[0].position.y>.4,"replacement retires prior box and appears at tracked hand after cooldown")
 state=fixture();c=command(state.medic.life,Poses.neutral());c.weapon=4;await step(c)
 frame=Codec.decode_frame(authority.snapshot())
 check(frame.boxes.is_empty() and authority.inspect(1).hp==35.,"fixture reset removes old medical boxes and restores low health")
 print("CQ_MEDIC_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}))
 authority=null;world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
