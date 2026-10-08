extends SceneTree
func _initialize():
 var results: Array=[]
 for key in ["4tdm_gasworks","dom_canalzon","ff_dustbowl","rctf_epicenter"]:
  var path: String="res://tools/tf_anniversary/local/"+key+".bsp"
  var error: String=preload("res://deathmatch/maps/loader.gd").validate(path)
  results.append({"map":key,"importable":error.is_empty(),"importer_diagnostic":error})
  print("TF_ARCHIVE_ATTEMPT ",key," ",error)
 FileAccess.open("res://tools/tf_anniversary/import_attempt.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 quit()
