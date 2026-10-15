extends RefCounted
var meshes:Dictionary={}
var material:ShaderMaterial
func update(active:bool,nodes:Array)->void:
 if not active:
  for row in meshes.values():
   var node=row.ref.get_ref()
   if is_instance_valid(node):node.material_override=row.original
  meshes.clear();return
 if not material:
  material=ShaderMaterial.new();material.shader=preload("res://deathmatch/avatars/cloak.gdshader");material.set_shader_parameter("visibility",.38);material.set_shader_parameter("tint",Color("69d3dc"))
 for root in nodes:
  if not is_instance_valid(root):continue
  var parts:Array=root.find_children("*","MeshInstance3D",true,false)
  if root is MeshInstance3D:parts.append(root)
  for node in parts:
   if node is Label3D:continue
   if not meshes.has(node.get_instance_id()):meshes[node.get_instance_id()]={"ref":weakref(node),"original":node.material_override};node.material_override=material
 for key in meshes.keys():
  if not is_instance_valid(meshes[key].ref.get_ref()):meshes.erase(key)
