extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args()
 var doc=GLTFDocument.new();var state=GLTFState.new()
 var err=doc.append_from_file(args[0],state)
 if err!=OK:push_error("BA2 glTF load failed: "+str(err));quit(1);return
 var model=doc.generate_scene(state)
 root.add_child(model)
 var player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
 var skeleton: Skeleton3D
 for n in model.find_children("*","Skeleton3D",true,false):skeleton=n;break
 if not player or not skeleton:push_error("Missing animation player or skeleton");quit(1);return
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var report={"engine":Engine.get_version_info().string,"bones":skeleton.get_bone_count(),"clips":{},"root_displacement_m":0.0,"failures":failures}
 for name in ["WalkStart","WalkLoop","TurretSweep","RoutePreview"]:
  if not player.has_animation(name):failures.append("Missing "+name);continue
  var a=player.get_animation(name);var paths=[]
  var durations={"WalkStart":6.6,"WalkLoop":5.6,"TurretSweep":16.,"RoutePreview":17.8}
  if abs(a.length-durations[name])>.0001:failures.append("Wrong clip duration: "+name)
  for i in a.get_track_count():paths.append(str(a.track_get_path(i)))
  report.clips[name]={"length":a.length,"tracks":paths}
  if name in ["WalkStart","WalkLoop"] and paths.any(func(p):return "Cannon" in p):failures.append("Walk contains cannon tracks")
  if name=="TurretSweep" and paths.any(func(p):return "Leg" in p):failures.append("Turret clip contains leg tracks")
  player.play(name);player.seek(0,true);player.advance(0)
  for t in [0.,a.length*.25,a.length*.5,a.length*.75,a.length]:
   player.seek(t,true);player.advance(0);skeleton.force_update_all_bone_transforms()
   for i in skeleton.get_bone_count():
    if not skeleton.get_bone_global_pose(i).is_finite():failures.append("Non-finite pose")
 var index=skeleton.find_bone("Root")
 if index<0:failures.append("Missing Root bone")
 else:
  player.play("RoutePreview");player.seek(0,true);player.advance(0);skeleton.force_update_all_bone_transforms()
  var p0=skeleton.global_transform*skeleton.get_bone_global_pose(index).origin
  player.seek(player.get_animation("RoutePreview").length,true);player.advance(0);skeleton.force_update_all_bone_transforms()
  var p1=skeleton.global_transform*skeleton.get_bone_global_pose(index).origin
  report.root_displacement_m=p0.distance_to(p1)
  if abs(report.root_displacement_m-7.56)>.005:failures.append("Root motion scale mismatch")
 if args.size()>3:
  var glb=JSON.parse_string(FileAccess.get_file_as_string(args[2]))
  var baked=JSON.parse_string(FileAccess.get_file_as_string(args[3]))
  var maximum=0.0
  var cannon_off_axis=0.0;var body_off_axis=0.0;var body_yaw=0.0
  player.play("RoutePreview")
  for sample in baked.samples:
   player.seek(sample.t,true);player.advance(0);skeleton.force_update_all_bone_transforms()
   for foot in sample.feet:
    var landmark=glb.toes[foot.leg];var local=landmark.bone_local
    var point=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(landmark.bone))*Vector3(local[0],local[1],local[2])
    var expected=Vector3(foot.toe[0],foot.toe[2],-foot.toe[1])
    maximum=max(maximum,point.distance_to(expected))
   for bone in ["Cannon.L","Cannon.R","Body"]:
    var bi=skeleton.find_bone(bone)
    var relative=skeleton.get_bone_rest(bi).basis.inverse()*Basis(skeleton.get_bone_pose_rotation(bi))
    var e=relative.get_euler()
    if bone=="Body":
     body_yaw=max(body_yaw,abs(rad_to_deg(e.y)))
     body_off_axis=max(body_off_axis,max(abs(rad_to_deg(e.x)),abs(rad_to_deg(e.z))))
    else:cannon_off_axis=max(cannon_off_axis,max(abs(rad_to_deg(e.y)),abs(rad_to_deg(e.z))))
  report.exported_toe_max_error_m=maximum
  report.cannon_non_x_degrees=cannon_off_axis;report.body_non_yaw_degrees=body_off_axis;report.body_yaw_degrees=body_yaw
  if maximum>.003:failures.append("Exported toe differs from authored contact")
  if cannon_off_axis>.001 or body_off_axis>.001 or body_yaw>3.001:failures.append("Axis limits differ after export")
 var f=FileAccess.open(args[1],FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("BA2_GODOT_ANIMATION_CHECKS ",JSON.stringify(report))
 model.free();quit(0 if failures.is_empty() else 1)
