extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/lighting-coverage/"
var reports: Array=[]
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func digest(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func inspect(level: Node) -> Dictionary:
	var materials: Dictionary={};var atlases: Dictionary={}
	var count:=0;var surfaces:=0;var cutouts:=0;var glow:=0
	for node in level.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		surfaces+=node.mesh.get_surface_count()
		for i in node.mesh.get_surface_count():materials[node.get_active_material(i)]=true
	for mat in materials:
		if mat is ShaderMaterial and mat.shader and mat.shader.code.contains("EMISSION = base * clamp(sqrt(baked) * 2.0"):
			count+=1
			if mat.get_shader_parameter("alpha_cutout"):cutouts+=1
			if mat.get_shader_parameter("has_glow"):glow+=1
			var texture: Texture2D=mat.get_shader_parameter("bake_texture")
			if not atlases.has(texture):
				var image:=texture.get_image()
				atlases[texture]={"width":image.get_width(),"height":image.get_height(),"sha256":digest(image.get_data())}
	return {"faces":level.get_meta("baked_light_faces",0),"invalid":level.get_meta("baked_light_invalid_faces",0),"overflow":level.get_meta("baked_light_overflow_faces",0),"unlit":level.get_meta("baked_light_unlit_faces",0),"rgb":level.get_meta("baked_light_rgb",false),"baked_materials":count,"surfaces":surfaces,"cutouts":cutouts,"glow":glow,"atlases":atlases.values()}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT+"cache")
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"input.json"))
	for row in input.rows:
		var start:=Time.get_ticks_usec()
		check(FileAccess.get_sha256(row.path)==row.sha256,row.id+": BSP checksum")
		var level:=Loader.read(row.path)
		check(level!=null,row.id+": fresh import")
		if not level:continue
		var before:=inspect(level)
		check(before.invalid==0 and before.overflow==0,row.id+": valid atlas extents")
		check((before.baked_materials>0)==row.expected_baked,row.id+": expected baked/legacy path")
		check(before.rgb==row.expected_rgb,row.id+": RGB/grayscale path")
		var packed:=PackedScene.new()
		check(packed.pack(level)==OK,row.id+": pack")
		var path: String=OUT+"cache/"+row.id+".scn"
		check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK,row.id+": save cache")
		level.free();packed=null
		var loaded: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		level=loaded.instantiate()
		check(inspect(level)==before,row.id+": fresh/cache atlas and material parity")
		Filtering.new().apply(level,2,true,1)
		check(inspect(level)==before,row.id+": shader upgrade preserves atlas and flags")
		var filter:=Filtering.new();filter.apply(level,0,false)
		for mat in filter.materials:
			if mat is ShaderMaterial and mat.shader==Filtering.BAKED:check(mat.get_shader_parameter("contrast_lighting")==true,row.id+": sampler switch preserves lighting")
		Filtering.new().apply(level,2,false,0)
		var after:=inspect(level)
		check(after==before,row.id+": restore preserves pixels/geometry")
		level.free();loaded=null;filter=null
		var shipping: String="res://maps/cache/"+row.id+("-lightmap1.scn" if row.expected_baked else ".scn")
		var shipping_result: Dictionary={}
		if row.category=="distribution" and FileAccess.file_exists(shipping):
			var scene: PackedScene=load(shipping);var cached:=scene.instantiate()
			Filtering.new().apply(cached,2,true,1)
			shipping_result=inspect(cached)
			check(shipping_result.faces==before.faces and shipping_result.atlases==before.atlases,row.id+": shipping/fresh lighting parity")
			cached.free();scene=null
		reports.append({"id":row.id,"category":row.category,"fresh":before,"shipping_cache":shipping_result,"seconds":(Time.get_ticks_usec()-start)/1000000.0})
		print("COVERAGE_IMPORT ",JSON.stringify(reports.back()))
		await process_frame
	FileAccess.open(OUT+"import.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":reports,"failures":failures},"  "))
	print("COVERAGE_IMPORT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
