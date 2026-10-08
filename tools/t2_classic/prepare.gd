extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Builder=preload("res://tools/lighting_experiment/build_static_assets.gd")
func _initialize():run.call_deferred()
func run():
 var args:=OS.get_cmdline_user_args();var helper:=Builder.new()
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
 for row in rows:
  if args.is_empty() and not str(row.id).begins_with("ctf_t2_") or not args.is_empty() and row.id not in args:continue
  var level:=Loader.read(row.path)
  assert(level!=null,Loader.validate(row.path))
  assert(level.get_meta("baked_light_invalid_faces",0)==0,"Invalid lightmap faces")
  assert(level.get_meta("baked_light_overflow_faces",0)==0,"Lightmap atlas overflow")
  Filtering.new().apply(level,2,true)
  var path: String="res://maps/cache/"+row.id+"-lightmap1.scn"
  helper.save(level,path);assert(DirAccess.copy_absolute(path,row.scene)==OK)
  var alias:=path.get_basename()+"-textures-"+preload("res://deathmatch/maps/texture_replacements/dictionary.gd").version()+".scn"
  assert(DirAccess.copy_absolute(path,alias)==OK)
  root.add_child(level)
  var fixtures=preload("res://deathmatch/tribes/stations.gd").new();level.add_child(fixtures)
  for node in level.find_children("*","Node3D",true,false):
   if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","") in ["info_tribes_inventory","info_tribes_ammo"]:
    fixtures.fixture({"position":node.global_position-Vector3.UP*.7},deg_to_rad(float(node.attributes.get("angle",0))))
  var mesh=preload("res://deathmatch/bots.gd").new_mesh()
  var lo: Array=[];var hi: Array=[]
  for node in level.find_children("*","Node3D",true,false):
   if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","")=="info_playable_bounds":
    var size: PackedFloat64Array=str(node.attributes.size).split_floats(" ",false)
    var half:=Vector3(size[0],size[1],size[2])*.5;var center: Vector3=node.global_position-Vector3.UP*.7
    var a:=center-half;var b:=center+half;lo=[a.x,a.y,a.z];hi=[b.x,b.y,b.z]
  assert(lo.size()==3,"Missing map boundary")
  mesh.filter_baking_aabb=AABB(Vector3(lo[0],lo[1],lo[2]),Vector3(hi[0]-lo[0],hi[1]-lo[1],hi[2]-lo[2]))
  mesh.cell_size=.8;mesh.cell_height=.2;mesh.agent_radius=.8;mesh.agent_height=1.8;mesh.agent_max_climb=.4
  mesh.set_meta("merge_rasterizer_cell_scale",.01)
  var geometry:=NavigationMeshSourceGeometryData3D.new()
  NavigationServer3D.parse_source_geometry_data(mesh,geometry,level)
  var cleanup: Dictionary={};var attempts: Array=[]
  for partition in [NavigationMesh.SAMPLE_PARTITION_WATERSHED,NavigationMesh.SAMPLE_PARTITION_MONOTONE,NavigationMesh.SAMPLE_PARTITION_LAYERS]:
   mesh.sample_partition_type=partition
   NavigationServer3D.bake_from_source_geometry_data(mesh,geometry)
   if mesh.get_polygon_count()==0:continue
   cleanup=preload("res://tools/raindance/navigation_cleanup.gd").clean(mesh)
   var removed: int=cleanup.removed_redundant_polygons
   for retry in 16:
    if cleanup.unresolved_edges!=-1:break
    cleanup=preload("res://tools/raindance/navigation_cleanup.gd").clean(mesh);removed+=int(cleanup.removed_redundant_polygons)
   cleanup.removed_redundant_polygons=removed
   attempts.append({"partition":partition,"cleanup":cleanup.duplicate()})
   if cleanup.unresolved_edges==0:break
  if cleanup.get("unresolved_edges",-1)!=0:
   push_error("Overlapping navigation: "+JSON.stringify(attempts));level.free();helper.free();quit(1);return
  assert(ResourceSaver.save(mesh,"res://maps/navigation/"+row.id+".res",ResourceSaver.FLAG_COMPRESS)==OK)
  var report:={"id":row.id,"bsp_sha256":FileAccess.get_sha256(row.path),"navigation_polygons":mesh.get_polygon_count(),"navigation_cleanup":cleanup,"navigation_attempts":attempts,"lightmap_faces":level.get_meta("baked_light_faces",0),"lightmap_packing":level.get_meta("lightmap_packing",{}),"raw_scene":path}
  DirAccess.make_dir_recursive_absolute("res://test-results/t2-classic/"+row.id)
  FileAccess.open("res://test-results/t2-classic/"+row.id+"/prepare.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
  print("CLASSIC_PREPARE ",JSON.stringify(report));level.free();await process_frame
 helper.free();quit()
