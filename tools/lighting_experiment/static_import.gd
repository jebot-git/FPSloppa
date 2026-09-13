extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/static-rendering/"
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT+"cache")
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
 var reports: Array=[]
 for row in rows:
  if row.get("distribution","base")!="base":continue
  var started:=Time.get_ticks_msec()
  var original: Node=load("res://maps/cache/"+row.id+".scn").instantiate()
  var old_metrics:=inspect(original);var old_uvs:=uv_signature(original)
  var level: Node=original
  if row.id in ["tf_pressureworks","tf_vesper"]:level=Loader.read(OUT+"candidate/"+row.id+".bsp")
  var filter:=Filtering.new();filter.apply(level,2,true,0)
  level.set_meta("bsp_source_sha256",FileAccess.get_sha256(OUT+"candidate/"+row.id+".bsp" if row.id in ["tf_pressureworks","tf_vesper"] else row.path))
  check(uv_signature(level)==old_uvs,row.id+": unchanged lightmap UVs")
  var metrics:=inspect(level)
  for key in ["faces","invalid","overflow","unlit","baked_materials","surfaces","cutouts","glow"]:
   check(metrics[key]==old_metrics[key],row.id+": unchanged "+key)
  check(metrics.atlases[0].width==old_metrics.atlases[0].width and metrics.atlases[0].height==old_metrics.atlases[0].height,row.id+": unchanged atlas size")
  var colour_count:=0
  for mat in filter.materials:
   if mat is ShaderMaterial and mat.shader==Filtering.BAKED:
    var tex: Texture2D=mat.get_shader_parameter("base_texture")
    check(tex.get_image().has_mipmaps() and tex.has_meta(Filtering.ColourMips.TAG),row.id+": prepared colour texture")
    colour_count+=1
  var packed:=PackedScene.new();check(packed.pack(level)==OK,row.id+": pack")
  var path: String=OUT+"cache/"+row.id+".scn"
  check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK,row.id+": save")
  if level!=original:original.free()
  level.free();packed=null;filter=null
  var cached: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
  var restored:=cached.instantiate();check(inspect(restored)==metrics,row.id+": round trip")
  restored.free();cached=null
  reports.append({"id":row.id,"original":old_metrics,"candidate":metrics,"colour_materials":colour_count,"cache_sha256":FileAccess.get_sha256(path),"prepare_ms":Time.get_ticks_msec()-started})
  FileAccess.open(OUT+"import.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":reports,"failures":failures},"  "))
  print("STATIC_IMPORT ",row.id," ms=",Time.get_ticks_msec()-started," failures=",failures.size())
  await process_frame
 quit(0 if failures.is_empty() else 1)
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
