extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Compressor=preload("res://tools/lighting_experiment/compress_static.gd")
const OUT="res://test-results/static-assets/"
var records: Array=[]
func _initialize():run.call_deferred()
func geometry(level: Node) -> Array:
 var result: Array=[]
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var a: Array=node.mesh.surface_get_arrays(i);var data: Array=[node.transform,node.mesh.surface_get_primitive_type(i)]
   for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:data.append(a[slot])
   var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(data));result.append(h.finish().hex_encode())
 for node in level.find_children("*","CollisionShape3D",true,false):
  var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes([node.transform,node.shape.get_debug_mesh().get_faces()]));result.append(h.finish().hex_encode())
 result.sort();return result
func save(level: Node,path: String) -> void:
 var packed:=PackedScene.new();assert(packed.pack(level)==OK)
 assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
func run() -> void:
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
 var only:=OS.get_cmdline_user_args()
 if not only.is_empty() and FileAccess.file_exists(OUT+"build.json"):records=JSON.parse_string(FileAccess.get_file_as_string(OUT+"build.json"))
 for row in rows:
  if row.get("distribution","base")!="base" or (not only.is_empty() and not row.id in only):continue
  var raw_path: String=row.scene.get_basename()+"-lightmap1.scn"
  var snapshot: String=OUT+"original/"+row.id+".scn"
  if not FileAccess.file_exists(snapshot):assert(DirAccess.copy_absolute(raw_path,snapshot)==OK)
  var old: Node=ResourceLoader.load(snapshot,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate();var expected:=geometry(old);old.free()
  var level:=Loader.read(row.path);assert(level!=null)
  Filtering.new().apply(level,2,true)
  assert(level.get_meta("baked_light_invalid_faces")==0 and level.get_meta("baked_light_overflow_faces")==0)
  assert(geometry(level)==expected,"Geometry/collision/colour mismatch: "+row.id)
  save(level,raw_path);assert(DirAccess.copy_absolute(raw_path,row.scene)==OK)
  var alias:=raw_path.get_basename()+"-textures-"+preload("res://deathmatch/maps/texture_replacements/dictionary.gd").version()+".scn"
  var needs_alias:=preload("res://deathmatch/maps/texture_replacements/dictionary.gd").has_missing(row.path)
  if needs_alias:assert(DirAccess.copy_absolute(raw_path,alias)==OK)
  var report: Dictionary={"map":row.id,"bsp_sha256":FileAccess.get_sha256(row.path),"geometry_preserved":true,"packing":level.get_meta("lightmap_packing"),"fine_faces":level.get_meta("lightmap_fine_faces",0),"codecs":[]}
  level.free()
  for codec in ["bc7","astc4"]:
   level=ResourceLoader.load(raw_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
   var stats:=Compressor.new().apply(level,codec)
   assert(geometry(level)==expected)
   var target:=Loader.compressed_scene_path(raw_path,codec);save(level,target);level.free()
   if needs_alias:assert(DirAccess.copy_absolute(target,Loader.compressed_scene_path(alias,codec))==OK)
   var packed: PackedScene=ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
   assert(Loader.cache_matches(packed,report.bsp_sha256,codec))
   assert(not Loader.cache_matches(packed,report.bsp_sha256,"invalid"))
   level=packed.instantiate();assert(geometry(level)==expected)
   # Loading/filter preparation must retain encoded GPU pixels and their mips.
   Filtering.new().apply(level,2,true)
   stats.path=target;stats.sha256=FileAccess.get_sha256(target);report.codecs.append(stats)
   level.free();packed=null
  records=records.filter(func(item):return item.map!=row.id);records.append(report)
  FileAccess.open(OUT+"build.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
  print("STATIC_ASSETS_MAP ",row.id," ",report.packing," ",report.codecs);await process_frame
 print("STATIC_ASSETS_BUILD_PASS ",records.size());quit()
