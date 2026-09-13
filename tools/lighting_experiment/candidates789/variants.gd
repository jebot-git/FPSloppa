extends SceneTree
const OUT="res://test-results/candidates789/"
const Mips=preload("res://deathmatch/maps/colour_mips.gd")
var report: Array=[]
var images: Dictionary={}
func _initialize():run.call_deferred()
func materials(level: Node) -> Array:
 var result: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():
    var mat: Material=node.get_active_material(i)
    if mat is ShaderMaterial and mat.get_shader_parameter("bake_texture") is Texture2D:result[mat]=true
 return result.keys()
func image_key(image: Image) -> String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(image.get_data())
 return str(image.get_width())+"x"+str(image.get_height())+"-"+str(image.get_format())+"-"+h.finish().hex_encode()
func bind(mat: ShaderMaterial,key: String,tex: Texture2D) -> void:
 mat.set_shader_parameter(key+"_texture",tex)
 if key!="bake":
  for suffix in ["_nearest","_linear"]:mat.set_shader_parameter(key+suffix,tex)
func glow(name: String,base: Image,source: Image) -> Image:
 if name!="tlight12" and not name.begins_with("stn_gr01_") and name!="*lava1":return null
 var result:=Image.create(base.get_width(),base.get_height(),false,Image.FORMAT_RGB8)
 for y in base.get_height():
  for x in base.get_width():
   var b:=base.get_pixel(x,y);var value:=Color.BLACK
   if name=="tlight12":
    var old: Color=source.get_pixel(x,y)
    # Existing tube aperture, warm edges and a restrained central bright core.
    var u: float=(x+.5)/base.get_width();var centre:=1.0-absf(u*2.0-1.0)
    value=old*Color(1.0,.75+.17*centre,.48+.30*centre)*(.8+.2*centre)
   elif name=="*lava1":
    var old: Color=source.get_pixel(x,y)
    var core:=smoothstep(.42,.9,old.r)*smoothstep(.08,.7,old.g)
    value=old*(.72+.28*core)
   else:
    # Test-only luminous ornamental inlay within the central rose medallion.
    # This is an art-direction proposal, not a claim the stone is emissive.
    var uv:=Vector2((x+.5)/base.get_width(),(y+.5)/base.get_height())-Vector2(.5,.5)
    var radius:=uv.length();var theta:=atan2(uv.y,uv.x)
    var ring:=smoothstep(.09,.14,radius)*(1.0-smoothstep(.33,.39,radius))
    var petal:=smoothstep(.2,.7,cos(theta*12.0))
    value=b*(ring*petal*.65)
   result.set_pixel(x,y,value)
 return Mips.build(result)
func pack_emission(base: Image,glow_image: Image) -> Image:
 var image:=Image.create(base.get_width(),base.get_height(),false,Image.FORMAT_RGBA8)
 for y in base.get_height():
  for x in base.get_width():
   var b:=base.get_pixel(x,y).srgb_to_linear();var g:=glow_image.get_pixel(x,y).srgb_to_linear()
   var sum:=Vector3(b.r+g.r,b.g+g.g,b.b+g.b);var emission:=Vector3(g.r,g.g,g.b)
   assert(sum.x<=1.001 and sum.y<=1.001 and sum.z<=1.001)
   var mask:=clampf(emission.dot(sum)/maxf(.000001,sum.length_squared()),0,1)
   var combined:=Color(sum.x,sum.y,sum.z,mask).linear_to_srgb();combined.a=mask;image.set_pixel(x,y,combined)
 return Mips.build(image)
func decode_astc(source: Image) -> Image:
 # The installed Godot decoder assumes each RGBA mip starts on an 8-byte
 # boundary, which fails on some non-square Quake mip tails. Decode levels
 # independently at offset zero and concatenate their actual RGBA pixels.
 var data:=PackedByteArray();var encoded:=source.get_data();var format:=Image.FORMAT_RGBA8
 for level in source.get_mipmap_count()+1:
  var start:=source.get_mipmap_offset(level);var end:=source.get_mipmap_offset(level+1) if level<source.get_mipmap_count() else encoded.size()
  var image:=Image.create_from_data(maxi(1,source.get_width()>>level),maxi(1,source.get_height()>>level),false,source.get_format(),encoded.slice(start,end))
  assert(image.decompress()==OK and not image.is_compressed())
  format=image.get_format();data.append_array(image.get_data())
 return Image.create_from_data(source.get_width(),source.get_height(),source.has_mipmaps(),format,data)
