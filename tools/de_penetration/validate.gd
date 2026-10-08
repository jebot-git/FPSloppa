extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Pen=preload("res://deathmatch/counterstrike/penetration.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 if not ok:failures.append(label);push_error(label)
func run():
 var reports: Array=[]
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")):
  if not row.id.begins_with("de_varq_"):continue
  var args:=OS.get_cmdline_user_args()
  if not args.is_empty() and row.id!=args[0]:continue
  var packed:=Loader.scene(row);var level:=packed.instantiate();root.add_child(level)
  var pen:=Pen.new();check(pen.open(row.path,level),"Missing BSP cover: "+row.id)
  if not pen.ready:level.free();continue
  await physics_frame;await physics_frame
  var cover=pen.bsp_cover;var space:=root.get_world_3d().direct_space_state;var tested:=0;var passed:=0;var blocked:=0;var samples: Array=[];var by_material: Dictionary={};var max_queries:=0;var max_us:=0
  for model in cover.models:
   var first:=int(model.faces[0]);var last:=first+int(model.faces[1]);var model_samples:=0
   for i in range(first,last):
    if model_samples>=1600:break
    var face: Dictionary=cover.faces[i];var center:=Vector3.ZERO
    for p in face.polygon:center+=p
    center/=face.polygon.size();center+=model.node.global_position
    var normal: Vector3=cover.planes[face.plane].normal*(1 if face.side==0 else -1)
    var entry: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*.04,center-normal*.04,1))
    if entry.is_empty() or entry.position.distance_to(center)>.015:continue
    tested+=1;model_samples+=1
    var before:=Time.get_ticks_usec();var passage:=pen.exit_surface(entry.position,-normal,45./32,space);max_us=maxi(max_us,Time.get_ticks_usec()-before);max_queries=maxi(max_queries,pen.queries)
    if passage.is_empty():blocked+=1;continue
    passed+=1;by_material[face.material]=int(by_material.get(face.material,0))+1
    check(passage.thickness>0 and passage.cost>=passage.thickness-.0001 and passage.retention>0 and passage.retention<=.6,"Invalid resistance: "+row.id)
    var reverse_query:=PhysicsRayQueryParameters3D.create(passage.position,entry.position+normal*.05,1);reverse_query.hit_from_inside=true
    var reverse: Dictionary=space.intersect_ray(reverse_query)
    check(not reverse.is_empty() and reverse.position.distance_to(passage.position)<.012,"Missing real back surface: "+row.id)
    check(pen.exit_surface(entry.position,-normal,float(passage.cost)*.5,space).is_empty(),"Insufficient power passed: "+row.id)
    if samples.size()<16:samples.append({"entry":[entry.position.x,entry.position.y,entry.position.z],"direction":[-normal.x,-normal.y,-normal.z],"role":face.material,"thickness":passage.thickness,"cost":passage.cost,"retention":passage.retention})
  check(tested>20,"Insufficient actual cover probes: "+row.id)
  reports.append({"id":row.id,"bsp_sha256":row.sha256,"profile_sha256":FileAccess.get_sha256("res://deathmatch/maps/penetration/"+row.id+".json"),"tested":tested,"penetrated":passed,"blocked":blocked,"by_material":by_material,"bound_models":cover.models.size(),"max_node_visits":max_queries,"max_query_us":max_us,"samples":samples})
  print("BSP_PENETRATION_MAP ",JSON.stringify(reports[-1]));level.free();pen=null;packed=null;await process_frame
 var result:={"maps":reports,"failures":failures}
 var suffix:="" if OS.get_cmdline_user_args().is_empty() else "-"+OS.get_cmdline_user_args()[0]
 FileAccess.open("res://tools/de_penetration/validation"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("BSP_PENETRATION_RESULT ",reports.size()," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
