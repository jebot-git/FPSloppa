extends SceneTree
## Isolated visual/performance probe. Does not alter shipped shaders or gameplay.
const Loader=preload("res://deathmatch/maps/loader.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/trajectory-light/"
var stage: Node3D
var camera: Camera3D
var receivers: Array=[]
var originals: Dictionary={}
var variants: Dictionary={}
var streaks: Array=[]
var records: Array=[]
var checks: Array=[]
var failures: Array=[]
var starts:=PackedVector4Array()
var ends:=PackedVector4Array()
var colors:=PackedVector4Array()
var origin:=Vector3.ZERO
var direction:=Vector3.FORWARD
var side:=Vector3.RIGHT
var viewport: RID

func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"label":label})
	if not ok:failures.append(label);push_error(label)
func stats(values: Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func shader_variant(source: Shader) -> Shader:
	if not variants.has(source):
		var code:=source.code
		code=code.replace("void fragment()",FileAccess.get_file_as_string("res://tools/lighting_experiment/trajectory.gdshaderinc")+"\nvoid fragment()")
		code=code.replace("ROUGHNESS = 1.0;","EMISSION += base * trajectory_illumination();\n    ROUGHNESS = 1.0;")
		var shader:=Shader.new();shader.code=code;variants[source]=shader
	return variants[source]
func collect(level: Node) -> void:
	receivers.clear();originals.clear()
	var filter:=Filtering.new();filter.apply(level,2,true,1)
	for material in filter.materials:
		if material is ShaderMaterial and material.shader in [Filtering.BAKED,Filtering.QUAKE]:
			receivers.append(material);originals[material]=material.shader
func activate(count: int,stock: bool=false) -> void:
	for material in receivers:
		material.shader=originals[material] if stock else shader_variant(originals[material])
		if not stock:material.set_shader_parameter("trajectory_count",count)
func update_segments(count: int,phase: float=0.0) -> void:
	starts.resize(8);ends.resize(8);colors.resize(8)
	for i in 8:
		var offset:=side*(float(i%4)-1.5)*.42+Vector3.UP*(i/4)*.20
		var a:=origin+offset+direction*(sin(phase+float(i)*.6)*1.5)
		var b:=a+direction*3.5
		starts[i]=Vector4(a.x,a.y,a.z,2.7)
		ends[i]=Vector4(b.x,b.y,b.z,1.5)
		colors[i]=Vector4(1,.24,.045,1) if i%2==0 else Vector4(.06,.3,1,1)
		streaks[i].visible=i<count
		streaks[i].position=(a+b)*.5;streaks[i].look_at(b)
	for material in receivers:
		if material.shader==originals[material]:continue
		material.set_shader_parameter("trajectory_start",starts)
		material.set_shader_parameter("trajectory_end",ends)
		material.set_shader_parameter("trajectory_color",colors)
func create_streaks() -> void:
	for i in 8:
		var mesh:=BoxMesh.new();mesh.size=Vector3(.025,.025,3.5)
		var node:=MeshInstance3D.new();node.mesh=mesh
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=Color(1,.55,.15) if i%2==0 else Color(.15,.55,1)
		material.emission_enabled=true;material.emission=material.albedo_color;material.emission_energy_multiplier=3
		node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(node);streaks.append(node)
func capture(name: String) -> Image:
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image();image.save_png(OUT+name+".png");return image
func difference(a: Image,b: Image,exclude_bright: bool=true) -> Dictionary:
	var changed:=0;var total:=0;var gain:=0.0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			if exclude_bright and maxf(ca.r,maxf(ca.g,ca.b))>.8:continue
			var d:=maxf(cb.r-ca.r,maxf(cb.g-ca.g,cb.b-ca.b))
			if d>.03:changed+=1
			gain+=maxf(0,d);total+=1
	return {"changed_pixels":changed,"sampled_pixels":total,"mean_positive_channel_gain":gain/maxi(total,1)}
func benchmark(name: String) -> void:
	activate(8);update_segments(8)
	var warm_until:=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<warm_until:await process_frame
	# Reversed second round limits order bias. Always draw the same eight streaks.
	for index in 10:
		var mode: int=[-1,0,1,4,8,8,4,1,0,-1][index]
		activate(maxi(mode,0),mode<0);update_segments(8)
		for i in 90:await process_frame
		var cpu: Array=[];var gpu: Array=[];var draws: Array=[];var uploads: Array=[]
		for frame in 600:
			var start:=Time.get_ticks_usec();update_segments(8,float(frame)/60.0)
			uploads.append((Time.get_ticks_usec()-start)/1000.0)
			await process_frame
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var row:={"map":name,"pass":index,"segments":mode,"cpu_ms":stats(cpu),"gpu_ms":stats(gpu),"update_ms":stats(uploads),"draws":stats(draws),"materials":receivers.size()}
		records.append(row);print("TRAJECTORY_BLOCK ",JSON.stringify(row))
func map_probe(name: String) -> void:
	var level:=Loader.read("res://maps/"+name+".bsp");stage.add_child(level)
	for node in level.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	collect(level)
	await physics_frame;await physics_frame
	var selected: Node3D
	for node in level.find_children("*","Node3D",true,false):
		if "attributes" in node and node.attributes.get("classname","")=="info_player_deathmatch":selected=node;break
	check(selected!=null,name+": spawn exists")
	if not selected:level.free();return
	camera.position=selected.global_position+Vector3.UP*.78
	var space:=stage.get_world_3d().direct_space_state
	var best:=-INF;direction=Vector3.FORWARD
	for i in 32:
		var dir:=Vector3(sin(i*TAU/32),-.09,cos(i*TAU/32)).normalized()
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(camera.position,camera.position+dir*18,1))
		var length:=18.0 if hit.is_empty() else camera.position.distance_to(hit.position)
		if length>best:best=length;direction=dir
	camera.look_at(camera.position+direction*10);side=camera.global_basis.x
	origin=camera.position+direction*minf(best*.25,3.0)-Vector3.UP*.8
	check(not receivers.is_empty(),name+": baked shader receivers")
	check(stage.find_children("*","Light3D",true,false).is_empty(),name+": no realtime lights while map is loaded")
	activate(0);update_segments(0)
	var empty:=await capture(name+"-empty")
	update_segments(1)
	var emission:=await capture(name+"-emission-only")
	activate(1);update_segments(1)
	var lit:=await capture(name+"-trajectory")
	var delta:=difference(emission,lit)
	check(delta.changed_pixels>300,name+": nearby surfaces brighten beyond emissive core")
	records.append({"map":name,"visual_delta":delta,"emission_only_delta":difference(empty,emission),"camera":str(camera.position),"origin":str(origin),"direction":str(direction)})
	activate(0);update_segments(1)
	var restored:=await capture(name+"-restored")
	check(difference(emission,restored,false).changed_pixels==0,name+": light fades completely when disabled")
	# A zero-length capsule is a moving bullet; exercise its degenerate path.
	var point:=Vector3(ends[0].x,ends[0].y,ends[0].z)
	starts[0]=Vector4(point.x,point.y,point.z,2.7)
	streaks[0].position=point;streaks[0].scale.z=.025/3.5
	for material in receivers:material.set_shader_parameter("trajectory_start",starts)
	var bullet_baseline:=await capture(name+"-bullet-emission")
	activate(1)
	var bullet_lit:=await capture(name+"-bullet-lit")
	var bullet_delta:=difference(bullet_baseline,bullet_lit)
	check(bullet_delta.changed_pixels>100,name+": zero-length bullet illuminates surfaces")
	records.append({"map":name,"bullet_delta":bullet_delta})
	streaks[0].scale=Vector3.ONE
	await benchmark(name)
	if name=="qsrc_dm6":
		activate(1)
		for frame in 120:
			update_segments(1,float(frame)*TAU/120)
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUT+"frames/%04d.png"%frame)
			await process_frame
	receivers.clear();originals.clear();level.free()
