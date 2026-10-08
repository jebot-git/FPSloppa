extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
var failures: Array=[]
func check(ok: bool,label: String):
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Loader.Paths.folder("maps")+"FinalExpansion/manifest.json"))
 var catalog:=Loader.catalog();var by_id: Dictionary={}
 for row in catalog:by_id[row.id]=row
 for mode in manifest.rotations:
  var text:=FileAccess.get_file_as_string(Loader.Paths.folder("maps")+mode+"_maplist.txt")
  var names:=Array(text.split("\n",false));check(names==manifest.rotations[mode],mode+" combined rotation")
  check(names.all(func(id):return by_id.has(id)),mode+" installed maps")
  var parsed:=preload("res://deathmatch/server/config.gd").parse('set '+mode+'_maplist "'+" ".join(names)+'"')
  check(not parsed.has("error"),mode+" server config accepts rotation")
 var maps: Array=[]
 for row in manifest.maps:
  check(by_id.has(row.id),row.id+" appears in catalog")
  if not by_id.has(row.id):continue
  var installed: Dictionary=by_id[row.id]
  check(installed.sha256==row.sha256,row.id+" BSP hash")
  if "as" in row.modes:check(Loader.supports_assault(installed.path),row.id+" AS support")
  var packed:=Loader.scene(installed)
  check(packed!=null,row.id+" prepared scene loads")
  if packed==null:continue
  var level:=packed.instantiate()
  var baked: int=level.get_meta("baked_light_faces",0)
  check(baked>0 and int(level.get_meta("baked_light_invalid_faces",0))==0,row.id+" light bake")
  maps.append({"id":row.id,"baked_faces":baked});level.free();packed=null
  await process_frame
 for id in manifest.excluded_ids:check(not by_id.has(id),id+" excluded")
 var report={"maps":maps,"rotation_counts":{},"failures":failures}
 for mode in manifest.rotations:report.rotation_counts[mode]=manifest.rotations[mode].size()
 FileAccess.open("res://test-results/final-expansion-install.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("EXPANSION_INSTALL_RESULT ",maps.size()," maps ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
