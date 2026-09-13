extends SceneTree
func _initialize():run.call_deferred()
func run() -> void:
 var report: Array=[]
 for mode in [Image.COMPRESS_BPTC,Image.COMPRESS_ASTC]:
  for block in [Image.ASTC_FORMAT_4x4,Image.ASTC_FORMAT_8x8]:
   if mode==Image.COMPRESS_BPTC and block==Image.ASTC_FORMAT_8x8:continue
   var img:=Image.create(64,64,false,Image.FORMAT_RGBA8)
   for y in 64:
    for x in 64:img.set_pixel(x,y,Color(float(x)/64,float(y)/64,.2,1))
   img.generate_mipmaps()
   var started:=Time.get_ticks_msec();var err:=img.compress(mode,Image.COMPRESS_SOURCE_GENERIC,block)
   var bytes:=img.get_data_size();var format:=img.get_format()
   var decode:=img.decompress() if err==OK else err
   report.append({"mode":mode,"block":block,"encode":err,"decode":decode,"format":format,"bytes":bytes,"ms":Time.get_ticks_msec()-started})
 print("CODECS ",JSON.stringify(report));quit()