func save(level: Node,name: String) -> void:
 var packed:=PackedScene.new();assert(packed.pack(level)==OK);assert(ResourceSaver.save(packed,OUT+"cache/"+name+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
func run() -> void:
 var variants: Array=["authored","packed_glow","bc7_colour","bc7_all","astc4_colour","astc4_all","astc8_all","half_colour","bc7_large","astc4_large"]
 var only:=OS.get_cmdline_user_args()
 var variant_filter: String=OS.get_environment("CANDIDATE_VARIANTS")
 if not only.is_empty() or not variant_filter.is_empty():report=JSON.parse_string(FileAccess.get_file_as_string(OUT+"variants.json"))
 for map in ["tf_pressureworks","tf_vesper","qsrc_dm2","ctf_deepvault"]:
  if not only.is_empty() and not map in only:continue
  report=report.filter(func(row):return row.map!=map or (not variant_filter.is_empty() and not row.variant in variant_filter.split(",")))
  for variant in variants:
   if not variant_filter.is_empty() and not variant in variant_filter.split(","):continue
   var input: String=map+"-baseline"+("-packed" if variant not in ["authored","packed_glow"] else "")
   var level: Node=ResourceLoader.load(OUT+"cache/"+input+".scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
   var pool: Dictionary={};var before: Dictionary={};var after: Dictionary={};var encoded:=0;var changed:=0;var dedup:=0
   var started:=Time.get_ticks_msec()
   for mat in materials(level):
    var name:=str(mat.get_meta("bsp_texture_name",""));var base: Texture2D=mat.get_shader_parameter("base_texture");var emission: Texture2D=mat.get_shader_parameter("glow_texture")
    if variant=="authored":
     var updated:=glow(name,base.get_image(),emission.get_image() if emission else null)
     if updated:
      var texture:=ImageTexture.create_from_image(updated);bind(mat,"glow",texture);mat.set_shader_parameter("has_glow",true);changed+=1
      updated.save_png(OUT+"sources/"+map+"-"+name.replace("*","")+"-authored.png")
    elif variant=="packed_glow":
     if emission and mat.get_shader_parameter("alpha_cutout")!=true:
      var packed:=ImageTexture.create_from_image(pack_emission(base.get_image(),emission.get_image()))
      mat.shader=load("res://tools/lighting_experiment/candidates789/packed_glow.gdshader")
      bind(mat,"base",packed);bind(mat,"glow",null);mat.set_shader_parameter("packed_emission",true);changed+=1
    else:
     for key in ["base","glow","bake"]:
      var original: Texture2D=mat.get_shader_parameter(key+"_texture")
      if not original:continue
      var image:=original.get_image()
      before[original]=image.get_data_size()
      var signature: String=key+"-"+image_key(image)
      if pool.has(signature):bind(mat,key,pool[signature]);dedup+=1;continue
      var candidate:=image.duplicate()
      var compress: bool=not variant.ends_with("colour") or key!="bake"
      if variant.ends_with("large"):compress=key!="bake" and maxi(image.get_width(),image.get_height())>128
      if variant=="half_colour":
       if key!="bake" and max(candidate.get_width(),candidate.get_height())>256 and candidate.has_mipmaps():
        candidate=Image.create_from_data(maxi(1,candidate.get_width()/2),maxi(1,candidate.get_height()/2),true,candidate.get_format(),candidate.get_data().slice(candidate.get_mipmap_offset(1)));changed+=1
      elif compress:
       var mode: int=Image.COMPRESS_BPTC if variant.begins_with("bc7") else Image.COMPRESS_ASTC
       assert(candidate.compress(mode,Image.COMPRESS_SOURCE_GENERIC,Image.ASTC_FORMAT_8x8 if variant.begins_with("astc8") else Image.ASTC_FORMAT_4x4)==OK)
       encoded+=candidate.get_data_size();changed+=1
       if variant.begins_with("astc"):
        # ASTC visual reference, explicitly decoded before upload on desktop.
        candidate=decode_astc(candidate)
      var texture:=ImageTexture.create_from_image(candidate);pool[signature]=texture;bind(mat,key,texture);after[texture]=candidate.get_data_size()
   save(level,map+"-"+variant)
   var row:={"map":map,"variant":variant,"modified_images":changed,"shared_slot_bindings":dedup,"raw_unique_bytes_before":before.values().reduce(func(a,b):return a+b,0),"upload_image_bytes_after":after.values().reduce(func(a,b):return a+b,0),"encoded_changed_image_bytes":encoded,"astc_decoded_reference":variant.begins_with("astc"),"prepare_ms":Time.get_ticks_msec()-started}
   report.append(row);print("CANDIDATE_VARIANT ",JSON.stringify(row));FileAccess.open(OUT+"variants.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
   pool.clear();before.clear();after.clear();level.free();await process_frame
 quit()
