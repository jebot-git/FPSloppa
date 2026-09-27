extends SceneTree
## Inspect actual loaded mip chains, including embedded model/map textures.
## godot --headless --xr-mode off --path . --script tools/audit_mipmaps.gd
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Loader=preload("res://deathmatch/maps/loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
const IMPORT_ROOTS=["res://deathmatch","res://addons/godot-xr-tools/hands","res://addons/godot-xr-tools/images","res://addons/godot-xr-tools/assets"]
var rows: Array=[]
var failures: Array=[]
var textures: Dictionary={}
var materials: Dictionary={}
var current: Dictionary={}
func _initialize() -> void:call_deferred("run")
func files_at(folder: String) -> Array:
	var result: Array=[]
	for file in DirAccess.get_files_at(folder):result.append(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):
		if not child.begins_with("."):result.append_array(files_at(folder.path_join(child)))
	return result
func begin(path: String,kind: String) -> void:
	textures.clear();materials.clear()
	current={"path":path,"kind":kind,"textures":0,"mipmapped":0,"one_pixel":0,"data_samplers":0,"viewports":0,"materials":0,"failures":[]}
func finish() -> void:
	rows.append(current.duplicate(true));textures.clear();materials.clear()
	print("MIP_ASSET ",JSON.stringify(current))
func fail(reason: String) -> void:
	current.failures.append(reason);failures.append(current.path+": "+reason)
func texture(value: Texture2D,label: String,data: bool=false) -> void:
	if not value:return
	if data:current.data_samplers+=1;return
	if value is ViewportTexture:current.viewports+=1;return
	if textures.has(value):return
	textures[value]=true;current.textures+=1
	var image:=value.get_image()
	if not image:fail(label+": missing pixels");return
	var size:=maxi(image.get_width(),image.get_height());var expected:=0
	while size>1:expected+=1;size=size>>1
	if expected==0:current.one_pixel+=1;return
	if not image.has_mipmaps() or image.get_mipmap_count()!=expected:
		fail(label+": incomplete mip chain (%d/%d)"%[image.get_mipmap_count(),expected]);return
	current.mipmapped+=1
func material(value: Material,label: String) -> void:
	if not value or materials.has(value):return
	materials[value]=true;current.materials+=1
	material(value.next_pass,label+"/next_pass")
	if value is BaseMaterial3D:
		if Filtering.new().textured(value) and not value.texture_filter in Filtering.FILTERS:fail(label+": sampler omits mipmaps")
		for slot in BaseMaterial3D.TEXTURE_MAX:texture(value.get_texture(slot),label+"/"+str(slot))
	elif value is ShaderMaterial and value.shader:
		for uniform in value.shader.get_shader_uniform_list():
			var parameter=value.get_shader_parameter(uniform.name)
			if parameter is Texture2D:texture(parameter,label+"/"+uniform.name,uniform.name in Filtering.DATA_SAMPLERS)
func node(value: Node) -> void:
	if value is GeometryInstance3D:
		material(value.material_override,str(value.name)+"/override");material(value.material_overlay,str(value.name)+"/overlay")
	if value is Sprite3D:
		texture(value.texture,str(value.name))
		if value.texture and not value.texture is ViewportTexture and not value.texture_filter in Filtering.FILTERS:fail(str(value.name)+": sprite sampler omits mipmaps")
	var meshes: Array=[]
	if value is MeshInstance3D or value is CPUParticles3D:meshes.append(value.mesh)
	elif value is MultiMeshInstance3D and value.multimesh:meshes.append(value.multimesh.mesh)
	elif value is GPUParticles3D:
		for index in value.draw_passes:meshes.append(value.get_draw_pass_mesh(index))
	for mesh in meshes:
		if not mesh:continue
		for index in mesh.get_surface_count():material(value.get_active_material(index) if value is MeshInstance3D else value.material_override if value.material_override else mesh.surface_get_material(index),str(value.name)+"/"+str(index))
	if value is Decal:
		for slot in Decal.TEXTURE_MAX:texture(value.get_texture(slot),str(value.name)+"/"+str(slot))
	for child in value.get_children():node(child)
func scene(path: String) -> void:
	begin(path,"model")
	var packed=load(path)
	if packed is PackedScene:
		var instance: Node=packed.instantiate();Filtering.new().apply(instance);node(instance);instance.free()
	else:fail("Could not load scene")
	finish()
func run() -> void:
	var paths: Array=[]
	for folder in IMPORT_ROOTS:paths.append_array(files_at(folder))
	paths.sort()
	for path in paths:
		if path.ends_with(".import"):
			var config:=ConfigFile.new()
			if config.load(path)!=OK or config.get_value("remap","importer","")!="texture":continue
			begin(path.trim_suffix(".import"),"import")
			texture(load(current.path),"imported texture");finish()
	for folder in ["res://deathmatch/weapons","res://deathmatch/vehicles","res://deathmatch/pickups","res://addons/godot-xr-tools/hands"]:
		for path in files_at(folder):
			if path.get_extension() in ["scn","glb","gltf","tscn"]:
				scene(path);await process_frame
	var manifest: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
	var shipped:=manifest.map(func(row):return row.id)
	for row in Loader.catalog():
		if not row.id in shipped:continue
		begin(row.id,"map")
		var packed:=Loader.scene(row)
		if packed:
			var instance:=packed.instantiate();Filtering.new().apply(instance);node(instance);instance.free()
		else:fail("Could not load map")
		finish();await process_frame
	var library:=Library.new();library.reload()
	for hash in library.entries:
		begin(library.entries[hash].path,"avatar")
		var avatar:=library.create_avatar(hash)
		if avatar:Filtering.new().apply(avatar);node(avatar);avatar.free()
		else:fail(library.last_error)
		finish();await process_frame
	library.free()
	var totals: Dictionary={}
	for row in rows:
		if not totals.has(row.kind):totals[row.kind]={"assets":0,"textures":0,"mipmapped":0,"one_pixel":0,"data_samplers":0}
		totals[row.kind].assets+=1
		for key in ["textures","mipmapped","one_pixel","data_samplers"]:totals[row.kind][key]+=row[key]
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"totals":totals,"failures":failures,"assets":rows}
	DirAccess.make_dir_recursive_absolute("res://test-results/mipmaps")
	var output:=FileAccess.open("res://test-results/mipmaps/assets.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
	print("MIPMAP_AUDIT_RESULT ",JSON.stringify({"totals":totals,"failures":failures}));quit(0 if failures.is_empty() else 1)
