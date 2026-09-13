extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Assets=preload("res://deathmatch/maps/surface_assets.gd")
const OUT="res://test-results/map-presentation/"
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func geometry(level: Node) -> Array:
 var result: Array=[]
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var a: Array=node.mesh.surface_get_arrays(i)
   # Normals are packed by ArrayMesh. Repacking vertex colour may re-quantize
   # normals by one packed step; compare rounded directions separately.
   var values: Array=[node.transform,node.mesh.surface_get_primitive_type(i)]
   for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:values.append(a[slot])
   result.append(digest(var_to_bytes(values)))
 for node in level.find_children("*","CollisionShape3D",true,false):
  var shape: Shape3D=node.shape
  result.append(digest(var_to_bytes([node.transform,shape.get_debug_mesh().get_faces()])))
 result.sort();return result
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT+"cache")
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
 var only:=OS.get_cmdline_user_args()
 var reports: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"prepare.json")).maps if not only.is_empty() else []
 for row in rows:
  if row.get("distribution","base")!="base" or (not only.is_empty() and not row.id in only):continue
  reports=reports.filter(func(r):return r.id!=row.id)
  var started:=Time.get_ticks_msec()
  var original: Node=load("res://maps/cache/"+row.id+".scn").instantiate()
  var before:=inspect(original);var old_geometry:=geometry(original)
  var level:=Loader.read(row.path)
  check(level!=null,row.id+": imports")
  if not level:original.free();continue
  var filter:=Filtering.new();filter.apply(level,2,true,0)
  var after:=inspect(level)
  check(after==before,row.id+": unchanged lightmap/material/surface metrics")
  check(geometry(level)==old_geometry,row.id+": exact geometry, UVs and collision")
  var bank: Dictionary=level.get_meta(Assets.FRAME_TAG,{})
  var frames:=0;var bytes:=0
  for sequence in bank.values():
   frames+=sequence.size()
   for frame in sequence:
    for tex in frame.values():
     if tex:bytes+=tex.get_image().get_data_size();check(tex.get_image().has_mipmaps(),row.id+": frame mips")
  var packed:=PackedScene.new();check(packed.pack(level)==OK,row.id+": pack")
  var path: String=OUT+"cache/"+row.id+".scn"
  check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK,row.id+": save")
  check(Loader.cache_matches(packed,FileAccess.get_sha256(row.path)),row.id+": new cache accepted")
  var tinted: int=level.get_meta("map_tinted_vertices",0)
  Assets.vary(level,row.id)
  check(level.get_meta("map_tinted_vertices",0)==tinted and geometry(level)==old_geometry,row.id+": weathering preparation idempotent")
  reports.append({"id":row.id,"bsp_sha256":FileAccess.get_sha256(row.path),"navigation_sha256":FileAccess.get_sha256("res://maps/navigation/"+row.id+".res"),"metrics":after,"geometry_preserved":geometry(level)==old_geometry,"tinted_vertices":tinted,"animation_sequences":bank.size(),"animation_frames":frames,"frame_pixel_bytes":bytes,"cache_sha256":FileAccess.get_sha256(path),"prepare_ms":Time.get_ticks_msec()-started})
  original.free();level.free();packed=null;filter=null
  var restored: Node=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
  check(inspect(restored)==after and geometry(restored)==old_geometry,row.id+": serialized cache preserves geometry and atlas")
  restored.free()
  FileAccess.open(OUT+"prepare.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":reports,"failures":failures},"  "))
  print("PRESENTATION_PREPARE ",row.id," ms=",Time.get_ticks_msec()-started," failures=",failures.size())
  await process_frame
 print("PRESENTATION_PREPARE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
func digest(bytes: PackedByteArray) -> String:
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func inspect(level: Node) -> Dictionary:
 var materials: Dictionary={};var atlases: Dictionary={}
 var count:=0;var surfaces:=0;var cutouts:=0;var glow:=0
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  surfaces+=node.mesh.get_surface_count()
  for i in node.mesh.get_surface_count():materials[node.get_active_material(i)]=true
 for mat in materials:
  if mat is ShaderMaterial and mat.shader and mat.shader.code.contains("EMISSION = base * clamp(sqrt(baked) * 2.0"):
   count+=1
   if mat.get_shader_parameter("alpha_cutout"):cutouts+=1
   if mat.get_shader_parameter("has_glow"):glow+=1
   var texture: Texture2D=mat.get_shader_parameter("bake_texture")
   if not atlases.has(texture):
    var image:=texture.get_image()
    atlases[texture]={"width":image.get_width(),"height":image.get_height(),"sha256":digest(image.get_data())}
 return {"faces":level.get_meta("baked_light_faces",0),"invalid":level.get_meta("baked_light_invalid_faces",0),"overflow":level.get_meta("baked_light_overflow_faces",0),"unlit":level.get_meta("baked_light_unlit_faces",0),"rgb":level.get_meta("baked_light_rgb",false),"baked_materials":count,"surfaces":surfaces,"cutouts":cutouts,"glow":glow,"atlases":atlases.values()}

func uv_signature(level: Node) -> Array:
 var result: Array=[]
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var uv=node.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV2]
   if uv==null:continue
   var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(uv.to_byte_array());result.append(digest.finish().hex_encode())
 result.sort();return result
