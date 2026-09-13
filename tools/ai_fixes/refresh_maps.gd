extends SceneTree
func _initialize():run.call_deferred()
func run():
 var loader=preload("res://deathmatch/maps/loader.gd")
 for id:String in ["koth_solstice","koth_hyperborea"]:
  var node=loader.read("res://maps/"+id+".bsp")
  if node==null:quit(1);return
  var scene:=PackedScene.new()
  if scene.pack(node)!=OK:quit(1);return
  for suffix:String in [".scn","-lightmap1.scn"]:
   if ResourceSaver.save(scene,"res://maps/cache/"+id+suffix)!=OK:quit(1);return
  node.free();print("REFRESHED ",id)
 quit()
