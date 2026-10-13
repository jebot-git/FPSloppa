extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const Policy=preload("res://deathmatch/avatars/vertex_lod.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var checks:=0
var failures:Array=[]
var models:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func tick(rig,distance:float,delta:float=.2) -> void:
 rig.position=Vector3(0,0,-distance);rig._process(delta)
func run() -> void:
 var library:=Library.new();root.add_child(library)
 var camera:=Camera3D.new();camera.fov=85;root.add_child(camera);camera.current=true
 for model in ["soldier","commando","sgirl","fcommando","boss"]:
  var hash:=library.register_file("res://deathmatch/avatars/models/base/"+model+".utavatar",false)
  var rig=library.create_avatar(hash);root.add_child(rig);rig.set_process(false)
  var clone=library.create_avatar(hash)
  check(rig.lod_meshes==clone.lod_meshes,model+": shared LOD resources")
  var counts:Array=[];var arrays=rig.lod_meshes[0].surface_get_arrays(0)
  var valid:=true;var decoded:=Format.read(library.entries[hash].path)
  var m:Dictionary=decoded.manifest
  var original_corners:=true
  var full_indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  for corner in full_indices.size():
   var index:=full_indices[corner];var source:Array=m.corners[corner]
   original_corners=original_corners and arrays[Mesh.ARRAY_TEX_UV2][index].x==float(source[0]) and arrays[Mesh.ARRAY_TEX_UV][index]==Vector2(source[1],source[2])
  check(original_corners,model+": full-detail indexing preserves every oriented source corner and UV seam")
  for mesh in rig.lod_meshes:
   var a=mesh.surface_get_arrays(0);counts.append(a[Mesh.ARRAY_INDEX].size()/3)
   for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_CUSTOM0]:valid=valid and a[attribute]==arrays[attribute]
   valid=valid and mesh.custom_aabb==rig.lod_meshes[0].custom_aabb and mesh.surface_get_material(0)==rig.lod_meshes[0].surface_get_material(0)
   for index in a[Mesh.ARRAY_INDEX]:valid=valid and index>=0 and index<a[Mesh.ARRAY_VERTEX].size()
  check(valid,model+": all LOD attributes/material/bounds unchanged and indices valid")
  check(counts[1]<=counts[0]*.55 and counts[2]<=counts[0]*.30,model+": medium/far triangle reduction")
  # Verify every retained animated ID still addresses the exact container sample.
  var frames_ok:=true
  for v in arrays[Mesh.ARRAY_TEX_UV2]:
   var id:=int(v.x);frames_ok=frames_ok and id>=0 and id<int(m.vertices) and v.x==float(id)
   for frame in int(m.frames):
    var offset:=(frame*int(m.vertices)+id)*16
    var p:=Vector3(decoded.positions.decode_float(offset),decoded.positions.decode_float(offset+4),decoded.positions.decode_float(offset+8))
    frames_ok=frames_ok and p.is_finite()
  check(frames_ok,model+": all frames retain valid original vertex-animation addresses")
  rig.target_xr_pose=Poses.neutral();rig.speed=4
  tick(rig,5);check(rig.tracked_arms_active and rig.ik_weight==1 and rig.mesh_tier==0,model+": nearby IK full detail")
  tick(rig,13);check(rig.ik_near,model+": IK exit hysteresis")
  var old_time:float=rig.time
  tick(rig,15,.05);check(not rig.ik_near and rig.ik_weight>0 and rig.ik_weight<1,model+": smooth IK fade")
  tick(rig,15);check(not rig.tracked_arms_active and rig.ik_weight==0 and rig.time>old_time and rig.clip_name.begins_with("Run"),model+": distant animation advances without IK")
  check(not rig.visual.get_instance_shader_parameter("tracked_head") and not rig.visual.get_instance_shader_parameter("tracked_arms"),model+": no stale shader IK")
  tick(rig,11);check(not rig.ik_near,model+": IK entry hysteresis")
  tick(rig,9);check(rig.tracked_arms_active,model+": IK resumes")
  tick(rig,22);check(rig.mesh_tier==1,model+": medium mesh")
  tick(rig,18);check(rig.mesh_tier==1,model+": medium mesh hysteresis")
  tick(rig,55);check(rig.mesh_tier==2 and not rig.tracked_arms_active,model+": far mesh with native animation")
  camera.fov=10;tick(rig,55);check(rig.mesh_tier==0 and rig.tracked_arms_active,model+": scope retains full mesh and IK")
  camera.fov=85;rig.set_first_person(true);tick(rig,100);check(rig.mesh_tier==0 and rig.tracked_arms_active,model+": local avatar protected")
  rig.set_first_person(false);rig.preview_mode=0;tick(rig,100);check(rig.mesh_tier==0 and rig.tracked_arms_active,model+": preview protected")
  rig.preview_mode=-1;rig.dead=true;tick(rig,100,.016);check(rig.ik_weight==0 and rig.clip_name.begins_with("Dead"),model+": death immediately uses native animation")
  rig.dead=false;rig.target_xr_pose={};tick(rig,5);check(rig.ik_weight==0,model+": desktop pose skips IK")
  rig.target_xr_pose=Poses.neutral();rig.mesh_lod_enabled=false;rig.distance_ik_enabled=false;tick(rig,100)
  check(rig.mesh_tier==0 and rig.tracked_arms_active,model+": baseline toggles")
  models.append({"model":model,"triangles":counts,"animation_vertices":m.vertices,"frames":m.frames})
  clone.free();rig.free()
 check(Policy.choose_tier(0,100)==2 and Policy.choose_tier(2,2)==0,"Teleport skips directly to correct tier")
 var xr:=XRCamera3D.new();root.add_child(xr)
 check(absf(Policy.effective_distance(Vector3(0,0,-60),xr)-60)<.001,"XR remote avatars use physical distance")
 xr.free()
 var result:={"checks":checks,"failures":failures,"models":models}
 DirAccess.make_dir_recursive_absolute("res://test-results/ut99-lod")
 var file:=FileAccess.open("res://test-results/ut99-lod/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
 library.free();camera.free();print("UT99_LOD ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
