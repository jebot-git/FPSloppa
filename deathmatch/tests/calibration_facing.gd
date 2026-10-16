extends SceneTree
const Preview=preload("res://deathmatch/vr/calibration_preview.gd")
const Body=preload("res://deathmatch/vr/body_basis.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:
 var preview=Preview.new()
 var neutral:Dictionary={"head":Transform3D(Basis.from_euler(Vector3(.3,0,.12)),Vector3(0,1.65,0)),"left":Transform3D(Basis(Vector3.RIGHT,.2),Vector3(-.3,1.1,-.4)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.2,-.5)),"weapon":Transform3D(Basis.IDENTITY,Vector3(.3,1.2,-.7)),"left_handed":true,"height":1.65}
 for yaw in [0.,PI/2.,PI,-PI/2.,.73]:
  var reference:=Transform3D(Basis(Vector3.UP,yaw),Vector3(2.3,0,-1.4))
  var source:=neutral.duplicate()
  for key in source:
   if source[key] is Transform3D:source[key]=reference*source[key]
  var before:=source.duplicate()
  var pose:Dictionary=preview.front_facing_pose(source)
  check(source==before,"preview never mutates tracked source at yaw %s"%yaw)
  check(absf(Body.head_yaw(pose))<.00001,"head faces fixed preview camera at yaw %s"%yaw)
  for key in ["head","left","right","weapon"]:
   check(pose[key].is_equal_approx(neutral[key]),"preserve %s calibration transform at yaw %s"%[key,yaw])
  check(pose.height==neutral.height and pose.left_handed,"preserve scale and handedness")
  var vertical:=source.duplicate();vertical.head=Transform3D(reference.basis*Basis(Vector3.RIGHT,PI/2.),source.head.origin)
  var up:Dictionary=preview.front_facing_pose(vertical)
  check(up.left.is_equal_approx(neutral.left),"vertical gaze retains last facing reference")
 check(preview.front_facing_pose({"height":1.65})=={"height":1.65},"missing tracking is safe")
 preview.free()
 print("CALIBRATION_FACING_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
