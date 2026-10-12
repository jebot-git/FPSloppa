extends "res://tools/voxelspace/column_renderer.gd"
## Shared resident textures and page table; no full-world height/color buffer.
var terrain_source
var sampler := RID()

func setup_stream(source, size: Vector2i, aggressive: bool = true) -> void:
	terrain_source = source
	resolution = size
	extent = 2048.0
	samples = 65
	base_step = 1.0 if aggressive else .25
	adaptive_step = .02 if aggressive else .007
	far_distance = 640.0
	quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	quad.mesh = mesh
	quad.custom_aabb = AABB(Vector3(-4096, -4096, -4096), Vector3(8192, 8192, 8192))
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://tools/voxelspace/composite.gdshader")
	material.set_shader_parameter("color_image", color_texture)
	material.set_shader_parameter("depth_image", depth_texture)
	quad.material_override = material
	add_child(quad)
	RenderingServer.call_on_render_thread(_initialize_stream_gpu)

func _initialize_stream_gpu() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null: failure = "RenderingDevice unavailable"; return
	var source := RDShaderSource.new()
	source.source_compute = FileAccess.get_file_as_string("res://tools/streamed_heightfield/columns.glsl").replace("#[compute]\n", "")
	var spirv := rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): failure = spirv.compile_error_compute; return
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
	var state := RDSamplerState.new()
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = rd.sampler_create(state)
	var format := RDTextureFormat.new()
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	format.width = resolution.x
	format.height = resolution.y
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	color_rid = rd.texture_create(format, RDTextureView.new())
	format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	depth_rid = rd.texture_create(format, RDTextureView.new())
	var uniforms: Array[RDUniform] = []
	for i in 7:
		var uniform := RDUniform.new()
		uniform.binding = i
		if i == 2 or i == 3:
			uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			uniform.add_id(color_rid if i == 2 else depth_rid)
		else:
			var texture = terrain_source.get(["height_tiles", "color_tiles", "", "", "pages", "coarse_heights", "coarse_colors"][i])
			uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
			uniform.add_id(sampler)
			uniform.add_id(RenderingServer.texture_get_rd_texture(texture.get_rid()))
		uniforms.append(uniform)
	uniform_set = rd.uniform_set_create(uniforms, shader, 0)
	if not uniform_set.is_valid(): failure = "Streamed column uniforms failed"; return
	color_texture.texture_rd_rid = color_rid
	depth_texture.texture_rd_rid = depth_rid
	ready_gpu = true

func _release_gpu() -> void:
	super._release_gpu()
	if rd != null and sampler.is_valid(): rd.free_rid(sampler)
