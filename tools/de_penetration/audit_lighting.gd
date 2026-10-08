extends "res://tools/expansions/prepare.gd"
func run():
 var reports: Array=[]
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")):
  if not "de" in row.get("modes",[]):continue
  var baseline:="";var entries: Array=[]
  check(FileAccess.get_sha256(row.path)==row.sha256,"BSP hash mismatch: "+row.id)
  var base: String=row.scene.get_basename()+"-lightmap1.scn"
  for codec in ["","bc7","astc4"]:
   var path: String=base if codec=="" else Loader.compressed_scene_path(base,codec)
   var packed:=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
   check(packed!=null,"Missing lighting cache: "+path)
   if not packed:continue
   check(Loader.cache_matches(packed,row.sha256,codec),"Stale lighting cache: "+path)
   var level:=packed.instantiate();var result:=audit(level)
   if codec=="":baseline=result.lossless_data_hash
   else:check(result.lossless_data_hash==baseline,"Compression changed light data: "+path)
   result.codec=codec;result.cache=path;entries.append(result)
   level.free();packed=null;await process_frame
  reports.append({"id":row.id,"bsp_sha256":row.sha256,"caches":entries})
  print("DE_LIGHT_CHECK ",row.id)
 DirAccess.make_dir_recursive_absolute("res://test-results/de-lighting")
 FileAccess.open("res://test-results/de-lighting/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":reports,"failures":failures},"  "))
 print("DE_LIGHT_AUDIT ",reports.size()," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
