extends SceneTree
func _initialize():run.call_deferred()
func run() -> void:
 for id in ["tf_pressureworks","tf_vesper"]:
  var level=preload("res://deathmatch/maps/loader.gd").read("res://maps/"+id+".bsp")
  assert(level!=null)
  var scene:=PackedScene.new();assert(scene.pack(level)==OK)
  for suffix in [".scn","-lightmap1.scn"]:
   assert(ResourceSaver.save(scene,"res://maps/cache/"+id+suffix,ResourceSaver.FLAG_COMPRESS)==OK)
  level.free();print("TF_DISTRIBUTION_CACHE ",id)
 quit()
