extends RefCounted
# Opt-in original arenas: embedded RGBLIGHTING travels with the BSP, no sidecar required.
const SIZE := 1024
var atlas_size:=SIZE
var enabled := false
var lighting := PackedByteArray()
var rgb := PackedByteArray()
var image: Image
var texture: ImageTexture
var materials := {}
var cursor := Vector2i(2, 0)
var shelf := 0
var faces := 0
func open(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f or f.get_length()<124 or not f.get_32() in [29,0x32505342]:return
	var lumps: Array[Vector2i]=[]
	var end:=124
	for i in 15:
		var offset:=f.get_32();var length:=f.get_32()
		if offset+length>f.get_length():return
		lumps.append(Vector2i(offset,length));end=maxi(end,offset+length)
	f.seek(lumps[0].x)
	var world:=f.get_buffer(lumps[0].y).get_string_from_ascii().split("}")[0]
	if not world.contains('"_fpsloppa_bake" "1"'):return
	f.seek(lumps[8].x);lighting=f.get_buffer(lumps[8].y)
	if lighting.is_empty():return
	f.seek((end+3)&~3)
	if f.get_position()+8<=f.get_length() and f.get_buffer(4).get_string_from_ascii()=="BSPX":
		var count:=mini(f.get_32(),64)
		for i in count:
			if f.get_position()+32>f.get_length():break
			var name:=f.get_buffer(24).get_string_from_ascii();var offset:=f.get_32();var length:=f.get_32()
			if name=="RGBLIGHTING" and length==lighting.size()*3 and offset+length<=f.get_length():
				var saved:=f.get_position();f.seek(offset);rgb=f.get_buffer(length);f.seek(saved)
	atlas_size=4096 if world.contains('"_fpsloppa_atlas" "4096"') else 2048 if world.contains('"_fpsloppa_atlas" "2048"') else SIZE
	enabled=true
	image=Image.create(atlas_size,atlas_size,false,Image.FORMAT_RGB8);image.fill(Color(.5,.5,.5))
	texture=ImageTexture.create_from_image(image)
func face_uvs(uvs: PackedVector2Array, dimensions: Vector2, offset: int) -> PackedVector2Array:
	var result:=PackedVector2Array()
	if not enabled:return result
	var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
	for uv in uvs:
		var texel:=uv*dimensions/16.0;lo=lo.min(texel);hi=hi.max(texel)
	lo=lo.floor();hi=hi.ceil()
	var size:=Vector2i(hi-lo)+Vector2i.ONE
	if offset<0 or offset==0xffffffff or size.x<1 or size.y<1 or offset+size.x*size.y>lighting.size():
		for uv in uvs:result.append(Vector2(.5,.5)/atlas_size)
		return result
	if cursor.x+size.x+2>atlas_size:cursor=Vector2i(0,cursor.y+shelf);shelf=0
	if cursor.y+size.y+2>atlas_size:
		push_error("Arena baked-light atlas exceeds budget")
		for uv in uvs:result.append(Vector2(.5,.5)/atlas_size)
		return result
	# Replicated one-luxel gutters prevent filtering across unrelated faces.
	for y in range(-1,size.y+1):
		for x in range(-1,size.x+1):
			var at:=offset+clampi(y,0,size.y-1)*size.x+clampi(x,0,size.x-1)
			var c:=Color8(lighting[at],lighting[at],lighting[at])
			if not rgb.is_empty():c=Color8(rgb[at*3],rgb[at*3+1],rgb[at*3+2])
			image.set_pixel(cursor.x+x+1,cursor.y+y+1,c)
	for uv in uvs:result.append((uv*dimensions/16.0-lo+Vector2(cursor)+Vector2(1.5,1.5))/atlas_size)
	cursor.x+=size.x+2;shelf=maxi(shelf,size.y+2);faces+=1
	return result
func material(original: Material) -> Material:
	if not enabled or not original is StandardMaterial3D:return original
	if materials.has(original):return materials[original]
	var result:=ShaderMaterial.new();result.shader=preload("res://deathmatch/maps/baked_light.gdshader")
	result.set_shader_parameter("base_texture",original.albedo_texture)
	result.set_shader_parameter("base_colour",original.albedo_color)
	result.set_shader_parameter("alpha_cutout",original.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	result.set_shader_parameter("bake_texture",texture)
	if original.emission_enabled and original.emission_texture:
		result.set_shader_parameter("glow_texture",original.emission_texture)
		result.set_shader_parameter("has_glow",true)
	materials[original]=result
	return result
func finish(root: Node) -> void:
	if not enabled:return
	texture.update(image)
	root.set_meta("baked_light_faces",faces)
	root.set_meta("baked_light_rgb",not rgb.is_empty())
