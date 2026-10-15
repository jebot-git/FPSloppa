extends SceneTree
## Offline 2D Voronoi clipping extruded to a solid slab. Original CC0 fixture.
const OUTPUT:="res://experimental-assets/destruction/wall_shards.tscn"
func clip(poly:PackedVector2Array,normal:Vector2,offset:float)->PackedVector2Array:
 var out:=PackedVector2Array()
 for i in poly.size():
  var a:Vector2=poly[i];var b:Vector2=poly[(i+1)%poly.size()]
  var da:float=a.dot(normal)-offset;var db:float=b.dot(normal)-offset
  if da<=0:out.append(a)
  if (da<0 and db>0) or (da>0 and db<0):out.append(a.lerp(b,da/(da-db)))
 return out
func _initialize()->void:run.call_deferred()
func run()->void:
 var start:=Time.get_ticks_usec();var rng:=RandomNumberGenerator.new();rng.seed=186923
 var seeds:Array[Vector2]=[]
 for y in 2:
  for x in 4:seeds.append(Vector2((x+.5)/4-.5,(y+.5)/2-.5)+Vector2(rng.randf_range(-.07,.07),rng.randf_range(-.1,.1)))
 var root_node:=Node3D.new();root_node.name="BakedWallShards"
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.4,.42,.34);material.roughness=.95
 for seed_index in seeds.size():
  var a:Vector2=seeds[seed_index]
  var polygon:=PackedVector2Array([Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)])
  for b in seeds:
   if a==b:continue
   polygon=clip(polygon,b-a,(b.length_squared()-a.length_squared())*.5)
  var mesh:=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
  var triangles:=Geometry2D.triangulate_polygon(polygon)
  for side in [-.5,.5]:
   for i in range(0,triangles.size(),3):
    var order:Array=[0,1,2] if side<0 else [0,2,1]
    for j in order:
     var p:Vector2=polygon[triangles[i+j]];mesh.add_vertex(Vector3(p.x,p.y,side))
  for i in polygon.size():
   var p:Vector2=polygon[i];var q:Vector2=polygon[(i+1)%polygon.size()]
   for v in [Vector3(p.x,p.y,-.5),Vector3(q.x,q.y,.5),Vector3(q.x,q.y,-.5),Vector3(p.x,p.y,-.5),Vector3(p.x,p.y,.5),Vector3(q.x,q.y,.5)]:mesh.add_vertex(v)
  mesh.generate_normals();mesh.set_material(material)
  var child:=MeshInstance3D.new();child.name="Shard%d"%seed_index;child.mesh=mesh.commit();root_node.add_child(child);child.owner=root_node
 var scene:=PackedScene.new();scene.pack(root_node)
 DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir());assert(ResourceSaver.save(scene,OUTPUT)==OK)
 print("WALL_SHARDS_BAKED ",JSON.stringify({"shards":seeds.size(),"bake_us":Time.get_ticks_usec()-start,"rigid_bodies":0}));root_node.free();quit()
