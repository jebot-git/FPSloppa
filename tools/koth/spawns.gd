extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.set_process(false)
 var report={}
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://tools/koth/recipes.json")):
  g._load_map(row.id);g.match_mode.kind="koth";g.match_mode.reset()
  var hill: Vector3=g.match_mode.hill
  var region:=NavigationRegion3D.new();g.add_child(region);var mesh: NavigationMesh=load("res://maps/navigation/"+row.id+".res");region.navigation_mesh=mesh
  for i in 12:await physics_frame
  var nav: RID=region.get_navigation_map();var space=g.get_world_3d().direct_space_state;var target=NavigationServer3D.map_get_closest_point(nav,hill);var candidates=[];var verts=mesh.vertices
  for i in mesh.get_polygon_count():
   var poly=mesh.get_polygon(i);var p=Vector3.ZERO
   for j in poly:p+=verts[j]
   p/=poly.size()
   if p.distance_to(hill)<12 or p.distance_to(hill)>32:continue
   var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.5,p-Vector3.UP*1.0,1))
   if hit.is_empty() or hit.normal.y<.99:continue
   p=hit.position+Vector3.UP*.05
   var shape=CapsuleShape3D.new();shape.radius=.48;shape.height=1.8
   var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis(),p+Vector3.UP*.92);q.collision_mask=1
   if not space.intersect_shape(q,1).is_empty():continue
   var path=NavigationServer3D.map_get_path(nav,p,target,true)
   if path.is_empty() or path[-1].distance_to(target)>.5:continue
   var length=0.0
   for j in range(1,path.size()):length+=path[j-1].distance_to(path[j])
   if length<16 or length>38:continue
   candidates.append({"p":p,"distance":length})
  candidates.sort_custom(func(a,b):return abs(a.distance-24)<abs(b.distance-24))
  var chosen=[]
  for c in candidates:
   if chosen.any(func(other):return other.p.distance_to(c.p)<5):continue
   chosen.append(c)
   if chosen.size()==12:break
  chosen.sort_custom(func(a,b):return a.distance<b.distance)
  var points=[]
  for c in chosen:
   var p:Vector3=c.p;points.append([-p.z*32/1.5,-p.x*32/1.5,(p.y+.7)*32])
  print(row.id," SPAWNS ",chosen.size()," ROUTES ",chosen.map(func(c):return snappedf(c.distance,.1)))
  report[row.id]=points
  region.free()
 FileAccess.open("res://tools/koth/spawns.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 g.free();quit()
