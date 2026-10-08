extends SceneTree
var rows: Array=[]
var failures: Array=[]
var seen: Dictionary={}
var resources: Dictionary={}
func _initialize():run.call_deferred()
func texture(tex: Texture2D,label: String,data: bool=false):
 if not tex or tex is ViewportTexture or seen.has(tex):return
 seen[tex]=true
 var im:=tex.get_image()
 if not im:return
 var size:=maxi(im.get_width(),im.get_height());var expected:=0
 while size>1:expected+=1;size=size>>1
 var valid:=not im.has_mipmaps() if data else im.get_mipmap_count()==expected
 if not valid:failures.append(label)
 rows.append({"asset":label,"width":im.get_width(),"height":im.get_height(),"mips":im.get_mipmap_count(),"data_texture":data,"valid":valid})
func material(mat: Material,path: String):
 if mat is BaseMaterial3D:
  for slot in BaseMaterial3D.TEXTURE_MAX:texture(mat.get_texture(slot),path+":"+str(slot))
 elif mat is ShaderMaterial and mat.shader:
  for uniform in mat.shader.get_shader_uniform_list():
   var value=mat.get_shader_parameter(uniform.name)
   if value is Texture2D:texture(value,path+":"+uniform.name,uniform.name in ["bake_texture","weapon_occlusion_tree"])
func scan(path: String):
 for dir in DirAccess.get_directories_at(path):scan(path+"/"+dir)
 for file in DirAccess.get_files_at(path):
  if path.ends_with("/fidelity") and not file.begins_with("cs16_"):continue
  if file.get_extension() not in ["scn","res"]:continue
  var name:=path+"/"+file;var resource=load(name);resources[name]=FileAccess.get_sha256(name)
  if resource is Texture2D:texture(resource,name)
  elif resource is PackedScene:
   var node: Node=resource.instantiate()
   for mesh in node.find_children("*","MeshInstance3D",true,false):
    if mesh.mesh:
     for surface in mesh.mesh.get_surface_count():material(mesh.get_active_material(surface),name+":"+mesh.name+":"+str(surface))
   node.free()
func run():
 for path in ["res://deathmatch/vehicles/tribes","res://deathmatch/tribes","res://deathmatch/weapons/tribes","res://deathmatch/weapons/cs16","res://deathmatch/weapons/fidelity","res://deathmatch/counterstrike"]:
  if DirAccess.dir_exists_absolute(path):scan(path)
 FileAccess.open("res://tools/expansions/runtime_art.json",FileAccess.WRITE).store_string(JSON.stringify({"textures":rows,"resources":resources,"failures":failures,"lighting":"Moving vehicles, weapons and service props use runtime lighting; level geometry uses audited baked atlases."},"  "))
 print("EXPANSION_RUNTIME_ART ",rows.size()," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
