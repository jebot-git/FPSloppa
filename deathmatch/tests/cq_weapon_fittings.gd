extends SceneTree
const Models=preload("res://deathmatch/conquest/classes/models.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize():run.call_deferred()
func physical_hit(model:Node3D,start:Vector3,end:Vector3)->bool:
 # Scale millimetre-sized faces past Geometry3D's fixed intersection epsilon.
 start*=100.;end*=100.
 for part in model.find_children("*","MeshInstance3D",true,false):
  if not part.mesh or part.name=="AlignedRedDot":continue
  var faces:PackedVector3Array=part.mesh.get_faces();var transform:Transform3D=model.global_transform.affine_inverse()*part.global_transform
  for i in range(0,faces.size(),3):
   var hit=Geometry3D.segment_intersects_triangle(start,end,(transform*faces[i])*100.,(transform*faces[i+1])*100.,(transform*faces[i+2])*100.)
   if hit!=null or Geometry3D.segment_intersects_triangle(start,end,(transform*faces[i+2])*100.,(transform*faces[i+1])*100.,(transform*faces[i])*100.)!=null:return true
 return false
func dimensions(model:Node3D)->Vector3:
 var combined:=AABB();var first:=true
 for part in model.find_children("*","MeshInstance3D",true,false):
  if not part.mesh or part.name=="AlignedRedDot":continue
  var box:AABB=model.global_transform.affine_inverse()*part.global_transform*part.get_aabb();combined=box if first else combined.merge(box);first=false
 return combined.size
func run():
 for pair in [[3,.72*.7],[12,.747*.7],[13,.765*.7]]:
  var id:int=pair[0];var model:=Models.weapon(id,"cq_medic");root.add_child(model)
  check(absf(dimensions(model).z-float(pair[1]))<.005,"SMG %d is authored 30%% smaller without a runtime-only scale hack"%id)
  check(Models.metadata(id,"cq_medic").authored_scale_reduction==.7,"SMG %d records its authored size"%id)
  if id==13:
   check(model.find_child("AlignedRedDot",true,false)==null and Models.metadata(id,"cq_medic").get("aim_laser",false),"T3 retains its modeled laser projector")
  else:
   check(model.find_child("AlignedRedDot",true,false)!=null and not Models.metadata(id,"cq_medic").get("aim_laser",false),"T1/T2 have functional red dots instead of laser projectors")
   var aperture:=Models.anchor(id,"red_dot_position")
   check(not physical_hit(model,aperture+Vector3.BACK*.03,aperture+Vector3.FORWARD*.1),"SMG %d sight aperture is optically open"%id)
   for side in [-1,1]:
    var frame_found:=false
    for step in range(1,41):
     var edge:=Vector3(side*step*.001,0,0)
     if physical_hit(model,aperture+edge+Vector3.BACK*.03,aperture+edge+Vector3.FORWARD*.1):frame_found=true;break
    check(frame_found,"SMG %d red-dot frame keeps both authored sides (%d)"%[id,side])
  model.free()
 var model:=Models.weapon(8,"cq_scout");root.add_child(model)
 var sight:=Models.anchor(8,"red_dot_position")
 check(not physical_hit(model,sight+Vector3.BACK*.03,sight+Vector3.FORWARD*.05),"Designator sight centre is a real opening, not opaque glass")
 check(physical_hit(model,sight+Vector3(.023,0,.03),sight+Vector3(.023,0,-.05)),"Designator opaque frame remains around the opening")
 check(model.get_node("AlignedRedDot").material_override is ShaderMaterial,"Designator reticle preserves the transparent collimated shader")
 model.free()
 check(Models.anchor(5,"support_anchor").is_equal_approx(Vector3(0,-.065,-.555)),"Massacre grab point is on the frontal bottom handle")
 check(Models.anchor(15,"support_anchor").is_equal_approx(Vector3(0,.082,-.553)),"Minigun grab point is at the transverse carry handle")
 print("CQ_WEAPON_FITTINGS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
