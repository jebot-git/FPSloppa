extends SceneTree
## Validate each shipped map's desktop/mobile compression caches against its BSP.
const Loader=preload("res://deathmatch/maps/loader.gd")
const DictionaryTextures=preload("res://deathmatch/maps/texture_replacements/dictionary.gd")
var failures: Array=[]
var records: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")):
		if row.get("distribution","base")!="base":continue
		var raw: String=str(row.scene).get_basename()+"-lightmap1.scn"
		if DictionaryTextures.has_missing(row.path):raw=raw.get_basename()+"-textures-"+DictionaryTextures.version()+".scn"
		var digest:=FileAccess.get_sha256(row.path)
		if digest!=str(row.sha256):failures.append("Catalog BSP checksum mismatch: "+str(row.id))
		for codec in ["","bc7","astc4"]:
			var path: String=raw if codec.is_empty() else Loader.compressed_scene_path(raw,codec)
			var packed:=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			var valid:=packed!=null and Loader.cache_matches(packed,digest,codec)
			records.append({"map":row.id,"codec":codec,"path":path,"source_matches":valid,"sha256":FileAccess.get_sha256(path),"bsp_sha256":digest})
			if not valid:failures.append(path)
			packed=null
		await process_frame
	var output: String="res://test-results/release-"+str(ProjectSettings.get_setting("application/config/version"))
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output+"/map-caches.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"failures":failures},"  "))
	print("RELEASE_MAP_CACHES_RESULT ",records.size()," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
