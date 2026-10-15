extends RefCounted
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const Rig=preload("res://deathmatch/avatars/rig.gd")
static var frame_textures:Dictionary={} # Weak references let inactive models release GPU memory.
const AnimationShader=preload("res://deathmatch/avatars/vertex_lighting.gdshader")
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
		frames=preload("res://deathmatch/textures.gd").create(image);frame_textures[frame_hash]=weakref(frames)
	material.set_shader_parameter("positions",frames)
	material.set_shader_parameter("skin_atlas",preload("res://deathmatch/textures.gd").create(skin))
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
	library.scenes[hash]={"mesh":lods[0],"lod_meshes":lods,"clips":m.clips,"arm_profile":attachment_profile(m,decoded.positions)};library.touch_scene(hash);library.prune_scenes(hash);library.last_error=""
	return true
static func create_avatar(library:Node,hash:String) -> Node3D:
	if not prepare_avatar(library,hash,true):return null
	var rig:=Rig.new();rig.name="UT99Avatar";rig.avatar_hash=hash
	rig.configure(library.scenes[hash]);library.track_instance(hash,rig);return rig

static func attachment_profile(m:Dictionary,data:PackedByteArray) -> Dictionary:
	var profile:Dictionary=m.get("ik_profile",{}).duplicate(true)
	if profile.is_empty():return profile
	var targets:={"left":Rig.IK.vec(profile.left[2]),"right":Rig.IK.vec(profile.right[2])}
	var shoulders:Vector3=(Rig.IK.vec(profile.left[0])+Rig.IK.vec(profile.right[0]))*.5
	# Back surface sample at the pack contact plate, not an offset from the headset.
	targets.back=shoulders+Vector3(0,-.15,.16)
	profile.attachments={}
	for key in targets:
		var best:=-1;var distance:=INF
		var back_ids:=[-1,-1];var back_distances:=[INF,INF]
		for vertex in int(m.vertices):
			var weight:Array=m.ik_weights[vertex]
			if key=="back" and int(weight[0])!=0:continue
			if key!="back" and (int(weight[0])!=(1 if key=="left" else 2) or float(weight[1])<.95 or float(weight[2])<.95):continue
			var offset:=int(m.reference*m.vertices+vertex)*16
			var point:=Vector3(data.decode_float(offset),data.decode_float(offset+4),data.decode_float(offset+8))
			var d:float=point.distance_squared_to(targets[key])
			if d<distance:distance=d;best=vertex
			if key=="back":
				var side:=0 if point.x<shoulders.x else 1
				if d<back_distances[side]:back_distances[side]=d;back_ids[side]=vertex
		if best<0:continue
		var samples:=PackedVector3Array()
		for frame in int(m.frames):
			var indices:Array=back_ids if key=="back" and back_ids[0]>=0 and back_ids[1]>=0 else [best]
			var sample:=Vector3.ZERO
			for vertex in indices:
				var offset:=int(frame*m.vertices+vertex)*16
				sample+=Vector3(data.decode_float(offset),data.decode_float(offset+4),data.decode_float(offset+8))
			samples.append(sample/indices.size())
		profile.attachments[key]={"samples":samples,"reference":samples[int(m.reference)]}
	return profile
