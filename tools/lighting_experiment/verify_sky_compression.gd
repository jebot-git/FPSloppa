extends SceneTree
func _initialize() -> void:
 var rows: Array=[]
 for name in ["overcast","night","storm","winter","ember"]:
  var cfg:=ConfigFile.new();assert(cfg.load("res://deathmatch/maps/skies/"+name+".png.import")==OK)
  assert(cfg.get_value("params","compress/high_quality")==true)
  for format in ["bptc","astc"]:
   var texture:=CompressedTexture2D.new();assert(texture.load(cfg.get_value("remap","path."+format))==OK)
   var image:=texture.get_image();assert(image.get_size()==Vector2i(2048,1024) and image.has_mipmaps())
   assert(image.get_format()==(Image.FORMAT_BPTC_RGBA if format=="bptc" else Image.FORMAT_ASTC_4x4))
   rows.append({"sky":name,"format":format,"width":image.get_width(),"height":image.get_height(),"mips":image.get_mipmap_count(),"encoded_bytes":image.get_data_size()})
 FileAccess.open("res://test-results/static-assets/sky-compression.json",FileAccess.WRITE).store_string(JSON.stringify({"records":rows,"failures":[]},"  "))
 print("SKY_COMPRESSION_PASS ",rows.size());quit()
