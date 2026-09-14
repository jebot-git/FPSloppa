extends SceneTree
func _initialize():run.call_deferred()
func run() -> void:
 var results: Array=[]
 var loader=preload("res://deathmatch/maps/loader.gd")
 var dictionary=preload("res://deathmatch/maps/texture_replacements/dictionary.gd")
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")):
  if row.get("distribution","base")!="base":continue
  var path: String=str(row.scene).get_basename()+"-lightmap1.scn"
  if dictionary.has_missing(row.path):path=path.get_basename()+"-textures-"+dictionary.version()+".scn"
  var scene: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
  var entry:={"id":row.id,"path":path,"source_matches":loader.cache_matches(scene,FileAccess.get_sha256(row.path)),"metadata":{},"shader_paths":[]}
  var state:=scene.get_state()
  for i in state.get_node_property_count(0):
   var name:=str(state.get_node_property_name(0,i))
   if name.begins_with("metadata/baked_light_") or name.begins_with("metadata/quake_"):entry.metadata[name]=state.get_node_property_value(0,i)
  for n in state.get_node_count():
   for i in state.get_node_property_count(n):
    if state.get_node_property_name(n,i)!="mesh":continue
    var mesh=state.get_node_property_value(n,i)
    if not mesh is Mesh:continue
    for surface in mesh.get_surface_count():
     var mat=mesh.surface_get_material(surface)
     if mat is ShaderMaterial and mat.shader and mat.get_shader_parameter("bake_texture") is Texture2D:
      var shader_path: String=mat.shader.resource_path
      if not shader_path in entry.shader_paths:entry.shader_paths.append(shader_path)
  results.append(entry);print("BASE_CACHE_AUDIT ",row.id," source_matches=",entry.source_matches," ",entry.shader_paths)
  scene=null
 FileAccess.open("res://docs/validation/base-lighting-caches.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 quit()
