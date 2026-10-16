extends Node3D
## Immutable offline placements. Engine mesh LOD, frustum and distance culling;
## no per-frame script selection or dependence on terrain tile residency.
const ROOT="res://experimental-assets/jungle/rocks/"
const CHUNK:=64.0
const VIEW_DISTANCE:=700.0 # Cover stays visible beyond all normal infantry spotting ranges.
var metadata:Dictionary={}
var rows:Array=[]
var meshes:Array=[]
var shapes:Array=[]
var navigation_faces:Array[PackedVector3Array]=[]
var collision_count:=0
var groups:Array[MultiMeshInstance3D]=[]
var bounds:Array[AABB]=[]
func setup(graphics:bool,physics:bool)->void:
 metadata=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"));rows=metadata.rows
 for asset in metadata.assets:
  meshes.append(load(asset.mesh) if graphics else null)
  shapes.append(load(asset.collision) if not asset.collision.is_empty() else null)
  var faces:=PackedVector3Array()
  for p in asset.nav_faces:faces.append(Vector3(p[0],p[1],p[2]))
  navigation_faces.append(faces)
 var batches:Dictionary={};var bodies:Dictionary={}
 for row in rows:
  var t:=placement(row);var kind:=int(row.asset)
  var chunk:=Vector2i(floori(t.origin.x/CHUNK),floori(t.origin.z/CHUNK))
  var key:=Vector3i(chunk.x,chunk.y,kind)
  if graphics:
   if not batches.has(key):batches[key]=[]
   batches[key].append(t)
  var size:=Vector3(metadata.assets[kind].size[0],metadata.assets[kind].size[1],metadata.assets[kind].size[2])
  bounds.append(t*AABB(Vector3(-size.x*.5,0,-size.z*.5),size))
  if physics and shapes[kind]:
   if not bodies.has(chunk):
    var body:=StaticBody3D.new();body.name="RockCover_%d_%d"%[chunk.x,chunk.y];add_child(body);bodies[chunk]=body
   var collider:=CollisionShape3D.new();collider.shape=shapes[kind];collider.transform=t;bodies[chunk].add_child(collider);collision_count+=1
 for key in batches:
  var group:=MultiMeshInstance3D.new();group.name="RockBatch_%d_%d_%d"%[key.x,key.y,key.z]
  # Local origins keep per-batch AABBs tight and floating-point transforms small.
  group.position=Vector3(key.x*CHUNK,0,key.y*CHUNK)
  group.multimesh=MultiMesh.new();group.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  group.multimesh.mesh=meshes[key.z];group.multimesh.instance_count=batches[key].size()
  for i in batches[key].size():
   var t:Transform3D=batches[key][i];t.origin-=group.position;group.multimesh.set_instance_transform(i,t)
  group.visibility_range_end=VIEW_DISTANCE;group.visibility_range_end_margin=40
  group.lod_bias=.65;group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(group);groups.append(group)
static func placement(row:Dictionary)->Transform3D:
 return Transform3D(Basis(Vector3.UP,row.angle).scaled(Vector3.ONE*float(row.scale)),Vector3(row.position[0],row.position[1],row.position[2]))
func navigation_source(data:NavigationMeshSourceGeometryData3D,area:AABB)->void:
 # Recast gets the same convex hull as authority collision, not an AABB wall.
 for i in rows.size():
  var kind:=int(rows[i].asset)
  if not shapes[kind] or not bounds[i].intersects(area):continue
  data.add_faces(navigation_faces[kind],placement(rows[i]))
static func sources()->Array:
 var result:Array=["res://tools/voxel_battle/rock_cover.gd",ROOT+"layout.json",ROOT+"source.json",ROOT+"albedo.png",ROOT+"rock.material"]
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"))
 for asset in catalog.assets:
  result.append(asset.mesh)
  if not asset.collision.is_empty():result.append(asset.collision)
 return result
