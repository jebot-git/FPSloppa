extends SceneTree
const Dict=preload("res://deathmatch/maps/texture_replacements/dictionary.gd")
func _initialize():run.call_deferred()
func run():
 var ids: Array=[]
 for file in ["tools/expansions/catalog.json","tools/arena_imports/conversions.json","tools/unreal_imports/installed.json","tools/unreal_imports/as-installed.json"]:
  for row in JSON.parse_string(FileAccess.get_file_as_string("res://"+file)):ids.append(row.id)
 var output: Dictionary={}
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")):
  if not row.id in ids:continue
  var active: String=row.scene.get_basename()+"-lightmap1"
  if Dict.has_missing(row.path):active+="-textures-"+Dict.version()
  output[row.id]={"bsp_sha256":FileAccess.get_sha256(row.path),"active":active.trim_prefix("res://")}
  for suffix in [".scn","-bc7.scn","-astc4.scn"]:
   if not FileAccess.file_exists(active+suffix):push_error("Missing "+active+suffix);quit(1);return
 FileAccess.open("res://tools/final_expansion/cache-selection.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
 print("EXPANSION_CACHE_SELECTION ",output.size());quit(0 if output.size()==78 else 1)
