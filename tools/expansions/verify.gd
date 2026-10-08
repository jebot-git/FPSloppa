extends "res://tools/expansions/prepare.gd"
func run():
 var reports: Array=[]
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")):
  if row.get("distribution","base")!="base" or not ("st" in row.get("modes",[]) or "de" in row.get("modes",[])):continue
  var path: String=row.scene.get_basename()+"-lightmap1.scn";var baseline:=""
  for codec in ["","bc7","astc4"]:
   var file: String=path if codec=="" else Loader.compressed_scene_path(path,codec)
   var packed:=ResourceLoader.load(file,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
   check(Loader.cache_matches(packed,row.sha256,codec),"Invalid cache: "+file)
   if not packed:continue
   var level:=packed.instantiate();var result:=audit(level)
   if codec=="":baseline=result.lossless_data_hash
   else:check(baseline==result.lossless_data_hash,"Changed lightmap/glow data: "+file)
   reports.append({"id":row.id,"codec":codec,"sha256":FileAccess.get_sha256(file),"complete_colour_mips":true,"lightmaps_lossless_unmipped":true})
   level.free();packed=null;await process_frame
  print("EXPANSION_VERIFIED ",row.id)
 FileAccess.open("res://tools/expansions/cache_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"caches":reports,"failures":failures},"  "))
 print("EXPANSION_CACHE_VALIDATION ",reports.size()," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
