extends RefCounted
const Reader = preload("res://addons/bsp_importer/bsp_reader.gd")
const SCALE := 1.0/32.0
static func catalog() -> Array:
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
	if FileAccess.file_exists("user://maps/catalog.json"):
		var custom=JSON.parse_string(FileAccess.get_file_as_string("user://maps/catalog.json"))
		if custom is Array:
			for row in custom:
				if row is Dictionary and row.has("scene") and FileAccess.file_exists(row.scene): rows.append(row)
	return rows
static func point(value: String) -> Vector3:
	var v := value.split_floats(" ",false)
	return Vector3(-v[1],v[2],-v[0])*SCALE if v.size()==3 else Vector3.ZERO
static func validate(path: String) -> String:
	var f := FileAccess.open(path,FileAccess.READ)
	if not f: return "Cannot read BSP."
	if f.get_length()<124 or f.get_length()>128_000_000: return "BSP must be between 124 bytes and 128 MB."
	if not f.get_32() in [29,0x32505342,0x42535032]: return "Only Quake I BSP29 and BSP2 are supported."
	for i in range(15):
		var offset := f.get_32()
		var length := f.get_32()
		if offset<0 or length<0 or offset+length>f.get_length(): return "BSP lump extends beyond file."
	return validate_geometry(path)
static func read(path: String) -> Node3D:
	if not validate(path).is_empty(): return null
	var reader := Reader.new()
	reader.unit_scale = SCALE
	reader.generate_texture_materials = true
	reader.transparent_texture_prefix = "{"
	reader.save_separate_materials = false
	reader.material_path_pattern = "res://deathmatch/maps/materials/{texture_name}.tres"
	reader.texture_path_pattern = "res://deathmatch/maps/textures/{texture_name}.png"
	reader.texture_emission_path_pattern = "res://deathmatch/maps/textures/{texture_name}_emission.png"
	reader.texture_palette_path = "res://deathmatch/maps/palette.lmp"
	reader.generate_lightmap_uv2 = false
	reader.generate_occlusion_culling = true
	reader.generate_shadow_mesh = false
	reader.use_triangle_collision = true
	reader.ignore_missing_entities = true
	reader.import_lights = false
	reader.include_sky_surfaces = false
	reader.entity_path_pattern = "res://deathmatch/maps/point.tscn"
	for name in ["func_door","func_plat","func_wall","func_button","func_train","func_illusionary"]:
		reader.entity_remap[name] = "res://deathmatch/maps/brush.tscn"
	for name in ["trigger_teleport","trigger_hurt","trigger_push","trigger_multiple","trigger_once"]:
		reader.entity_remap[name] = "res://deathmatch/maps/trigger.tscn"
	reader.water_template = load("res://addons/bsp_importer/examples/water_example_template.tscn")
	reader.slime_template = load("res://addons/bsp_importer/examples/slime_example_template.tscn")
	reader.lava_template = load("res://addons/bsp_importer/examples/lava_example_template.tscn")
	var result: Node3D = reader.read_bsp(path)
	if result:
		# Preserve trigger volumes even where their faces use invisible textures.
		var file := FileAccess.open(path,FileAccess.READ)
		file.seek(116)
		var models_offset := file.get_32()
		var models_size := file.get_32()
		for node in result.get_children():
			if not node is Area3D or not "attributes" in node: continue
			var model: String = node.attributes.get("model","")
			if not model.begins_with("*"): continue
			var index := model.substr(1).to_int()
			if index*64+24>models_size: continue
			file.seek(models_offset+index*64)
			var minimum := Reader.read_vector_convert_unscaled(file)*SCALE
			var maximum := Reader.read_vector_convert_unscaled(file)*SCALE
			var bounds := AABB(minimum,Vector3.ZERO).expand(maximum)
			for shape in node.get_children():
				if shape is CollisionShape3D: shape.free()
			add_volume_box(node,result,bounds,node.transform.affine_inverse())
		var brush_data = reader.bspx_model_to_brush_map.get(0)
		if brush_data:
			for brush in brush_data.brush_array:
				if not brush.contents in [-3,-4,-5]: continue
				var area := Area3D.new()
				area.name = "Water" if brush.contents==-3 else "Slime" if brush.contents==-4 else "Lava"
				area.collision_layer=0
				area.collision_mask=2
				result.add_child(area,true)
				area.owner=result
				add_volume_box(area,result,AABB(brush.mins,Vector3.ZERO).expand(brush.maxs),Transform3D.IDENTITY)
	reader.free()
	return result

static func add_volume_box(parent: Node3D, owner_root: Node3D, bounds: AABB, inverse: Transform3D) -> void:
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=bounds.size.max(Vector3.ONE*.01)
	collision.shape=shape
	collision.transform=inverse*Transform3D(Basis.IDENTITY,bounds.get_center())
	parent.add_child(collision)
	collision.owner=owner_root