func fixture_material() -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=Filtering.BAKED
	var pixels:=Image.create(2,2,false,Image.FORMAT_RGB8);pixels.fill(Color(.45,.45,.45))
	var texture:=ImageTexture.create_from_image(pixels)
	for key in ["base_texture","base_linear","base_nearest"]:material.set_shader_parameter(key,texture)
	pixels=Image.create(2,2,false,Image.FORMAT_RGB8);pixels.fill(Color(.002,.002,.002))
	material.set_shader_parameter("bake_texture",ImageTexture.create_from_image(pixels));material.set_shader_parameter("contrast_lighting",true)
	return material
func leak_probe() -> void:
	var fixture:=Node3D.new();stage.add_child(fixture)
	var material:=fixture_material()
	for spec in [[Vector3(0,-.1,0),Vector3(12,.2,12)],[Vector3(0,1,0),Vector3(.2,2,6)]]:
		var mesh:=BoxMesh.new();mesh.size=spec[1]
		var node:=MeshInstance3D.new();node.mesh=mesh;node.position=spec[0];node.material_override=material;fixture.add_child(node)
	receivers=[material];originals={material:material.shader}
	camera.position=Vector3(7,8,9);camera.look_at(Vector3.ZERO)
	origin=Vector3(-.6,.6,-1.5);direction=Vector3.BACK;side=Vector3.ZERO
	activate(0);update_segments(1)
	var baseline:=await capture("wall-baseline")
	activate(1);update_segments(1)
	var lit:=await capture("wall-leak")
	var probe:=Vector3(.7,.01,1.0);var pixel:=Vector2i(camera.unproject_position(probe))
	var a:=baseline.get_pixelv(pixel);var b:=lit.get_pixelv(pixel)
	var gain:=b.r-a.r
	check(gain>.05,"Known limitation reproduced: capsule illumination leaks through divider onto hidden floor")
	records.append({"fixture":"occlusion","pixel":str(pixel),"red_gain_behind_wall":gain})
	receivers.clear();originals.clear();fixture.free()
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Real renderer required");quit(1);return
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	viewport=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	stage=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.007,.008,.012)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=0
	environment.environment.reflected_light_source=2 # Disabled; no reflected sky fill.
	environment.environment.glow_enabled=false;stage.add_child(environment)
	camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=80;camera.far=300
	create_streaks()
	await map_probe("qsrc_dm6")
	await map_probe("tf_vesper")
	await leak_probe()
	check(stage.find_children("*","Light3D",true,false).is_empty(),"No realtime light nodes in test scene")
	var result:={"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"resolution":[1280,720],"msaa":4,"frames_per_block":600,"records":records,"checks":checks,"failures":failures}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	stage.free();print("TRAJECTORY_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
