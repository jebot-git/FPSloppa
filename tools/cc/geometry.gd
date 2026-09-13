extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func stats(path: String) -> Dictionary:
 var level=load(path).instantiate();var result={"nodes":0,"triangles":0,"meshes":0}
 result.nodes=level.find_children("*","",true,false).size()
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:result.meshes+=1;result.triangles+=node.mesh.get_faces().size()/3
 level.free();return result
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false);var results=[]
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://tools/cc/recipes.json")):
  var before=stats("res://optional-librequake/maps/cache/"+row.source+".scn");var after=stats("res://maps/cache/"+row.id+".scn")
  g._load_map(row.id)
  var region=NavigationRegion3D.new();g.add_child(region);var mesh:NavigationMesh=load("res://maps/navigation/"+row.id+".res");region.navigation_mesh=mesh
  var nav:RID=region.get_navigation_map();NavigationServer3D.map_set_cell_size(nav,mesh.cell_size)
  NavigationServer3D.map_set_merge_rasterizer_cell_scale(nav,mesh.get_meta("merge_rasterizer_cell_scale",1.0))
  for i in 12:await physics_frame
  var floor_space=g.get_world_3d().direct_space_state;var positions=g.spawn_points.duplicate();var longest=0.0
  check(positions.size()>=16,row.id+" has at least sixteen starts")
  check(g.pickups.is_empty(),row.id+" contains no inert CC pickups")
  for pos in positions:
   var shape=CapsuleShape3D.new();shape.radius=.4;shape.height=1.7;var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=pos+Vector3.UP*.87;query.collision_mask=1
   var hit=floor_space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.15,pos-Vector3.UP*.3,1))
   check(not hit.is_empty() and floor_space.intersect_shape(query,1).is_empty(),row.id+" clear grounded spawn "+str(pos))
   check(g.get_node("Map/MapRuntime").contents.at(pos+Vector3.UP*.75)==-1,row.id+" spawn is dry")
   for other in positions:
    var path=NavigationServer3D.map_get_path(nav,pos,other,true)
    var reached=not path.is_empty() and path[-1].distance_to(other)<.9
    if not reached:check(false,row.id+" incomplete spawn-to-spawn route")
    var length=0.0
    for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
    longest=maxf(longest,length)
  check(longest<=55,row.id+" longest spawn route is under 55m ("+str(snappedf(longest,.1))+"m)")
  results.append({"id":row.id,"before":before,"after":after,"longest_spawn_path":longest,"spawns":positions.size()});region.free()
 FileAccess.open("res://test-results/cc/geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":results,"failures":failures},"  "))
 g.free();print("CC_GEOMETRY_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
