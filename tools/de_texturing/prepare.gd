extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Builder=preload("res://tools/lighting_experiment/build_static_assets.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Compressor=preload("res://tools/lighting_experiment/compress_static.gd")
func _initialize():run.call_deferred()
func run() -> void:
	var ids:=OS.get_cmdline_user_args()
	if ids.is_empty():ids=PackedStringArray(["de_dust2_rebuilt","de_nuke_rebuilt","de_inferno_rebuilt","de_aztec_rebuilt","de_train_rebuilt"])
	var reports: Array=[]
	var helper=Builder.new()
	for id in ids:
		var path:="res://maps/"+id+".bsp"
		var level:=Loader.read(path);assert(level!=null)
		Filtering.new().apply(level,2,true)
		assert(level.get_meta("baked_light_invalid_faces")==0 and level.get_meta("baked_light_overflow_faces")==0)
		var expected: Array=helper.geometry(level)
		var raw:="res://maps/cache/"+id+"-lightmap1.scn"
		helper.save(level,raw);assert(DirAccess.copy_absolute(raw,"res://maps/cache/"+id+".scn")==OK)
		var alias:=raw.get_basename()+"-textures-"+preload("res://deathmatch/maps/texture_replacements/dictionary.gd").version()+".scn"
		var needs_alias:=preload("res://deathmatch/maps/texture_replacements/dictionary.gd").has_missing(path)
		# QBSP may retain unused missing texture entries from func_detail. The
		# runtime still selects its dictionary-versioned cache in that case.
		if needs_alias:assert(DirAccess.copy_absolute(raw,alias)==OK)
		var report: Dictionary={"map":id,"bsp_sha256":FileAccess.get_sha256(path),"packing":level.get_meta("lightmap_packing"),"invalid_faces":0,"overflow_faces":0,"codecs":[]}
		level.free()
		assert(Loader.cache_matches(load(raw),report.bsp_sha256))
		for codec in ["bc7","astc4"]:
			level=ResourceLoader.load(raw,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
			var stats:=Compressor.new().apply(level,codec);assert(helper.geometry(level)==expected)
			var target:=Loader.compressed_scene_path(raw,codec);helper.save(level,target);level.free()
			if needs_alias:assert(DirAccess.copy_absolute(target,Loader.compressed_scene_path(alias,codec))==OK)
			var packed: PackedScene=ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
			assert(Loader.cache_matches(packed,report.bsp_sha256,codec));stats.path=target;report.codecs.append(stats)
		reports.append(report)
		FileAccess.open("res://test-results/de-texturing/"+id+"-assets.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		print("DE_TEXTURE_ASSETS_PASS ",JSON.stringify(report));await process_frame
	helper.free();quit()
