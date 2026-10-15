extends SceneTree
const Integrity=preload("res://tools/voxel_battle/structural_integrity.gd")
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Assets=preload("res://tools/voxel_battle/collapse_assets.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 var started:=Time.get_ticks_usec();var layout:=Architecture.new();var meshes:Array=layout.generate();var topology:Dictionary={}
 for index in layout.boxes.size():
  var row:Dictionary=layout.boxes[index]
  if row.size.y<.6 or not (row.size.z<=.3 and row.size.x>=1.2 or row.size.x<=.3 and row.size.z>=1.2):continue
  topology[index]={}
  var bounds:=AABB(row.center-row.size*.5,row.size).grow(.002)
  for lod in 2:
   var arrays:Array=meshes[row.kind][lod].surface_get_arrays(0)
   var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var record:Dictionary={"triangles":PackedInt32Array(),"vertices":PackedInt32Array()}
   for i in range(0,indices.size(),3):
    if bounds.has_point(points[indices[i]]) and bounds.has_point(points[indices[i+1]]) and bounds.has_point(points[indices[i+2]]):
     record.triangles.append(i)
     for j in 3:
      if not indices[i+j] in record.vertices:record.vertices.append(indices[i+j])
   if not record.triangles.is_empty():topology[index][lod]=record
 var structural:=Integrity.new();structural.setup(layout,{},[])
 var buildings:Dictionary={};var animations:Dictionary={}
 var bake:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://experimental-assets/jungle/lighting/bake.json"))
 for id in structural.buildings.size():
  var building:Dictionary=structural.buildings[id];buildings[id]={}
  for lod in 2:
   var arrays:Array=meshes[building.kind][lod].surface_get_arrays(0)
   var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var removed:=PackedInt32Array()
   for i in range(0,indices.size(),3):
    if Integrity.contains_triangle(building,points,indices,i):removed.append(i)
   buildings[id][lod]=removed
  animations[id]=Assets.compact(load(bake.meshes[building.kind][0]),buildings[id][0],building.center)
 var resource:=Resource.new();resource.set_meta("topology",topology);resource.set_meta("buildings",buildings)
 resource.set_meta("animations",animations)
 var hashes:Dictionary={}
 for file in ["tools/voxel_battle/collapse_assets.gd","tools/voxel_battle/structural_integrity.gd","tools/voxel_battle/architecture.gd","tools/voxel_battle/outer_architecture.gd","tools/voxel_battle/light_fixtures.gd","tools/streamed_heightfield/structures.gd","experimental-assets/jungle/lighting/bake.json"]:hashes[file]=FileAccess.get_sha256("res://"+file)
 resource.set_meta("sources",hashes)
 assert(ResourceSaver.save(resource,"res://experimental-assets/destruction/wall_topology.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("DESTRUCTION_TOPOLOGY_BAKED ",JSON.stringify({"walls":topology.size(),"bake_us":Time.get_ticks_usec()-started}));quit()
