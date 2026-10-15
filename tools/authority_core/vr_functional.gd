extends SceneTree
## Differential checks against the live CQ gesture and jetpack reference sources.
const Runtime=preload("res://deathmatch/native/runtime.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Reload=preload("res://deathmatch/conquest/classes/reload_state.gd")
const Magazines=preload("res://deathmatch/conquest/classes/magazines.gd")
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const IK=preload("res://deathmatch/avatars/controller_arms.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var authority
var world:Node3D
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok and failures.size()<30:failures.append(label);push_error(label)
func command(life:int,seq:int,w:int)->Dictionary:
 return {"life":life,"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":w,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false}
func tick()->void:
 await physics_frame
 check(authority.advance(),"native VR physics tick")
func make_actor(id:int,w:int)->Array:
 var body:=CharacterBody3D.new();body.position=Vector3(id*5.,0,0);body.collision_layer=2;body.collision_mask=3
 var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.3;shape.height=1.65;collider.shape=shape;body.add_child(collider);world.add_child(body)
 var life:int=authority.attach_actor(id,body,collider,1,1<<w,PackedInt32Array([1000,1000,1000,1000]));check(life>0,"VR actor admitted");return [body,life]
func pose_for(left:bool,support:Vector3)->Dictionary:
 var pose:Dictionary=Poses.neutral();pose.left_handed=left
 pose.weapon.origin.x=-.3 if left else .3
 if left:pose.left=pose.weapon;pose.right=Transform3D(Basis.IDENTITY,support)
 else:pose.right=pose.weapon;pose.left=Transform3D(Basis.IDENTITY,support)
 pose.offhand_weapon=pose.right if left else pose.left
 return pose
func near(a:Variant,b:Variant)->bool:
 if a is float:return absf(a-float(b))<.00001
 if a is Vector3:return a.distance_to(b)<.00001
 return a==b
func reload_differential(id:int,w:int,left:bool)->void:
 var row:=make_actor(id,w);var life:int=row[1];var body:CharacterBody3D=row[0]
 var geometry:=12 if w in [5,11] else 2 if w in [2,9,3] else 7
 var reference:Dictionary=Reload.make(3 if w==5 else 7 if w==2 else 30);var clip:int=3 if w==5 else 7 if w==2 else 30
 var capacity:=clip;var total:=1000;var well:Vector3=Reload.MAG_POINTS[geometry]
 var base:=Vector3(-.3 if left else .3,1.1,-.3)
 var point:=base+well*.65
 var frames:=245 if w==5 else 50
 for index in frames:
  var support:=point;var grip:=false;var eject:=false
  if index>=3 and index<16:
   grip=true
   var draw:=minf(maxf(index-3,0)*.03,.12) if index<9 else maxf(0,.12-(index-9)*.025)
   support+=Vector3.LEFT*draw if w==5 else Vector3.DOWN*draw
  if index==19:eject=true
  if index>=22 and index<=30:
   var pouch:=Vector3(.29 if left else -.29,.965,0)
   support=pouch.lerp(point,clampf((index-24)/6.,0,1));grip=index>=23
  if index>=33 and index<=40:
   support=base+Vector3(.04,.09,.055)*.65+Vector3.UP*.02
   grip=index<40
   support.z+=[0.,0.,.025,.05,.065,.04,.015,0.][index-33]
  var pose:=pose_for(left,support);var c:=command(life,index,w);c.xr=pose;c.vr_device=true;c.reload_grip=grip;c.reload=eject
  check(authority.submit_packet(id,Codec.encode_input(c)),"VR reload command %d/%d/%s"%[w,index,left]);await tick()
  var now:float=authority.metrics().time;var actual:Dictionary=authority.inspect(id)
  var previous_mag:bool=reference.mag;var previous_clip:=clip
  clip=Reload.sample(reference,geometry,clip,total,capacity,pose,grip,eject,now,true,actual.pose_stamp)
  if w==5:Magazines.pack_delay(reference,previous_mag,previous_clip,clip,now,6.6)
  var p:Dictionary=actual.physical[w]
  check(actual.clips[w]==clip,"clip parity %d/%d/%s"%[w,index,left])
  for key in ["mag","ready","locked","grip","eject","pulled","left_pouch","side","carry","carried_rounds","event","stroke","started","removed_depth","anchor","grab"]:
   check(near(p[key],reference[key]),"reload parity %d/%d/%s %s expected=%s got=%s"%[w,index,left,key,str(reference[key]),str(p[key])])
  check(near(p.pack_until,reference.get("pack_until",0.)),"pack arming deadline parity")
 authority.detach_actor(id,life);body.queue_free();await process_frame
func run()->void:
 Engine.physics_ticks_per_second=30
 check(Runtime.available("FPSAuthority"),"native authority available")
 if not failures.is_empty():quit(1);return
 authority=ClassDB.instantiate("FPSAuthority");authority.configure_frames(true);world=Node3D.new();root.add_child(world)
 var floor:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(500,1,500);var collider:=CollisionShape3D.new();collider.shape=shape;floor.position.y=-.5;floor.add_child(collider);world.add_child(floor)
 var rng:=RandomNumberGenerator.new();rng.seed=176042
 for index in 1200:
  var p:Dictionary=Poses.neutral();p.head.origin.y=rng.randf_range(-.1,3.4);p.head.origin.x=rng.randf_range(-.8,.8)
  if index%3==0:p.left.basis=Basis(Vector3.UP,rng.randf_range(-PI,PI))
  if index%7==0:p.weapon.origin.x+=.5
  if index%11==0:p.height=NAN
  if index%13==0:p.head.basis.x*=1.04
  if index%17==0:p.head.basis.x+=p.head.basis.y*.04
  if index%19==0:p["body"]={}
  check(authority.validate_pose(p)==not Poses.validate_reference(p).is_empty(),"typed pose validation parity %d"%index)
 var id:=1
 for w in [2,4,5]:
  for left in [false,true]:await reload_differential(id,w,left);id+=1
 # All five shipped base-model reach profiles must match the existing client solver.
 for model in ["soldier","commando","sgirl","fcommando","boss"]:
  var decoded:Dictionary=Format.read("res://deathmatch/avatars/models/base/"+model+".utavatar")
  check(not decoded.has("error"),"read UT99 reach profile "+model)
  var profile:Dictionary=decoded.manifest.ik_profile
  var who:=make_actor(id,2);var life:int=who[1];var body:CharacterBody3D=who[0]
  check(authority.configure_reach(id,profile),"install native reach profile "+model)
  for index in 60:
   var pose:=pose_for(index%2==1,Vector3(-.4,1.1,-.4));pose.head.basis=Basis.from_euler(Vector3(rng.randf_range(-1.3,1.3),rng.randf_range(-2.8,2.8),rng.randf_range(-1,1)))
   for key in ["left","right"]:pose[key].origin=Vector3(rng.randf_range(-1.1,1.1),rng.randf_range(.6,1.9),rng.randf_range(-.7,.6))
   pose.weapon=pose.left if pose.left_handed else pose.right;pose.weapon.basis=Basis.from_euler(Vector3(.2,index*.01,.1));pose.offhand_weapon=pose.right if pose.left_handed else pose.left
   var c:=command(life,index,2);c.xr=pose;c.vr_device=true
   check(authority.submit_packet(id,Codec.encode_input(c)),"reach sample accepted");await tick()
   var state:Dictionary=authority.inspect(id)
   for offhand in [false,true]:
    var expected:Transform3D=IK.weapon_pose(profile,pose,offhand);var actual:Transform3D=state.offhand_pose if offhand else state.weapon_pose
    check(actual.origin.distance_to(expected.origin)<.00005,"UT99 native hand reach parity %s/%d/%s"%[model,index,offhand])
   var frame:Dictionary=Codec.decode_frame(authority.snapshot());check(not frame.is_empty(),"CQA2 bounded frame decode")
   if frame.has("players") and frame.players.has(id):check(frame.players[id].life==life and not frame.players[id].xr.is_empty(),"CQA2 pose/life roundtrip")
  authority.detach_actor(id,life);body.queue_free();id+=1;await process_frame
 world.queue_free();await process_frame
 print("AUTHORITY_VR_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
