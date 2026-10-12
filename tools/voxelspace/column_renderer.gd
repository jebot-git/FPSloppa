extends Node3D
## Main RenderingDevice; no per-frame CPU image readback or rd.sync().
var rd: RenderingDevice
var shader:=RID()
var pipeline:=RID()
var uniform_set:=RID()
var height_buffer:=RID()
var color_buffer:=RID()
var color_rid:=RID()
var depth_rid:=RID()
var color_texture:=Texture2DRD.new()
var depth_texture:=Texture2DRD.new()
var quad: MeshInstance3D
var ready_gpu:=false
var failure:=""
var resolution:=Vector2i(1440,900)
var extent:=250.0
var samples:=513
var base_step:=.25
var adaptive_step:=.007
var far_distance:=250.0
var compute_gpu_ms:=0.0
var timestamp_raw:=0
var dispatch_cpu_ms:=0.0
var dispatches:=0
func setup(map,solid: bool,size: Vector2i) -> void:
	resolution=size;extent=map.EXTENT;samples=map.SIZE
	quad=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(2,2);quad.mesh=mesh;quad.custom_aabb=AABB(Vector3(-500,-500,-500),Vector3(1000,1000,1000));quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=preload("res://tools/voxelspace/composite.gdshader");material.set_shader_parameter("color_image",color_texture);material.set_shader_parameter("depth_image",depth_texture);quad.material_override=material;add_child(quad)
	RenderingServer.call_on_render_thread(_initialize_gpu.bind((map.solid_heights if solid else map.heights).to_byte_array(),(map.solid_colors if solid else map.terrain_colors).to_byte_array()))
func _initialize_gpu(height_bytes: PackedByteArray,color_bytes: PackedByteArray) -> void:
	rd=RenderingServer.get_rendering_device()
	if rd==null:failure="RenderingDevice unavailable";return
	var source:=RDShaderSource.new();source.source_compute=FileAccess.get_file_as_string("res://tools/voxelspace/columns.glsl").replace("#[compute]\n","")
	var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():failure=spirv.compile_error_compute;return
	shader=rd.shader_create_from_spirv(spirv);pipeline=rd.compute_pipeline_create(shader)
	height_buffer=rd.storage_buffer_create(height_bytes.size(),height_bytes);color_buffer=rd.storage_buffer_create(color_bytes.size(),color_bytes)
	var format:=RDTextureFormat.new();format.texture_type=RenderingDevice.TEXTURE_TYPE_2D;format.width=resolution.x;format.height=resolution.y;format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	format.format=RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM;color_rid=rd.texture_create(format,RDTextureView.new())
	format.format=RenderingDevice.DATA_FORMAT_R32_SFLOAT;depth_rid=rd.texture_create(format,RDTextureView.new())
	var uniforms: Array[RDUniform]=[]
	for i in 4:
		var uniform:=RDUniform.new();uniform.binding=i;uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER if i<2 else RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.add_id([height_buffer,color_buffer,color_rid,depth_rid][i]);uniforms.append(uniform)
	uniform_set=rd.uniform_set_create(uniforms,shader,0)
	color_texture.texture_rd_rid=color_rid;depth_texture.texture_rd_rid=depth_rid;ready_gpu=true
func draw(camera: Camera3D) -> void:
	if not ready_gpu:return
	var focal:=resolution.y*.5/tan(deg_to_rad(camera.fov*.5))
	var push:=PackedFloat32Array([camera.global_position.x,camera.global_position.y,camera.global_position.z,camera.rotation.y,resolution.x,resolution.y,focal,far_distance,extent,samples,base_step,adaptive_step]).to_byte_array()
	RenderingServer.call_on_render_thread(_dispatch.bind(push))
func _dispatch(push: PackedByteArray) -> void:
	var start:=Time.get_ticks_usec()
	var before:=0
	for i in rd.get_captured_timestamps_count():
		var name:=rd.get_captured_timestamp_name(i)
		if name=="voxelspace-start":before=rd.get_captured_timestamp_gpu_time(i)
		elif name=="voxelspace-end" and before>0:
			timestamp_raw=rd.get_captured_timestamp_gpu_time(i)-before;compute_gpu_ms=timestamp_raw/1000000.0
	rd.capture_timestamp("voxelspace-start")
	var list:=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(list,pipeline);rd.compute_list_bind_uniform_set(list,uniform_set,0);rd.compute_list_set_push_constant(list,push,push.size());rd.compute_list_dispatch(list,ceili(resolution.x/64.0),1,1);rd.compute_list_end()
	rd.capture_timestamp("voxelspace-end");dispatch_cpu_ms=(Time.get_ticks_usec()-start)/1000.0;dispatches+=1
func _exit_tree() -> void:
	ready_gpu=false
	if quad:quad.material_override=null
	color_texture.texture_rd_rid=RID();depth_texture.texture_rd_rid=RID()
	RenderingServer.call_on_render_thread(_release_gpu)
func _release_gpu() -> void:
	if rd==null:return
	for rid in [uniform_set,pipeline,shader,height_buffer,color_buffer,color_rid,depth_rid]:
		if rid.is_valid():rd.free_rid(rid)
