extends CompositorEffect
## Single in-place HDR compute pass for each eye, including native XR multiview.
var mutex:=Mutex.new()
var parameters:=PackedFloat32Array([1,.045,.18,0,0,0,0,0,1,1,0,0,.577,.4,.14,0])
var shader:=RID()
var pipeline:=RID()
func _init() -> void:
	effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color=true;enabled=false
func configure(gain:float,scout:bool,blind:float,time:float) -> void:
	mutex.lock();parameters=PackedFloat32Array([gain*(.533333 if scout else .233333),.012 if scout else .045,.09 if scout else .18,blind,time,0,0,0,1,1,0,0,0.0 if scout else tan(deg_to_rad(40)),.65 if scout else .4,.05 if scout else .14,0]);mutex.unlock()
func _render_callback(_type:int,data:RenderData) -> void:
	var rd:=RenderingServer.get_rendering_device()
	var buffers:RenderSceneBuffersRD=data.get_render_scene_buffers()
	var size:=buffers.get_internal_size()
	if size.x<=0 or size.y<=0:return
	if not shader.is_valid():
		var source:=RDShaderSource.new();source.source_compute="""#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform image2D scene;
layout(push_constant,std430) uniform Params {float gain;float noise;float vignette;float blind;float time;float eye;float width;float height;float inv_x;float inv_y;float offset_x;float offset_y;float aperture;float brightness;float lines;float pad;} p;
float hash(vec2 v){return fract(sin(dot(v,vec2(12.9898,78.233)))*43758.5453);}
void main(){ivec2 xy=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(xy,imageSize(scene))))return;
vec4 src=imageLoad(scene,xy);float luma=dot(max(src.rgb,vec3(0)),vec3(.2126,.7152,.0722));
float detail=1.0-exp(-luma*p.gain);vec2 uv=(vec2(xy)+.5)/vec2(p.width,p.height);
// Reconstruct head-relative angular rays from each actual off-axis eye projection.
vec2 ray=(vec2(uv.x*2.0-1.0,1.0-uv.y*2.0)+vec2(p.offset_x,p.offset_y))*vec2(p.inv_x,p.inv_y);
float elevation=atan(ray.y,sqrt(1.0+ray.x*ray.x));
float scan=1.0-p.lines*(.5+.5*cos(elevation*1800.0+p.time*2.0));
// Both eyes share angular phase/noise, rather than unrelated pixel-row patterns.
float grain=(hash(floor(ray*900.0)+vec2(floor(p.time*30.0)*17.0,0))-.5)*p.noise;
float aperture=p.aperture<=0.0?1.0:1.0-smoothstep(p.aperture*.92,p.aperture,length(ray));
float shade=1.0-p.vignette*smoothstep(p.aperture<=0.0?.48:.2,.7,length(uv-.5));
vec3 color=vec3(.09,1.0,.17)*clamp(detail+grain,0.0,1.0)*shade*scan*p.brightness;
imageStore(scene,xy,vec4(mix(color,vec3(1.0),p.blind)*aperture,src.a));}
"""
		var spirv:=rd.shader_compile_spirv_from_source(source)
		if not spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE).is_empty():push_error(spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE));return
		shader=rd.shader_create_from_spirv(spirv);pipeline=rd.compute_pipeline_create(shader)
	mutex.lock();var values:=parameters.duplicate();mutex.unlock()
	for eye_index in buffers.get_view_count():
		values[5]=eye_index;values[6]=size.x;values[7]=size.y
		var projection:Projection=data.get_render_scene_data().get_view_projection(eye_index)
		values[8]=1.0/projection.x.x;values[9]=1.0/projection.y.y;values[10]=projection.z.x;values[11]=projection.z.y
		var uniform:=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;uniform.binding=0;uniform.add_id(buffers.get_color_layer(eye_index))
		var uniforms:=UniformSetCacheRD.get_cache(shader,0,[uniform])
		var list:=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(list,pipeline);rd.compute_list_bind_uniform_set(list,uniforms,0)
		var bytes:=values.to_byte_array();rd.compute_list_set_push_constant(list,bytes,bytes.size());rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1);rd.compute_list_end()
func release() -> void:
	var rd:=RenderingServer.get_rendering_device()
	if pipeline.is_valid():rd.free_rid(pipeline);pipeline=RID()
	if shader.is_valid():rd.free_rid(shader);shader=RID()
