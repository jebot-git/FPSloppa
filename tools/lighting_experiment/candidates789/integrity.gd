extends SceneTree
const OUT="res://test-results/candidates789/"
var failures: Array=[]
func _initialize():run.call_deferred()
func digest(data: PackedByteArray) -> String:
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(data);return context.finish().hex_encode()
func geometry(level: Node) -> Array:
 var result: Array=[]
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var a: Array=node.mesh.surface_get_arrays(i);var data: Array=[node.transform,node.mesh.surface_get_primitive_type(i)]
   for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:data.append(a[slot])
   result.append(digest(var_to_bytes(data)))
 for node in level.find_children("*","CollisionShape3D",true,false):result.append(digest(var_to_bytes([node.transform,node.shape.get_debug_mesh().get_faces()])))
 result.sort();return result
func run() -> void:
 var results: Array=[]
 for map in ["tf_pressureworks","tf_vesper","qsrc_dm2","ctf_deepvault"]:
  var original: Node=ResourceLoader.load("res://maps/cache/"+map+"-lightmap1.scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
  var expected:=geometry(original);original.free()
  var files:=DirAccess.get_files_at(OUT+"cache")
  for file in files:
   if not file.begins_with(map+"-") or not file.ends_with(".scn"):continue
   var level: Node=ResourceLoader.load(OUT+"cache/"+file,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
   var valid:=geometry(level)==expected
   if not valid:failures.append(file+": geometry/UV/colour/collision differs")
   results.append({"cache":file,"preserved":valid});level.free()
 FileAccess.open(OUT+"integrity.json",FileAccess.WRITE).store_string(JSON.stringify({"caches":results,"failures":failures},"  "))
 print("CANDIDATE_INTEGRITY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
