extends SceneTree
const DictionaryTextures=preload("res://deathmatch/maps/texture_replacements/dictionary.gd")
const Loader=preload("res://deathmatch/maps/loader.gd")
const Reader=preload("res://addons/bsp_importer/bsp_reader.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("TEXTURE_CHECK ",ok," ",label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path:=OS.get_cmdline_user_args()[0]
	check(Loader.validate(path).is_empty(),"rebuilt BSP valid")
	check(not DictionaryTextures.has_missing(path),"embedded map detected")
	var external:="res://test-results/texture-fallback/external.bsp"
	check(Loader.validate(external).is_empty(),"named external texture headers accepted")
	check(DictionaryTextures.has_missing(external),"missing textures detected for versioned cache")
	check(not Loader.validate("res://test-results/texture-fallback/malformed.bsp").is_empty(),"out of bounds pixels rejected")
	var named:=DictionaryTextures.resolve("METAL1_3")
	check(named.key=="metal1_3","case-insensitive counterpart")
	check(DictionaryTextures.resolve("*water1").key=="*water1","liquid prefix preserved")
	check(DictionaryTextures.resolve("unknown_external").key=="_fallback","unknown name gets deterministic neutral material")
	var reader:=Reader.new();reader.save_separate_materials=false;reader.use_named_texture_replacements=true;reader.generate_texture_materials=true;reader.texture_palette_path="res://deathmatch/maps/palette.lmp"
	var texture:=Reader.BSPTexture.new();texture.name="metal1_3";texture.source_name="metal1_3";texture.width=32;texture.height=128
	var material_info=reader.load_or_create_material(texture.name,texture)
	check(material_info.width==32 and material_info.height==128,"external BSP dimensions retained for UVs")
	check(material_info.material.albedo_texture==named.texture,"named fallback material uses shared dictionary")
	# Embedded pixels with the SAME name must win over that dictionary.
	var bytes:=PackedByteArray();bytes.resize(32*128+1);bytes.fill(17)
	var f:=FileAccess.open("user://embedded-texture-test.bin",FileAccess.WRITE);f.store_buffer(bytes);f.close()
	reader.file=FileAccess.open("user://embedded-texture-test.bin",FileAccess.READ);texture.texture_data_offset=1
	material_info=reader.load_or_create_material(texture.name,texture)
	var pixel: Color=material_info.material.albedo_texture.get_image().get_pixel(0,0)
	var palette:=FileAccess.get_file_as_bytes("res://deathmatch/maps/palette.lmp")
	check(pixel.is_equal_approx(Color8(palette[51],palette[52],palette[53])),"embedded texture wins over same-named replacement")
	for map in [external,"res://test-results/texture-fallback/unnamed.bsp"]:
		var node:=Loader.read(map);check(node!=null,"complete missing-texture map imports: "+map.get_file())
		if node:node.free()
	print("TEXTURE_RESULT ",JSON.stringify({"failures":failures,"dictionary":DictionaryTextures.version()}))
	reader.file=null;reader.free();reader=null;texture=null;material_info=null
	DictionaryTextures.textures.clear();named.clear()
	await process_frame
	quit(0 if failures.is_empty() else 1)
