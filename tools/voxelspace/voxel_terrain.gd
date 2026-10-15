extends Node3D
## Offline greedy chunks; runtime changes visibility and prebuilt LOD meshes only.
var chunks: Array=[]
var material: ShaderMaterial
var last_position:=Vector3.INF
var last_rotation:=Vector3.INF
var counts: Array=[]
var triangles:=0
var force_full:=false
var merged_lod:=-1
func load_stream(path: String) -> StreamPeerBuffer:
	var packed:=FileAccess.get_file_as_bytes(path)
	var stream:=StreamPeerBuffer.new();stream.big_endian=false;stream.data_array=packed.slice(4).decompress(packed.decode_u32(0),FileAccess.COMPRESSION_DEFLATE);return stream
func read_mesh(file: StreamPeerBuffer) -> ArrayMesh:
	var count:=file.get_u32();var index_count:=file.get_u32()
	var flat: PackedFloat32Array=file.get_data(count*12)[1].to_float32_array();var normal_flat: PackedFloat32Array=file.get_data(count*12)[1].to_float32_array();var indices: PackedInt32Array=file.get_data(index_count*4)[1].to_int32_array()
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	for i in count:vertices.append(Vector3(flat[i*3],flat[i*3+1],flat[i*3+2]));normals.append(Vector3(normal_flat[i*3],normal_flat[i*3+1],normal_flat[i*3+2]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material);return mesh
func setup(map,full: bool=false,merged: int=-1) -> void:
	force_full=full;merged_lod=merged
	material=ShaderMaterial.new();material.shader=preload("res://tools/voxelspace/voxel_surface.gdshader");material.set_shader_parameter("colors",map.color_texture)
	if merged>=0:
		var file:=load_stream("res://tools/voxelspace/assets/terrain-voxels-merged.vxz")
		var magic:String=file.get_data(4)[1].get_string_from_ascii()
		if magic!="VXMG":push_error("Invalid merged voxel terrain header");return
		var levels:=file.get_u32()
		for lod in levels:
			var mesh:=read_mesh(file)
			if lod==merged:
				var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(instance);triangles=mesh.surface_get_array_index_len(0)/3
		return
	var file:=load_stream("res://tools/voxelspace/assets/terrain-voxels.vxz")
	var magic:String=file.get_data(4)[1].get_string_from_ascii()
	if magic!="VXCH":push_error("Invalid voxel terrain header");return
	var count:=file.get_u32();var levels:=file.get_u32()
	for i in count:
		var origin:=Vector3(file.get_float(),0,file.get_float());var meshes: Array=[]
		for lod in levels:meshes.append(read_mesh(file))
		var instance:=MeshInstance3D.new();instance.mesh=meshes[0];instance.position=origin;instance.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(instance)
		chunks.append({"node":instance,"meshes":meshes,"lod":0})
func update(camera: Camera3D) -> void:
	if merged_lod>=0:return
	if camera.global_position==last_position and camera.rotation==last_rotation:return
	last_position=camera.global_position;last_rotation=camera.rotation;counts=[0,0,0];triangles=0
	var planes:=camera.get_frustum()
	for item in chunks:
		var center: Vector3=item.node.position+Vector3(15.625,8,15.625);var visible:=true
		for plane in planes:
			if plane.distance_to(center)>32:visible=false;break
		item.node.visible=visible
		if not visible:continue
		var distance:=Vector2(center.x-camera.global_position.x,center.z-camera.global_position.z).length()
		var lod: int=item.lod
		if force_full:lod=0
		else:
			# Resolve both transitions before caching a stationary camera.
			while lod<2 and distance>[45.0,100.0][lod]:lod+=1
			while lod>0 and distance<[35.0,80.0][lod-1]:lod-=1
		if lod!=item.lod:item.node.mesh=item.meshes[lod];item.lod=lod
		counts[lod]+=1;triangles+=item.node.mesh.surface_get_array_index_len(0)/3
