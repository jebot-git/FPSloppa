extends SceneTree
const Check=preload("res://tools/lighting_experiment/verify_static_assets.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Loader=preload("res://deathmatch/maps/loader.gd")
func _initialize():run.call_deferred()
func run() -> void:
	var helper=Check.new()
	var raw=load("res://maps/cache/tb_ashfall-lightmap1.scn").instantiate()
	var original: Array=helper.materials(raw);var records: Array=[]
	for codec in ["bc7","astc4"]:
		var path="res://maps/cache/tb_ashfall-lightmap1-"+codec+".scn"
		var packed: PackedScene=load(path)
		assert(Loader.cache_matches(packed,FileAccess.get_sha256("res://maps/tb_ashfall.bsp"),codec))
		var node=packed.instantiate();var updated: Array=helper.materials(node);assert(updated.size()==original.size());var compressed:=0
		for i in original.size():
			var a: ShaderMaterial=original[i];var b: ShaderMaterial=updated[i]
			assert(a.get_meta("bsp_texture_name")==b.get_meta("bsp_texture_name"))
			assert(helper.image_equal(a.get_shader_parameter("bake_texture"),b.get_shader_parameter("bake_texture")))
			assert(helper.image_equal(a.get_shader_parameter("glow_texture"),b.get_shader_parameter("glow_texture")))
			var base: Texture2D=b.get_shader_parameter("base_texture");var img:=base.get_image()
			assert(base.get_size()==a.get_shader_parameter("base_texture").get_size())
			if img.is_compressed():
				compressed+=1;assert(img.get_format()==(Image.FORMAT_BPTC_RGBA if codec=="bc7" else Image.FORMAT_ASTC_4x4));assert(img.has_mipmaps())
			elif a.get_shader_parameter("alpha_cutout")==true:assert(helper.image_equal(a.get_shader_parameter("base_texture"),base))
		Filtering.new().apply(node,2,true)
		var retained:=0
		for mat in updated:if mat.get_shader_parameter("base_texture").get_image().is_compressed():retained+=1
		assert(compressed==retained and compressed>0)
		records.append({"codec":codec,"materials":updated.size(),"compressed_materials":compressed,"lightmaps_glow_unchanged":true,"full_resolution_mips":true,"filtering_retains_compression":true});node.free()
	raw.free();helper.free()
	FileAccess.open("res://test-results/titanball/assets.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"failures":[]},"  "))
	print("TB_ASSETS_PASS ",JSON.stringify(records));quit()
