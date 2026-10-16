extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const Batch=preload("res://deathmatch/avatars/native_batch.gd")
var checks:=0
var failures:Array=[]
var max_error:=0.0
var tracked_frames:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func compare(a,b,label:String)->void:
 if a is Vector3 and b is Vector3:max_error=maxf(max_error,a.distance_to(b));check(a.distance_to(b)<.0001,label)
 elif a is Vector4 and b is Vector4:check(a.distance_to(b)<.0001,label)
 elif a is Transform3D and b is Transform3D:
  max_error=maxf(max_error,a.origin.distance_to(b.origin))
  check(a.origin.distance_to(b.origin)<.0001 and a.basis.is_equal_approx(b.basis),label)
 elif a is float or b is float:check(absf(float(a)-float(b))<.0001,label)
 else:check(a==b,label)
static func foreign_update(kernel,rig,clips:Array,profile:Dictionary,lods:Array,result:Dictionary)->void:
 result.advanced=kernel.advance_one(rig,.1,null)
 result.configured=kernel.configure(rig,clips,profile,lods)
 result.metrics=kernel.metrics()
func _initialize()->void:run.call_deferred()
func run()->void:
 var library:=Library.new();root.add_child(library)
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,1.7,0);camera.make_current()
 for model in ["soldier","commando","sgirl","fcommando","boss"]:
  var hash:=library.register_file("res://deathmatch/avatars/models/base/"+model+".utavatar",false)
  var reference=library.create_avatar(hash);root.add_child(reference);reference.set_process(false)
  if reference.native_animation:reference.native_animation.detach(reference)
  reference.native_animation=null
  var actual=library.create_avatar(hash);root.add_child(actual);actual.set_process(false)
  check(actual.native_bound,"native profile configured "+model)
  for rig in [reference,actual]:rig.set_weapon(1,"cq_shocktroop");rig.set_equipment("jetpack")
  for frame in 90:
   camera.projection=Camera3D.PROJECTION_ORTHOGONAL if frame%19==0 else Camera3D.PROJECTION_PERSPECTIVE
   camera.fov=65 if frame%2 else 105;camera.size=40 if frame%3 else 10
   var yaw:float=sin(frame*.3)*2.9;var turn:=Transform3D(Basis(Vector3.UP,yaw),Vector3.ZERO)
   var pose:Dictionary={"head":turn*Transform3D(Basis.from_euler(Vector3(.5*sin(frame),.2,.1)),Vector3(0,1.65,0)),"left":turn*Transform3D(Basis.IDENTITY,Vector3(-.3,1.2,-.4)),"right":turn*Transform3D(Basis.IDENTITY,Vector3(.3,1.3,-.6)),"weapon":turn*Transform3D(Basis.IDENTITY,Vector3(.3,1.3,-.6)),"left_handed":frame%2==0}
   if frame%11==0:pose={}
   elif frame%7==0:pose.erase("left");pose.erase("right")
   for rig in [reference,actual]:
    rig.seated_bike=frame%9<3;rig.seated_heading=.3*sin(frame*.3);rig.target_xr_pose=pose;rig.dead=frame%17>=14;rig.speed=[0.,.5,6.][frame%3];rig.grounded=frame%9<6;rig.stance=["stand","crouch","prone"][frame%3];rig.preview_mode=[-1,0,1,2,3][frame%5];rig.selected_sequence="Taunt1" if frame%13==0 else "";rig.position=Vector3(0,0,-float(frame%55));rig.aim_pitch=.4*sin(frame*.7)
    if frame%9==0:rig.fire()
   reference._process(.02);actual.advance_animation(.02)
   check(actual.native_animation.metrics().updated==1,"native path advances without fallback")
   if actual.tracked_arms_active:tracked_frames+=1
   for key in ["tracking_yaw","rotation","left_handed","firing","death_time","clip_name","time","animation_frames","effective_distance","ik_near","ik_weight","mesh_tier","tracked_arms_active","ik_uniforms_active"]:compare(actual.get(key),reference.get(key),model+" "+str(frame)+" "+key)
   compare(actual.visual.transform,reference.visual.transform,"body transform")
   compare(actual.gun.transform,reference.gun.transform,"gun attachment")
   compare(actual.carried_radio.transform,reference.carried_radio.transform,"radio attachment")
   compare(actual.carried_utility.transform,reference.carried_utility.transform,"utility attachment")
   if DisplayServer.get_name()!="headless":
    for key in ["animation_frames","ik_weight","tracked_arms","tracked_head","neck_q","neck_t","head_q","head_t","left_upper_q","left_upper_t","left_fore_q","left_fore_t","right_upper_q","right_upper_t","right_fore_q","right_fore_t"]:
     compare(actual.visual.get_instance_shader_parameter(key),reference.visual.get_instance_shader_parameter(key),"rendered shader parameter "+key)
   check(actual.solved_arms.keys()==reference.solved_arms.keys(),"IK activation parity")
   for side in reference.solved_arms:
    for key in reference.solved_arms[side]:compare(actual.solved_arms[side][key],reference.solved_arms[side][key],"constrained arm "+side+" "+key)
  reference.free();actual.free()
 check(tracked_frames>50,"tracked IK exercised across all avatars")
 # Exercise the gameplay manager, shared metadata and removal while paused.
 var hash:=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false)
 var a=library.create_avatar(hash);var b=library.create_avatar(hash);root.add_child(a);root.add_child(b)
 Batch.attach(a);Batch.attach(b)
 check(a.native_batched and a.native_animation==b.native_animation,"gameplay rigs share native batch")
 var kernel=a.native_animation
 check(kernel.metrics().registered==2 and kernel.metrics().models==1,"one cached model for two actors")
 a.set_process(false);b.set_process(false)
 check(kernel.advance(.1,camera)==0,"paused rigs skipped by native batch")
 a.set_process(true);b.set_process(true)
 var before:float=a.time
 check(kernel.advance(.1,camera)==2 and a.time>before,"single native call advances both gameplay rigs")
 var xr:=XRCamera3D.new();root.add_child(xr);xr.position=Vector3(70,2,0);xr.fov=30
 kernel.advance_one(a,.1,xr)
 check(absf(a.effective_distance-a.global_position.distance_to(xr.global_position))<.0001,"XR LOD uses physical distance independently of desktop FOV")
 xr.free()
 a.process_mode=Node.PROCESS_MODE_DISABLED;var hidden_before:float=a.time
 a.advance_animation(.1)
 check(a.time>hidden_before,"explicit update refreshes hidden local avatar outside automatic batch")
 a.process_mode=Node.PROCESS_MODE_INHERIT
 var rejected:Dictionary={};var before_foreign:float=a.time
 var task:=WorkerThreadPool.add_task(foreign_update.bind(kernel,a,a.clips,a.arm_profile,a.lod_meshes,rejected))
 WorkerThreadPool.wait_for_task_completion(task)
 check(not rejected.advanced and not rejected.configured and rejected.metrics.is_empty() and a.time==before_foreign,"worker cannot touch animation scene state")
 paused=true;a.process_mode=Node.PROCESS_MODE_ALWAYS
 check(kernel.advance(.1,camera)==1,"batch respects each avatar pause mode")
 paused=false;a.process_mode=Node.PROCESS_MODE_INHERIT
 a.free();check(kernel.metrics().registered==1,"free unregisters rig without retaining its scene")
 root.remove_child(b);check(kernel.metrics().registered==0,"detached rig retired")
 root.add_child(b);await process_frame;await process_frame
 check(kernel.metrics().registered==1 and b.native_batched,"reparent automatically re-registers same batch safely")
 b.free();check(kernel.metrics().registered==0 and kernel.metrics().models==0,"last actor releases native model cache")
 var fighter=load("res://deathmatch/fighter.gd").new();root.add_child(fighter);fighter.set_process(false);fighter.setup(77,"Batch integration",Color.WHITE)
 fighter.set_avatar(library.create_avatar(hash),hash);fighter.avatar.speed=6
 await process_frame;await process_frame
 check(fighter.avatar.native_batched and kernel.metrics().registered==1,"fighter asset installation joins animation batch after loading")
 check(fighter.avatar.clip_name.begins_with("Run"),"gameplay batch consumes current fighter animation state")
 fighter.free();check(kernel.metrics().registered==0,"fighter teardown unregisters its avatar")
 var viewport:=SubViewport.new();viewport.size=Vector2i(64,64);root.add_child(viewport)
 var nested=library.create_avatar(hash);viewport.add_child(nested);Batch.attach(nested)
 check(nested.native_animation!=kernel and viewport.has_node("NativeAvatarBatch"),"subviewport owns a separate camera batch")
 viewport.free()
 library.free();camera.free()
 print("CQ_NATIVE_ANIMATION ",JSON.stringify({"checks":checks,"failures":failures,"max_position_error":max_error}));quit(0 if failures.is_empty() else 1)
