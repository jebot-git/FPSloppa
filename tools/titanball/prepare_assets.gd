extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Builder=preload("res://tools/lighting_experiment/build_static_assets.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Compressor=preload("res://tools/lighting_experiment/compress_static.gd")
func _initialize():run.call_deferred()
func run() -> void:
	var helper=Builder.new();var level:=Loader.read("res://maps/tb_ashfall.bsp");assert(level!=null)
	Filtering.new().apply(level,2,true)
	assert(level.get_meta("baked_light_invalid_faces")==0 and level.get_meta("baked_light_overflow_faces")==0)
	var expected: Array=helper.geometry(level)
	var raw: String="res://maps/cache/tb_ashfall-lightmap1.scn"
	helper.save(level,raw);assert(DirAccess.copy_absolute(raw,"res://maps/cache/tb_ashfall.scn")==OK)
	var alias: String=raw.get_basename()+"-textures-"+preload("res://deathmatch/maps/texture_replacements/dictionary.gd").version()+".scn"
	assert(DirAccess.copy_absolute(raw,alias)==OK)
	var report: Dictionary={"bsp_sha256":FileAccess.get_sha256("res://maps/tb_ashfall.bsp"),"packing":level.get_meta("lightmap_packing"),"geometry_hashes":expected.size(),"codecs":[]}
	level.free()
	for codec in ["bc7","astc4"]:
		level=ResourceLoader.load(raw,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
		var stats:=Compressor.new().apply(level,codec);assert(helper.geometry(level)==expected)
		var target:=Loader.compressed_scene_path(raw,codec);helper.save(level,target);level.free()
		assert(DirAccess.copy_absolute(target,Loader.compressed_scene_path(alias,codec))==OK)
		var packed: PackedScene=ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		assert(Loader.cache_matches(packed,report.bsp_sha256,codec));stats.path=target;report.codecs.append(stats)
	FileAccess.open("res://test-results/titanball/prepare-assets.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	helper.free();print("TB_PREPARE_ASSETS_PASS ",JSON.stringify(report));quit()
