extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run() -> void:
 var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/validation/static-rendering.json"))
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
 var names: Array=[]
 for row in rows:
  if row.get("distribution","base")!="base":continue
  var packed:=Loader.scene(row);check(packed!=null,row.id+": loader cache")
  var level:=packed.instantiate()
  var expected: Dictionary=report.prepared_maps.filter(func(r):return r.id==row.id)[0].candidate
  var actual:=inspect(level)
  check(JSON.parse_string(JSON.stringify(actual))==expected,row.id+": active cache has current atlas/materials")
  var filter:=Filtering.new();filter.apply(level,2,false,1)
  for mat in filter.materials:
   if mat is ShaderMaterial and mat.shader==Filtering.BAKED:
    for key in ["base_texture","glow_texture"]:
     var tex: Texture2D=mat.get_shader_parameter(key)
     if tex:check(tex.has_meta(Filtering.ColourMips.TAG),row.id+": active cache has prepared "+key)
  names.append({"id":row.id,"path":packed.resource_path})
  level.free();packed=null
 print("STATIC_CACHE_RESULT ",JSON.stringify({"maps":names,"failures":failures}))
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
