extends SceneTree
## Clip the navigation bake at the rotational seam and mirror its topology.
## Both sides then use identical polygons, avoiding Recast triangulation bias.
func _initialize():run.call_deferred()
func run() -> void:
 var level=preload("res://deathmatch/maps/loader.gd").read("res://maps/tf_pressureworks.bsp")
 assert(level!=null)
 root.add_child(level)
 var mesh=preload("res://deathmatch/bots.gd").new_mesh()
 var data:=NavigationMeshSourceGeometryData3D.new()
 NavigationServer3D.parse_source_geometry_data(mesh,data,level)
 NavigationServer3D.bake_from_source_geometry_data(mesh,data)
 var old: PackedVector3Array=mesh.vertices
 var vertices:=PackedVector3Array();var lookup: Dictionary={};var polygons: Array=[]
 for i in mesh.get_polygon_count():
  var input: Array=[]
  for index in mesh.get_polygon(i):input.append(old[index])
  var clipped: Array=[]
  for j in input.size():
   var p: Vector3=input[j];var q: Vector3=input[(j+1)%input.size()]
   if p.z>=0:clipped.append(p)
   if (p.z>=0)!=(q.z>=0):
    var at: Vector3=p.lerp(q,-p.z/(q.z-p.z));at.z=0;clipped.append(at)
  if clipped.size()<3:continue
  var area:=Vector3.ZERO
  for j in clipped.size():area+=clipped[j].cross(clipped[(j+1)%clipped.size()])
  if area.length()<.0001:continue
  for side in [1,-1]:
   var indices:=PackedInt32Array()
   for point in clipped:
    var v: Vector3=point*Vector3(side,1,side)
    var key: String="%d,%d,%d"%[roundi(v.x*10000),roundi(v.y*10000),roundi(v.z*10000)]
    if not lookup.has(key):lookup[key]=vertices.size();vertices.append(v)
    var index: int=lookup[key]
    if indices.is_empty() or indices[-1]!=index:indices.append(index)
   if indices.size()>1 and indices[0]==indices[-1]:indices.resize(indices.size()-1)
   if indices.size()>=3:polygons.append(indices)
 # Split seam edges at the union of both halves' vertices. Otherwise clipped
 # polygons create T-junctions and Godot sees disconnected navigation islands.
 var seam: Array=[]
 for index in vertices.size():
  if absf(vertices[index].z)<.00001:seam.append(index)
 mesh.clear_polygons();mesh.vertices=vertices
 for polygon in polygons:
  var split:=PackedInt32Array()
  for j in polygon.size():
   var start: int=polygon[j];var end: int=polygon[(j+1)%polygon.size()]
   split.append(start)
   var p:=vertices[start];var v:=vertices[end]-p
   if absf(p.z)>.00001 or absf(vertices[end].z)>.00001:continue
   var interior: Array=[]
   for index in seam:
    var t: float=(vertices[index]-p).dot(v)/v.length_squared()
    if t>.00001 and t<.99999 and (p+v*t).distance_to(vertices[index])<.0001:interior.append([t,index])
   interior.sort_custom(func(a,b):return a[0]<b[0])
   for item in interior:split.append(item[1])
  mesh.add_polygon(split)
 assert(ResourceSaver.save(mesh,"res://maps/navigation/tf_pressureworks.res")==OK)
 FileAccess.open("res://maps/Pressureworks/navigation-sha256.txt",FileAccess.WRITE).store_string(FileAccess.get_sha256("res://maps/tf_pressureworks.bsp")+"\n")
 print("PRESSUREWORKS_NAV polygons=",mesh.get_polygon_count()," vertices=",vertices.size())
 level.free();quit()
