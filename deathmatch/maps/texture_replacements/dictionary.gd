extends RefCounted
# A bounded, packaged dictionary; never resolve paths supplied by an imported map.
const MANIFEST="res://deathmatch/maps/texture_replacements/manifest.json"
const PACK="res://deathmatch/maps/texture_replacements/replacement-miptex.lmp"
static var manifest: Dictionary={}
static var textures: Dictionary={}
static var warned: Dictionary={}
static func version() -> String:
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return str(manifest.get("version","missing"))
static func resolve(name: String) -> Dictionary:
	version()
	var key:=name.to_lower()
	if not manifest.textures.has(key):
		if not warned.has(key):
			push_warning("BSP texture '%s' has no reviewed replacement; using neutral stone."%key)
			warned[key]=true
		key="_fallback"
	if textures.has(key):return textures[key]
	var row: Dictionary=manifest.textures[key]
	var f:=FileAccess.open(PACK,FileAccess.READ)
	if not f:return {}
	f.seek(int(row.offset)+40)
	var width:=int(row.width);var height:=int(row.height)
	var pixels:=f.get_buffer(width*height)
	var palette:=FileAccess.get_file_as_bytes("res://deathmatch/maps/palette.lmp")
	var colour:=PackedByteArray();colour.resize(width*height*4)
	var glow:=PackedByteArray();glow.resize(width*height*4)
	var has_glow:=false
	for i in pixels.size():
		var index:=int(pixels[i])
		if key.begins_with("{") and index==255:continue
		colour[i*4+3]=255;glow[i*4+3]=255
		for channel in 3:
			if index>=224:
				glow[i*4+channel]=palette[index*3+channel];has_glow=true
			else:colour[i*4+channel]=palette[index*3+channel]
	var image:=Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,colour);image.generate_mipmaps()
	var result: Dictionary={"texture":ImageTexture.create_from_image(image),"key":key}
	if has_glow:
		image=Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,glow);image.generate_mipmaps()
		result.emission=ImageTexture.create_from_image(image)
	textures[key]=result
	return result
# Called only after normal BSP validation, so header reads stay bounded.
static func has_missing(path: String) -> bool:
	var f:=FileAccess.open(path,FileAccess.READ)
	if not f or f.get_length()<124:return false
	f.seek(20);var offset:=f.get_32();var size:=f.get_32()
	if size<4 or offset+size>f.get_length():return false
	f.seek(offset);var count:=f.get_32()
	if count>2048 or 4+count*4>size:return false
	for i in count:
		f.seek(offset+4+i*4);var relative:=f.get_32()
		if relative==0xffffffff:return true
		if relative+40>size:continue
		f.seek(offset+relative+24)
		if f.get_32()==0:return true
	return false
