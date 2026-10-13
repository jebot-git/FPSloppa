extends CompositorEffect
## One post-measurement compute readback of the actual native eye buffers.
var requested:=false
var textures: Array[RID]=[]
var pipeline:=RID()
var shader:=RID()
var sampler:=RID()
var sets: Array[RID]=[]
func _render_callback(_type: int,data: RenderData) -> void:
	if not requested:return
	requested=false
	var rd:=RenderingServer.get_rendering_device()
	var buffers: RenderSceneBuffersRD=data.get_render_scene_buffers()
	var size:=buffers.get_internal_size()
	var source:=RDShaderSource.new();source.source_compute="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D eye_color;
layout(rgba8,set=0,binding=1) uniform writeonly image2D screenshot;
void main(){ivec2 p=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(p,imageSize(screenshot))))return;
vec3 c=texelFetch(eye_color,p,0).rgb;
imageStore(screenshot,p,vec4(pow(clamp(c,0.0,1.0),vec3(1.0/2.2)),1.0));}
"""
	var spirv:=rd.shader_compile_spirv_from_source(source)
	shader=rd.shader_create_from_spirv(spirv);pipeline=rd.compute_pipeline_create(shader)
	sampler=rd.sampler_create(RDSamplerState.new())
	for eye in buffers.get_view_count():
		var format:=RDTextureFormat.new();format.width=size.x;format.height=size.y;format.format=RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		format.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		var target:=rd.texture_create(format,RDTextureView.new());textures.append(target)
		var input:=RDUniform.new();input.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;input.binding=0;input.add_id(sampler);input.add_id(buffers.get_color_layer(eye))
		var output:=RDUniform.new();output.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;output.binding=1;output.add_id(target)
		var uniforms:=rd.uniform_set_create([input,output],shader,0);sets.append(uniforms)
		var list:=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(list,pipeline);rd.compute_list_bind_uniform_set(list,uniforms,0)
		rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1);rd.compute_list_end()
func release() -> void:
	var rd:=RenderingServer.get_rendering_device()
	for id in sets:rd.free_rid(id)
	for id in textures:rd.free_rid(id)
	if pipeline.is_valid():rd.free_rid(pipeline)
	if shader.is_valid():rd.free_rid(shader)
	if sampler.is_valid():rd.free_rid(sampler)
	sets.clear();textures.clear()
