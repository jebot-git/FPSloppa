extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const OUT="res://test-results/lighting-ao-distribution/"
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"bake.json"))
	var reports: Array=[]
	DirAccess.make_dir_recursive_absolute(OUT+"cache")
	for row in input.maps:
		var nodes: Array=[];var metrics: Array=[];var uvs: Array=[]
		for variant in ["original","off","low"]:
			var level:=Loader.read(OUT+variant+"/"+row.id+".bsp")
			check(level!=null,row.id+": "+variant+" loads")
			if not level:continue
			nodes.append(level);metrics.append(inspect(level));uvs.append(uv_signature(level))
			check(metrics.back().invalid==0 and metrics.back().overflow==0,row.id+": "+variant+" atlas valid")
			check(metrics.back().rgb and metrics.back().baked_materials>0,row.id+": "+variant+" RGB bake")
		if nodes.size()!=3:
			for node in nodes:node.free()
			continue
		check(uvs[0]==uvs[1] and uvs[1]==uvs[2],row.id+": original/off/low UVs identical")
		for field in ["faces","invalid","overflow","unlit","rgb","baked_materials","surfaces","cutouts","glow"]:
			check(metrics[0][field]==metrics[2][field],row.id+": preserve "+field)
		check(metrics[0].atlases.size()==1 and metrics[2].atlases.size()==1,row.id+": one atlas")
		check(metrics[0].atlases[0].width==metrics[2].atlases[0].width and metrics[0].atlases[0].height==metrics[2].atlases[0].height,row.id+": atlas dimensions unchanged")
		var packed:=PackedScene.new();check(packed.pack(nodes[2])==OK,row.id+": pack AO cache")
		var path: String=OUT+"cache/"+row.id+".scn"
		check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK,row.id+": save AO cache")
		for node in nodes:node.free()
		packed=null
		var cached: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var restored:=cached.instantiate();check(inspect(restored)==metrics[2],row.id+": cache round-trip")
		restored.free();cached=null
		reports.append({"id":row.id,"original":metrics[0],"off":metrics[1],"low":metrics[2],"cache_sha256":FileAccess.get_sha256(path)})
		FileAccess.open(OUT+"import.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":reports,"failures":failures},"  "))
		print("AO_DISTRIBUTION_IMPORT ",row.id," failures=",failures.size())
		await process_frame
	print("AO_DISTRIBUTION_IMPORT_RESULT ",failures);quit(0 if failures.is_empty() else 1)

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

func uv_signature(level: Node) -> Array:
	var result: Array=[]
	for node in level.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		for i in node.mesh.get_surface_count():
			var uv=node.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV2]
			if uv==null:continue
			var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(uv.to_byte_array());result.append(digest.finish().hex_encode())
	result.sort();return result
