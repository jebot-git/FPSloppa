extends SceneTree
const Cover=preload("res://tools/voxel_battle/rock_cover.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize()->void:run.call_deferred()
func run()->void:
 Landscape.prepare_roads()
 var cover:=Cover.new();root.add_child(cover);cover.setup(true,true)
 for path in cover.metadata.sources:check(FileAccess.get_sha256(path)==cover.metadata.sources[path],"Bake source current: "+path)
 check(cover.rows.size()<400,"Sparse world rock budget")
 check(cover.rows.filter(func(row):return row.tag=="river").size()>=3,"Occasional in-river cover")
 check(cover.collision_count==cover.rows.filter(func(row):return int(row.asset)<10).size(),"All cover has collision")
 for row in cover.rows:
  var p:=Vector2(row.position[0],row.position[2]);var radius:=float(row.radius)
  for i in Landscape.CENTERS.size():check(maxf(absf(p.x-Landscape.CENTERS[i].x),absf(p.y-Landscape.CENTERS[i].z))>Landscape.RADII[i]+radius+22,"Clear site/spawn/capture/structure footprint")
  if row.tag=="river":
   var water:=Landscape.water_sample(p.x,p.y)
   check(water.x>.95 and row.position[1]+row.height>water.y+.5,"River cover emerges above surface")
   check(radius<4,"Channel remains passable around river rocks")
  else:check(Landscape.water_mask(p.x,p.y)<.01,"Dry rocks remain outside water")
  for road in Landscape.main_roads+Landscape.access_roads:
   var a:=Vector2(road.a.x,road.a.z);var b:=Vector2(road.b.x,road.b.z)
   var t:=clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
   check(p.distance_to(a.lerp(b,t))>=road.width+radius+7,"Clear road, shoulder and crossing")
 for i in cover.meshes.size():
  var mesh:Mesh=cover.meshes[i];var spec:Dictionary=cover.metadata.assets[i]
  check(mesh.get_surface_count()==1,"One atlas surface")
  check(mesh.surface_get_material(0)==cover.meshes[0].surface_get_material(0),"All meshes share one cached material")
  check(spec.lod_triangles.size()>=3,"Reduced mesh LODs exist")
  check(spec.lod_triangles.back()<spec.lod_triangles[0]*.5,"Far LOD reduces geometry")
  if cover.shapes[i]:
   check(cover.navigation_faces[i].size()>0 and cover.navigation_faces[i].size()%3==0,"Navigation hull has triangle faces")
 for group in cover.groups:
  check(group.visibility_range_end==Cover.VIEW_DISTANCE,"Bounded native visibility")
  check(group.get_aabb().size.x<90 and group.get_aabb().size.z<90,"Spatial MultiMesh bounds")
 await physics_frame;await physics_frame
 var row:Dictionary=cover.rows.filter(func(r):return int(r.asset)<10 and r.height>2)[0]
 var center:=Vector3(row.position[0],row.position[1]+row.height*.45,row.position[2]);var query:=PhysicsRayQueryParameters3D.create(center-Vector3(15,0,0),center+Vector3(15,0,0))
 var hit:=root.world_3d.direct_space_state.intersect_ray(query)
 check(not hit.is_empty(),"Rock cover blocks weapon/LOS ray")
 var data:=NavigationMeshSourceGeometryData3D.new();cover.navigation_source(data,AABB(center-Vector3.ONE*20,Vector3.ONE*40))
 check(data.get_vertices().size()>0 and data.get_indices().size()>0,"Navigation receives cover geometry")
 print("ROCK_COVER_VALIDATION ",JSON.stringify({"checks":checks,"failures":failures,"rocks":cover.rows.size(),"formations":cover.metadata.formations.size(),"colliders":cover.collision_count,"batches":cover.groups.size()}));quit(0 if failures.is_empty() else 1)
