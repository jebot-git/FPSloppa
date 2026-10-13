extends RefCounted
static func load_model(path: String) -> Array:
	var f:=FileAccess.open(path,FileAccess.READ);var bytes:=f.get_buffer(f.get_length())
	var nv:=bytes.decode_s32(60);var nt:=bytes.decode_s32(64);var nf:=bytes.decode_s32(68)
	var width:=bytes.decode_s32(52);var height:=bytes.decode_s32(56)
	var scale:=Vector3(bytes.decode_float(8),bytes.decode_float(12),bytes.decode_float(16));var base:=Vector3(bytes.decode_float(20),bytes.decode_float(24),bytes.decode_float(28))
	var cursor:=88+width*height
	var uv:=PackedVector2Array()
	for i in nv:uv.append(Vector2(bytes.decode_s32(cursor+i*12+4)+.5,bytes.decode_s32(cursor+i*12+8)+.5)/Vector2(width,height))
	cursor+=nv*12
	var indices:=PackedInt32Array()
	for i in nt:
		for corner in 3:indices.append(bytes.decode_s32(cursor+i*16+4+corner*4))
	cursor+=nt*16
	var frames:=Image.create(nv,nf,false,Image.FORMAT_RGBAF);var rest:=PackedVector3Array()
	for frame in nf:
		cursor+=28
		for i in nv:
			var p: Vector3=Vector3(bytes[cursor+i*4],bytes[cursor+i*4+1],bytes[cursor+i*4+2])*scale+base
			p=Vector3(-p.y,p.z,p.x)*(1.7/56)
			frames.set_pixel(i,frame,Color(p.x,p.y,p.z,1))
			if frame==0:rest.append(p)
		cursor+=nv*4
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=rest;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=ShaderMaterial.new();material.shader=preload("res://tools/vrm_to_mdl/frames.gdshader")
	material.set_shader_parameter("vertex_frames",ImageTexture.create_from_image(frames));material.set_shader_parameter("skin",ImageTexture.create_from_image(Image.load_from_file(path.trim_suffix(".mdl")+"-skin.png")))
	return [mesh,material]
