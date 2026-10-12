extends SceneTree
## Separate correctness run: local RD readback is NOT part of render benchmarks.
const Landscape = preload("res://tools/streamed_heightfield/landscape.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null: push_error("GPU terrain parity check requires Vulkan"); quit(2); return
	var points := PackedFloat32Array()
	var expected: Array[Vector4] = []
	for z in range(-1024, 1025, 16):
		for x in range(-1024, 1025, 16):
			points.append_array(PackedFloat32Array([x, z, 0, 0]))
			expected.append(Landscape.surface(x, z))
	for i in 2048:
		var x := sin(i * 1.618) * 1023.8
		var z := cos(i * .731) * 1023.8
		points.append_array(PackedFloat32Array([x, z, 0, 0]))
		expected.append(Landscape.surface(x, z))
	# Compile the exact surface function used by the actual raster shader.
	var shader_text := FileAccess.get_file_as_string("res://tools/streamed_heightfield/procedural.gdshader")
	var function := "vec4 surface(vec2 p) {" + shader_text.get_slice("vec4 surface(vec2 p) {", 1).get_slice("vec3 srgb_to_linear", 0)
	var source := RDShaderSource.new()
	source.source_compute = "#version 450\nlayout(local_size_x=64) in;\nlayout(set=0,binding=0,std430) readonly buffer Input { vec4 points[]; } data_in;\nlayout(set=0,binding=1,std430) writeonly buffer Output { vec4 values[]; } data_out;\n" + function + "\nvoid main() { uint i=gl_GlobalInvocationID.x; if(i<" + str(expected.size()) + "u) data_out.values[i]=surface(data_in.points[i].xy); }\n"
	var spirv := rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): push_error(spirv.compile_error_compute); rd.free(); quit(3); return
	var shader := rd.shader_create_from_spirv(spirv)
	var pipeline := rd.compute_pipeline_create(shader)
	var input := rd.storage_buffer_create(points.size() * 4, points.to_byte_array())
	var output := rd.storage_buffer_create(points.size() * 4)
	var uniforms: Array[RDUniform] = []
	for i in 2:
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		uniform.binding = i
		uniform.add_id(input if i == 0 else output)
		uniforms.append(uniform)
	var uniform_set := rd.uniform_set_create(uniforms, shader, 0)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipeline)
	rd.compute_list_bind_uniform_set(list, uniform_set, 0)
	rd.compute_list_dispatch(list, ceili(expected.size() / 64.0), 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var result := rd.buffer_get_data(output).to_float32_array()
	var maximum_height_error := 0.0
	var maximum_color_error := 0.0
	for i in expected.size():
		maximum_height_error = maxf(maximum_height_error, absf(result[i * 4] - expected[i].x))
		for channel in range(1, 4): maximum_color_error = maxf(maximum_color_error, absf(result[i * 4 + channel] - expected[i][channel]))
	var passed := maximum_height_error < .02 and maximum_color_error < .005
	var report := {"gpu": RenderingServer.get_video_adapter_name(), "samples": expected.size(), "maximum_height_error_m": maximum_height_error, "maximum_color_error": maximum_color_error, "height_tolerance_m": .02, "color_tolerance": .005, "passed": passed, "scope": "Exact GPU shader surface function versus CPU deterministic source, world grid and fractional probes. Readback/sync used only for this separate correctness check."}
	DirAccess.make_dir_recursive_absolute("res://test-results/streamed-heightfield")
	FileAccess.open("res://test-results/streamed-heightfield/gpu-parity.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("GPU_TERRAIN_PARITY ", JSON.stringify(report))
	for rid in [uniform_set, pipeline, shader, input, output]: rd.free_rid(rid)
	rd.free()
	quit(0 if passed else 1)
