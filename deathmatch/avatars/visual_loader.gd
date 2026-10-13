extends RefCounted
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const Rig=preload("res://deathmatch/avatars/rig.gd")
static var frame_textures:Dictionary={} # Weak references let inactive models release GPU memory.
const AnimationShader=preload("res://deathmatch/avatars/vertex_animation.gdshader")
static func prepare_avatar(library:Node,hash:String,_wait:bool=false) -> bool:
	if not library.entries.has(hash):return false
	if library.scenes.has(hash):library.touch_scene(hash);return true
	var decoded:=Format.read(library.entries[hash].path)
	if decoded.has("error"):library.last_error=decoded.error;return false
	var m:Dictionary=decoded.manifest
	var image:=Image.create_from_data(int(m.width),int(m.height),false,Image.FORMAT_RGBAF,decoded.positions)
	var skin:=Image.new()
	if skin.load_png_from_buffer(decoded.skin)!=OK:library.last_error="Cannot decode UT99 skin.";return false
	skin.generate_mipmaps()
	var material:=ShaderMaterial.new();material.shader=AnimationShader
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(decoded.positions)
	var frame_hash:=digest.finish().hex_encode()
	var frames:Texture2D=frame_textures[frame_hash].get_ref() if frame_textures.has(frame_hash) else null
	if frames==null:
		frames=ImageTexture.create_from_image(image);frame_textures[frame_hash]=weakref(frames)
	material.set_shader_parameter("positions",frames)
	material.set_shader_parameter("skin_atlas",ImageTexture.create_from_image(skin))
	material.set_shader_parameter("reference_frame",int(m.reference))
	material.set_shader_parameter("vertex_count",int(m.vertices));material.set_shader_parameter("position_width",int(m.width))
	var points:=PackedVector3Array();var uv:=PackedVector2Array();var ids:=PackedVector2Array();var ik:=PackedFloat32Array()
	for c in m.corners:
		var offset:=int(m.reference*m.vertices+c[0])*16
		points.append(Vector3(decoded.positions.decode_float(offset),decoded.positions.decode_float(offset+4),decoded.positions.decode_float(offset+8)))
		uv.append(Vector2(c[1],c[2]));ids.append(Vector2(c[0],m.arm_weights[int(c[0])] if m.has("arm_profile") else 0))
		var w:Array=m.ik_weights[int(c[0])] if m.has("ik_profile") else [0,0,0]
		ik.append_array(PackedFloat32Array([w[0],w[1],w[2],0]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=ids;arrays[Mesh.ARRAY_CUSTOM0]=ik
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))
	mesh.surface_set_material(0,material)
	var b:Array=m.bounds;mesh.custom_aabb=AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5])).grow(.03)
	if m.has("arm_profile") or m.has("ik_profile"):mesh.custom_aabb=mesh.custom_aabb.merge(AABB(Vector3(-1.7,-1,-1.7),Vector3(3.4,5,3.4)))
	var lods:=preload("res://deathmatch/avatars/vertex_lod.gd").build(mesh)
	library.scenes[hash]={"mesh":lods[0],"lod_meshes":lods,"clips":m.clips,"arm_profile":m.get("ik_profile",{})};library.touch_scene(hash);library.prune_scenes(hash);library.last_error=""
	return true
static func create_avatar(library:Node,hash:String) -> Node3D:
	if not prepare_avatar(library,hash,true):return null
	var rig:=Rig.new();rig.name="UT99Avatar";rig.avatar_hash=hash
	rig.configure(library.scenes[hash]);library.track_instance(hash,rig);return rig
