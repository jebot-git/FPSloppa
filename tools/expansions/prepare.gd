extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Compressor=preload("res://tools/lighting_experiment/compress_static.gd")
const Dict=preload("res://deathmatch/maps/texture_replacements/dictionary.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
 if not ok:failures.append(message);push_error(message)
func hash_bytes(bytes: PackedByteArray) -> String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func materials(level: Node) -> Array:
 var bank: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  for i in node.mesh.get_surface_count():bank[node.get_active_material(i)]=true
 return bank.keys()
func valid_mips(im: Image) -> bool:
 var size:=maxi(im.get_width(),im.get_height());var expected:=0
 while size>1:expected+=1;size=size>>1
 return im.get_mipmap_count()==expected
func audit(level: Node) -> Dictionary:
 var colours:=0;var atlases: Dictionary={};var data: Array=[]
 for mat in materials(level):
  if mat is ShaderMaterial:
   var bake=mat.get_shader_parameter("bake_texture")
   if bake is Texture2D:
    var im: Image=bake.get_image();check(not im.has_mipmaps() and not im.is_compressed(),"Packed lightmap must remain lossless without mipmaps")
    var digest:=hash_bytes(im.get_data());atlases[digest]=true;data.append(["bake",digest])
   for name in ["base_texture","glow_texture"]:
    var tex=mat.get_shader_parameter(name)
    if tex is Texture2D:
     var im: Image=tex.get_image();check(valid_mips(im),"Missing colour mip chain")
     if name=="glow_texture":data.append([name,hash_bytes(im.get_data())])
     colours+=1
  elif mat is BaseMaterial3D:
   for slot in BaseMaterial3D.TEXTURE_MAX:
    var tex: Texture2D=mat.get_texture(slot)
    if tex:
     var im:=tex.get_image();check(valid_mips(im),"Missing material mip chain");colours+=1
 check(int(level.get_meta("baked_light_faces",0))>0,"Missing baked faces")
 check(int(level.get_meta("baked_light_invalid_faces",0))==0,"Invalid baked light samples")
 check(int(level.get_meta("baked_light_overflow_faces",0))==0,"Lightmap packing overflow")
 return {"colour_textures":colours,"light_atlases":atlases.size(),"lossless_data_hash":hash_bytes(var_to_bytes(data)),"baked_faces":level.get_meta("baked_light_faces",0),"unlit_faces":level.get_meta("baked_light_unlit_faces",0),"rgb":level.get_meta("baked_light_rgb",false),"packing":level.get_meta("lightmap_packing",{})}
func save(level: Node,path: String):
 var packed:=PackedScene.new();check(packed.pack(level)==OK,"Pack failed");check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK,"Save failed: "+path)
func run():
 var id: String=OS.get_cmdline_user_args()[0];var row: Dictionary={}
 for item in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")):
  if item.id==id:row=item;break
 assert(not row.is_empty())
 var level:=Loader.read(row.path);assert(level!=null)
 var filtering:=Filtering.new();filtering.apply(level,2,true)
 var report:=audit(level);report.id=id;report.bsp_sha256=FileAccess.get_sha256(row.path);report.codecs=[]
 var path: String=row.scene.get_basename()+"-lightmap1.scn";save(level,path);check(DirAccess.copy_absolute(path,row.scene)==OK,"Base cache copy")
 var alias:=path.get_basename()+"-textures-"+Dict.version()+".scn";var needed:=Dict.has_missing(row.path)
 if needed:check(DirAccess.copy_absolute(path,alias)==OK,"Dictionary cache copy")
 if id.begins_with("de_varq_"):
  root.add_child(level)
  var mesh:=preload("res://deathmatch/bots.gd").new_mesh(id);var geometry:=NavigationMeshSourceGeometryData3D.new()
  var doors:=preload("res://deathmatch/maps/de_navigation.gd").open_for_navigation(level)
  NavigationServer3D.parse_source_geometry_data(mesh,geometry,level);preload("res://deathmatch/maps/de_navigation.gd").restore(doors)
  NavigationServer3D.bake_from_source_geometry_data(mesh,geometry)
  check(mesh.get_polygon_count()>0,"Empty navigation");check(ResourceSaver.save(mesh,"res://maps/navigation/"+id+".res",ResourceSaver.FLAG_COMPRESS)==OK,"Navigation save")
 level.free();filtering=null
 for codec in ["bc7","astc4"]:
  level=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
  var stats:=Compressor.new().apply(level,codec)
  var verified:=audit(level);check(verified.lossless_data_hash==report.lossless_data_hash,"Compression changed lightmaps or glow")
  var target:=Loader.compressed_scene_path(path,codec);save(level,target);level.free()
  if needed:check(DirAccess.copy_absolute(target,Loader.compressed_scene_path(alias,codec))==OK,"Compressed dictionary copy")
  var packed:=ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
  check(Loader.cache_matches(packed,report.bsp_sha256,codec),"Stale cache: "+target)
  stats.sha256=FileAccess.get_sha256(target);stats.path=target;report.codecs.append(stats)
  packed=null;await process_frame
 report.failures=failures
 DirAccess.make_dir_recursive_absolute("res://test-results/expansion-assets")
 FileAccess.open("res://test-results/expansion-assets/"+id+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("EXPANSION_ASSET_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
