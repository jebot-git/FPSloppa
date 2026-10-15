extends SceneTree
## Geometry suitability audit; does not enable headlights in gameplay.
func _initialize()->void:run.call_deferred()
func percentile(values:Array,ratio:float)->float:
 values.sort();return values[mini(values.size()-1,int(values.size()*ratio))]
func run()->void:
 var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://experimental-assets/jungle/lighting/bake.json"))
 var rows:Array=[]
 for kind in metadata.meshes.size():
  for lod in 2:
   var mesh:ArrayMesh=load(metadata.meshes[kind][lod]);var arrays:Array=mesh.surface_get_arrays(0)
   var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var edges:Array=[];var large:=0
   for i in range(0,indices.size(),3):
    var longest:=0.
    for j in 3:longest=maxf(longest,points[indices[i+j]].distance_to(points[indices[i+(j+1)%3]]))
    edges.append(longest)
    if longest>8.:large+=1
   rows.append({"site":kind,"lod":lod,"triangles":indices.size()/3,"normal_count":0 if arrays[Mesh.ARRAY_NORMAL]==null else arrays[Mesh.ARRAY_NORMAL].size(),"longest_edge_p50_m":percentile(edges,.5),"longest_edge_p95_m":percentile(edges,.95),"max_edge_m":edges[-1],"triangles_over_8m":large})
 # A 12m wall, two triangles: the headlight hits the middle while its vertices
 # all lie outside the cone. Vertex interpolation therefore yields no light.
 var wall:=PackedVector3Array([Vector3(-6,0,-10),Vector3(6,0,-10),Vector3(-6,8,-10),Vector3(6,8,-10)])
 var origin:=Vector3(0,1.2,0);var axis:=Vector3.FORWARD;var outer:=cos(deg_to_rad(22.))
 var vertices_lit:=0
 for p in wall:
  if (p-origin).normalized().dot(axis)>outer:vertices_lit+=1
 var middle_lit:bool=(Vector3(0,1.2,-10)-origin).normalized().dot(axis)>outer
 var tile:float=preload("res://tools/voxel_battle/landscape.gd").TILE
 var report:Dictionary={"surface_rows":rows,"terrain_tile_edge_m":tile,"terrain_vertex_steps_m":[],"coarse_world_vertex_step_m":preload("res://tools/voxel_battle/landscape.gd").EXTENT/128.,"coarse_wall_test":{"wall_size_m":[12,8],"range_m":10,"half_cone_degrees":22,"lit_corner_vertices":vertices_lit,"center_should_be_lit":middle_lit},"scope":"Geometry/coverage feasibility audit only; not GPU timing or an i7 benchmark. No production headlight implementation."}
 for segments in preload("res://tools/streamed_heightfield/stream.gd").SEGMENTS:report.terrain_vertex_steps_m.append(tile/segments)
 var transport=load("res://deathmatch/models/ground_transport/transport.glb").instantiate()
 preload("res://deathmatch/conquest/classes/transport_geometry.gd").prepare_seats(transport)
 report.transport_seats=transport.get_node("OccupantSeats").get_child_count()
 report.entry_text_count=transport.find_children("*","Label3D",true,false).size()
 transport.free()
 DirAccess.make_dir_recursive_absolute("res://test-results/headlight-evaluation")
 FileAccess.open("res://test-results/headlight-evaluation/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("HEADLIGHT_GEOMETRY ",JSON.stringify(report));quit()
