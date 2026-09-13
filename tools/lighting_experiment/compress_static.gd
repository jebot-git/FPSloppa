extends RefCounted
## Editor/offline only. Never recompress lightmaps, glow, cutouts or small artwork.
const Mips=preload("res://deathmatch/maps/colour_mips.gd")
var pool: Dictionary={}
var seen: Dictionary={}
var format: String
var changed:=0
var raw_bytes:=0
var encoded_bytes:=0
func texture(source: Texture2D,cutout: bool=false) -> Texture2D:
 if not source or cutout:return source
 var image:=source.get_image()
 if not image or image.is_compressed() or maxi(image.get_width(),image.get_height())<=128 or mini(image.get_width(),image.get_height())<4:return source
 if image.detect_alpha()!=Image.ALPHA_NONE:return source
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(image.get_data())
 var key:=str(image.get_size())+str(image.get_format())+h.finish().hex_encode()
 if pool.has(key):return pool[key]
 raw_bytes+=image.get_data_size()
 assert(image.compress(Image.COMPRESS_BPTC if format=="bc7" else Image.COMPRESS_ASTC,Image.COMPRESS_SOURCE_GENERIC,Image.ASTC_FORMAT_4x4)==OK)
 assert(image.is_compressed());encoded_bytes+=image.get_data_size();changed+=1
 var result:=ImageTexture.create_from_image(image)
 for tag in source.get_meta_list():result.set_meta(tag,source.get_meta(tag))
 result.set_meta(Mips.TAG,Mips.VERSION*2)
 pool[key]=result
 return result
func material(mat: Material) -> void:
 if not mat or seen.has(mat):return
 seen[mat]=true
 if mat is ShaderMaterial and mat.get_shader_parameter("bake_texture") is Texture2D:
  var base: Texture2D=mat.get_shader_parameter("base_texture")
  var updated:=texture(base,mat.get_shader_parameter("alpha_cutout")==true)
  for key in ["base_texture","base_nearest","base_linear"]:mat.set_shader_parameter(key,updated)
 elif mat is BaseMaterial3D and mat.has_meta("bsp_texture_name"):
  mat.albedo_texture=texture(mat.albedo_texture,mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED)
 if mat.has_meta("fpsloppa_filter_variants"):
  for variant in mat.get_meta("fpsloppa_filter_variants"):material(variant)
func apply(level: Node,codec: String) -> Dictionary:
 assert(codec in ["bc7","astc4"]);format=codec
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():material(node.get_active_material(i))
 var bank: Dictionary=level.get_meta("map_texture_frames",{})
 for frames in bank.values():
  for frame in frames:frame.base=texture(frame.base) # Animated Quake frames use opaque palette colour.
 level.set_meta("static_texture_format",format)
 return {"format":format,"images":changed,"raw_bytes":raw_bytes,"encoded_bytes":encoded_bytes}
