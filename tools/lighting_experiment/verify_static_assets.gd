extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/static-assets/"
var rows: Array=[]
var decode_pool: Dictionary={}
func _initialize():run.call_deferred()
func materials(level: Node) -> Array:
 var bank: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():
    var mat: Material=node.get_active_material(i)
    if mat is ShaderMaterial and mat.get_shader_parameter("bake_texture") is Texture2D:bank[mat]=true
 return bank.keys()
func image_equal(a: Texture2D,b: Texture2D) -> bool:
 if not a or not b:return a==b
 return a.get_image().get_data()==b.get_image().get_data() and a.get_size()==b.get_size()
func decode(source: Texture2D) -> Texture2D:
 if not source or not source.get_image().is_compressed():return source
 if decode_pool.has(source):return decode_pool[source]
 var image:=source.get_image();var encoded:=image.get_data();var data:=PackedByteArray()
 # Decode each mip at offset zero: avoids the installed decoder's alignment bug.
 for level in image.get_mipmap_count()+1:
  var start:=image.get_mipmap_offset(level);var end:=image.get_mipmap_offset(level+1) if level<image.get_mipmap_count() else encoded.size()
  var mip:=Image.create_from_data(maxi(1,image.get_width()>>level),maxi(1,image.get_height()>>level),false,image.get_format(),encoded.slice(start,end))
  assert(mip.decompress()==OK and not mip.is_compressed());mip.convert(Image.FORMAT_RGBA8);data.append_array(mip.get_data())
 var texture:=ImageTexture.create_from_image(Image.create_from_data(image.get_width(),image.get_height(),image.has_mipmaps(),Image.FORMAT_RGBA8,data))
 for tag in source.get_meta_list():texture.set_meta(tag,source.get_meta(tag))
 decode_pool[source]=texture;return texture
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT+"astc-reference")
 var maps: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"build.json"))
 for row in maps:
  var raw: Node=ResourceLoader.load("res://maps/cache/"+row.map+"-lightmap1.scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
  var original:=materials(raw)
  for codec in ["bc7","astc4"]:
   var node: Node=ResourceLoader.load("res://maps/cache/"+row.map+"-lightmap1-"+codec+".scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
   var updated:=materials(node);assert(updated.size()==original.size())
   var compressed:=0
   for i in original.size():
    var a: ShaderMaterial=original[i];var b: ShaderMaterial=updated[i]
    assert(a.get_meta("bsp_texture_name")==b.get_meta("bsp_texture_name"))
    assert(image_equal(a.get_shader_parameter("bake_texture"),b.get_shader_parameter("bake_texture")))
    assert(image_equal(a.get_shader_parameter("glow_texture"),b.get_shader_parameter("glow_texture")))
    var base: Texture2D=b.get_shader_parameter("base_texture");var image:=base.get_image()
    assert(base.get_size()==a.get_shader_parameter("base_texture").get_size())
    if image.is_compressed():
     compressed+=1;assert(image.get_format()==(Image.FORMAT_BPTC_RGBA if codec=="bc7" else Image.FORMAT_ASTC_4x4))
     assert(image.has_mipmaps() and maxi(image.get_width(),image.get_height())>128 and b.get_shader_parameter("alpha_cutout")!=true)
    elif a.get_shader_parameter("alpha_cutout")==true:assert(image_equal(a.get_shader_parameter("base_texture"),base))
   Filtering.new().apply(node,2,true)
   var retained:=0
   for mat in updated:
    if mat.get_shader_parameter("base_texture").get_image().is_compressed():retained+=1
   assert(compressed==retained)
   if codec=="astc4":
    for mat in updated:
     var texture:=decode(mat.get_shader_parameter("base_texture"))
     for key in ["base_texture","base_nearest","base_linear"]:mat.set_shader_parameter(key,texture)
    var bank: Dictionary=node.get_meta("map_texture_frames",{})
    for frames in bank.values():
     for frame in frames:frame.base=decode(frame.base)
    # These scenes are explicitly decoded VISUAL REFERENCES, never distributed.
    var packed:=PackedScene.new();assert(packed.pack(node)==OK);assert(ResourceSaver.save(packed,OUT+"astc-reference/"+row.map+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
   rows.append({"map":row.map,"format":codec,"baked_materials":updated.size(),"compressed_base_materials":compressed,"lightmaps_glow_cutouts_unchanged":true,"full_resolution_and_mips":true,"runtime_filtering_preserves_compression":true})
   node.free();decode_pool.clear()
  raw.free();await process_frame
 # Previously randomly chosen third-party BSP: native fallback remains importable.
 var external:="res://test-results/lighting-coverage/external-original.bsp"
 assert(FileAccess.file_exists(external))
 var imported: Array=[]
 for path in [external,"res://test-results/lighting-coverage/external-optin.bsp"]:
  var level:=Loader.read(path);assert(level!=null);imported.append({"path":path,"baked":level.has_meta("baked_light_faces"),"invalid":level.get_meta("baked_light_invalid_faces",0),"overflow":level.get_meta("baked_light_overflow_faces",0)});assert(imported.back().invalid==0 and imported.back().overflow==0);level.free()
 FileAccess.open(OUT+"verify.json",FileAccess.WRITE).store_string(JSON.stringify({"records":rows,"imports":imported,"failures":[]},"  "))
 print("STATIC_ASSETS_VERIFY_PASS ",rows.size());quit()
