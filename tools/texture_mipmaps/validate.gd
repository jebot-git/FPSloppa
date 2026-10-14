extends SceneTree
const Mips=preload("res://deathmatch/textures.gd")
var failures:Array=[]
var imported:=0
var runtime:=0
var embedded:=0
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func scan(path:String) -> void:
	var directory:=DirAccess.open(path)
	if not directory:return
	for name in directory.get_files():
		if not name.ends_with(".import"):continue
		var text:=FileAccess.get_file_as_string(path.path_join(name))
		if not text.contains('importer="texture"'):continue
		var config:=ConfigFile.new();check(config.load(path.path_join(name))==OK,"read import "+name)
		var source:String=config.get_value("deps","source_file","")
		var texture=load(source)
		if not texture is Texture2D:continue
		var image:Image=texture.get_image()
		if image and maxi(image.get_width(),image.get_height())>1:
			imported+=1;check(image.has_mipmaps(),"imported texture "+source)
	for name in directory.get_directories():
		if name.begins_with("."):continue
		scan(path.path_join(name))
func inspect_material(material:Material,label:String) -> void:
	if not material:return
	var textures:Array=[]
	if material is BaseMaterial3D:
		for slot in BaseMaterial3D.TEXTURE_MAX:
			var texture=material.get_texture(slot)
			if texture:textures.append(texture)
	elif material is ShaderMaterial and material.shader:
		for uniform in material.shader.get_shader_uniform_list():
			var texture=material.get_shader_parameter(uniform.name)
			if texture is Texture2D:textures.append(texture)
	for texture in textures:
		var image:Image=texture.get_image()
		if image and maxi(image.get_width(),image.get_height())>1:
			embedded+=1;check(image.has_mipmaps(),"embedded material texture "+label)
func scan_models(path:String) -> void:
	var directory:=DirAccess.open(path)
	if not directory:return
	for name in directory.get_files():
		if name.get_extension() not in ["glb","gltf","res","tres"]:continue
		var asset=load(path.path_join(name))
		if asset is Mesh:
			for surface in asset.get_surface_count():inspect_material(asset.surface_get_material(surface),name)
		elif asset is PackedScene:
			var node=asset.instantiate()
			var nodes:Array=node.find_children("*","MeshInstance3D",true,false)
			if node is MeshInstance3D:nodes.append(node)
			for part in nodes:
				if part.mesh:
					for surface in part.mesh.get_surface_count():inspect_material(part.get_active_material(surface),name)
			node.free()
		elif asset is Material:inspect_material(asset,name)
	for name in directory.get_directories():
		if not name.begins_with("."):scan_models(path.path_join(name))
func run() -> void:
	DisplayServer.window_set_title("FPSloppa · texture mipmap validation")
	check(ProjectSettings.get_setting("importer_defaults/texture",{}).get("mipmaps/generate",false),"New imports default to mipmaps")
	scan("res://")
	for path in ["res://deathmatch/models","res://deathmatch/weapons","res://experimental-assets/jungle"]:scan_models(path)
	for format in [Image.FORMAT_RGBA8,Image.FORMAT_RF,Image.FORMAT_RGBAF]:
		var source:=Image.create(65,65,false,format);source.fill(Color(.3,.4,.5,1));var base:=source.get_data()
		var prepared:=Mips.image(source);runtime+=1
		check(prepared.has_mipmaps(),"Runtime image mipmaps, format "+str(format))
		var copy:Image=prepared.duplicate();copy.clear_mipmaps()
		check(copy.get_data()==base,"Exact lookup/height base pixels preserved")
		var size:=prepared.get_data_size();check(Mips.image(prepared).get_data_size()==size,"Mipmaps never regenerated when already present")
		var texture:=Mips.create(prepared);check(texture.get_image().has_mipmaps(),"Runtime GPU texture mipmaps")
	var bake=preload("res://deathmatch/maps/baked_light.gd").new()
	bake.enabled=true;bake.image=Image.create(32,32,false,Image.FORMAT_RGB8);bake.image.fill(Color.BLACK)
	bake.texture=Mips.create(bake.image);bake.image.set_pixel(1,0,Color.WHITE)
	var level:=Node3D.new();root.add_child(level);bake.finish(level)
	var finished:Image=bake.texture.get_image();var bytes:=finished.get_data()
	check(finished.has_mipmaps() and bytes[finished.get_mipmap_offset(1)]>50,"Finished light atlas regenerates mipmaps after base pixels change");runtime+=1
	var library=preload("res://deathmatch/avatars/library.gd").new();root.add_child(library)
	var hash:String=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false)
	var avatar=library.create_avatar(hash);root.add_child(avatar)
	var material:ShaderMaterial=avatar.visual.mesh.surface_get_material(0)
	for key in ["skin_atlas","positions"]:
		check(material.get_shader_parameter(key).get_image().has_mipmaps(),"UT99 "+key+" mipmaps");runtime+=1
	var stream=preload("res://tools/streamed_heightfield/stream.gd").new();root.add_child(stream);stream.setup()
	for texture in [stream.coarse_colors,stream.coarse_heights,stream.pages]:
		check(texture.get_image().has_mipmaps(),"Terrain fallback/table mipmaps");runtime+=1
	for texture in [stream.color_tiles,stream.height_tiles]:
		check(texture.get_layer_data(0).has_mipmaps(),"Terrain streamed array mipmaps");runtime+=1
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,40,0);camera.current=true
	var deadline:=Time.get_ticks_msec()+10000
	while stream.loaded_total==0 and Time.get_ticks_msec()<deadline:
		stream.tick(camera);await process_frame
	check(stream.loaded_total>0,"Actual streaming upload completed")
	if stream.loaded_total>0:
		var slot:int=stream.resident.values()[0]
		check(stream.color_tiles.get_layer_data(slot).has_mipmaps() and stream.height_tiles.get_layer_data(slot).has_mipmaps(),"Actual uploaded tile layers retain mipmaps")
	stream.shutdown()
	print("TEXTURE_MIPMAPS_RESULT ",JSON.stringify({"imported":imported,"runtime":runtime,"embedded":embedded,"failures":failures}));quit(0 if failures.is_empty() else 1)