static func import_custom(path: String,title_override: String="") -> Dictionary:
	var error:=validate(path)
	if not error.is_empty(): return {"error":error}
	var checksum:=FileAccess.get_sha256(path)
	var id:="custom_"+checksum
	for row in catalog():
		if row.sha256==checksum: return row
	var root:=read(path)
	if not root: return {"error":"BSP importer could not build this map."}
	var spawns:=0
	for node in root.get_children():
		if "attributes" in node and node.attributes.get("classname","")=="info_player_deathmatch": spawns+=1
	if spawns<2:
		root.free()
		return {"error":"A deathmatch BSP needs at least two info_player_deathmatch entities."}
	DirAccess.make_dir_recursive_absolute("user://maps")
	var packed:=PackedScene.new()
	packed.pack(root)
	root.free()
	var scene_path:="user://maps/"+id+".scn"
	if ResourceSaver.save(packed,scene_path)!=OK: return {"error":"Could not cache the imported scene."}
	var raw_path:="user://maps/"+id+".bsp"
	if DirAccess.copy_absolute(path,raw_path)!=OK: return {"error":"Could not copy BSP to map library."}
	var row:={"id":id,"title":title_override.left(60) if not title_override.is_empty() else path.get_file().get_basename().left(60),"path":raw_path,"scene":scene_path,"sha256":checksum}
	var custom: Array=[]
	for existing in catalog():
		if existing.id.begins_with("custom_"): custom.append(existing)
	custom.append(row)
	var file:=FileAccess.open("user://maps/catalog.json",FileAccess.WRITE)
	if not file: return {"error":"Could not save map library."}
	file.store_string(JSON.stringify(custom))
	return row

static func validate_geometry(path: String) -> String:
	var bytes:=FileAccess.get_file_as_bytes(path)
	var bsp2:=bytes.decode_u32(0)!=29
	var offsets: Array=[]
	var sizes: Array=[]
	for i in range(15):
		offsets.append(bytes.decode_u32(4+i*8))
		sizes.append(bytes.decode_u32(8+i*8))
	if sizes[0]>2_000_000: return "Map entity data is too large."
	var records: Dictionary={1:20,3:12,6:40,7:28 if bsp2 else 20,12:8 if bsp2 else 4,13:4,14:64}
	for i in records:
		if sizes[i]%records[i]!=0 or sizes[i]/records[i]>262144: return "Invalid or excessive BSP geometry records."
	if sizes[14]/64>4096: return "Too many brush models."
	for i in range(int(sizes[3]/4)):
		var value:=bytes.decode_float(offsets[3]+i*4)
		if not is_finite(value) or absf(value)>10_000_000: return "Invalid BSP vertex coordinate."
	if sizes[2]<4: return "Missing embedded texture table."
	var count:=bytes.decode_s32(offsets[2])
	if count<0 or count>2048 or 4+count*4>sizes[2]: return "Invalid texture table."
	var pixels:=0
	for i in range(count):
		var rel:=bytes.decode_s32(offsets[2]+4+i*4)
		if rel==-1: continue
		if rel<4 or rel+40>sizes[2]: return "Invalid texture header."
		var at: int=offsets[2]+rel
		var name:=bytes.slice(at,at+16).get_string_from_ascii()
		if name.contains("/") or name.contains("\\") or name.contains(".."): return "Invalid texture name."
		var width:=bytes.decode_u32(at+16)
		var height:=bytes.decode_u32(at+20)
		if width<1 or height<1 or width>2048 or height>2048: return "Texture dimensions exceed map limits."
		pixels+=width*height
		if pixels>33_554_432: return "Map textures exceed 32 megapixels."
		for mip in range(4):
			var start:=bytes.decode_u32(at+24+mip*4)
			if start>0 and (start<40 or rel+start+maxi(1,width>>mip)*maxi(1,height>>mip)>sizes[2]): return "Texture pixels outside BSP."
	var edge_size:=8 if bsp2 else 4
	var vertex_count: int=sizes[3]/12
	var edge_count: int=sizes[12]/edge_size
	for i in range(edge_count*2):
		var index:=bytes.decode_u32(offsets[12]+i*4) if bsp2 else bytes.decode_u16(offsets[12]+i*2)
		if index>=vertex_count: return "Edge references missing vertex."
	for i in range(int(sizes[13]/4)):
		if absi(bytes.decode_s32(offsets[13]+i*4))>=edge_count: return "Surface references missing edge."
	for i in range(int(sizes[6]/40)):
		var at: int=offsets[6]+i*40
		for component in range(8):
			if not is_finite(bytes.decode_float(at+component*4)): return "Invalid texture coordinates."
		if bytes.decode_u32(at+32)>=count: return "Missing texture reference."
	var face_size:=28 if bsp2 else 20
	for i in range(int(sizes[7]/face_size)):
		var at: int=offsets[7]+i*face_size
		var first:=bytes.decode_u32(at+(8 if bsp2 else 4))
		var length:=bytes.decode_u32(at+12) if bsp2 else bytes.decode_u16(at+8)
		var texture:=bytes.decode_u32(at+16) if bsp2 else bytes.decode_u16(at+10)
		if length>4096 or first+length>sizes[13]/4 or texture>=sizes[6]/40: return "Invalid face bounds."
	for i in range(int(sizes[14]/64)):
		var at: int=offsets[14]+i*64
		if bytes.decode_u32(at+56)+bytes.decode_u32(at+60)>sizes[7]/face_size: return "Invalid brush face range."
	return ""
