extends SceneTree
## Isolated receiver experiment: private MToon/PBR variants, no production edits.
const OUT="res://test-results/avatar-trajectory/"
const TreeData=preload("res://tools/lighting_experiment/occlusion_tree.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
var stage: Node3D
var camera: Camera3D
var receivers: Array=[]
var assignments: Array=[]
var records: Array=[]
var failures: Array=[]
var checks: Array=[]
var tree_data=TreeData.new()
var starts:=PackedVector4Array()
var ends:=PackedVector4Array()
var colors:=PackedVector4Array()
var viewport: RID
var shaders: Dictionary={}

func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"label":label})
	if not ok:failures.append(label);push_error(label)
func stats(values: Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func shot(name: String) -> Image:
	for i in 6:await process_frame
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image();image.save_png(OUT+name+".png");return image
func compare(a: Image,b: Image) -> Dictionary:
	var changed:=0;var maximum:=0.0;var delta:=Vector3.ZERO;var pixels:=0;var clipped:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			if maxf(ca.r,maxf(ca.g,ca.b))<.015:continue
			var d:=Vector3(cb.r-ca.r,cb.g-ca.g,cb.b-ca.b)
			var error:=d.abs().max_axis_index();maximum=maxf(maximum,absf(d[error]))
			if d.length()>.025:changed+=1
			delta+=d;pixels+=1
			if minf(cb.r,minf(cb.g,cb.b))>.97:clipped+=1
	return {"changed":changed,"pixels":pixels,"mean_delta":[delta.x/maxi(pixels,1),delta.y/maxi(pixels,1),delta.z/maxi(pixels,1)],"max_error":maximum,"white_fraction":float(clipped)/maxi(pixels,1)}
func variant(source: Material) -> ShaderMaterial:
	var mtoon:=source is ShaderMaterial
	var code: String=source.shader.code if mtoon else "shader_type spatial;\nrender_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;\nuniform vec4 avatar_color : source_color = vec4(1.0);\nuniform sampler2D avatar_texture : source_color, hint_default_white;\nuniform vec4 avatar_emission : source_color;\nuniform sampler2D avatar_emission_texture : source_color, hint_default_black;\nuniform float avatar_energy = 0.0;\nuniform float avatar_metallic = 0.0;\nuniform float avatar_roughness = .5;\nvoid fragment() { ALBEDO = avatar_color.rgb * texture(avatar_texture, UV).rgb; METALLIC = avatar_metallic; ROUGHNESS = avatar_roughness; EMISSION = (avatar_emission.rgb + texture(avatar_emission_texture,UV).rgb) * avatar_energy; }"
	if mtoon:code=code.replace('#include "./mtoon_common.gdshaderinc"',FileAccess.get_file_as_string("res://addons/Godot-MToon-Shader/mtoon_common.gdshaderinc"))
	var key:=code
	if not shaders.has(key):
		var extra:=FileAccess.get_file_as_string("res://tools/lighting_experiment/trajectory.gdshaderinc")
		var first:=extra.find("void vertex() {");var last:=extra.find("vec3 trajectory_illumination()")
		extra=extra.substr(0,first)+extra.substr(last)
		extra=extra.replace("illumination +=", "if (falloff <= 0.0 || facing <= 0.0) continue;\n        if (!occlusion_clear_emitter(trajectory_world + normalize(trajectory_normal) * .002, a + t * segment, i)) continue;\n        illumination +=")
		var declarations:=FileAccess.get_file_as_string("res://tools/lighting_experiment/trajectory_occlusion.gdshaderinc")+"\n"+extra
		# Capture skinned model-space inputs before MToon moves VERTEX to view space.
		var vertex_code:="trajectory_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;\ntrajectory_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);\n"
		var vertex:=RegEx.new();vertex.compile("void vertex\\(\\)\\s*\\{")
		var found:=vertex.search(code)
		if found:code=code.substr(0,found.get_start())+declarations+"\nvoid vertex() {\n"+vertex_code+code.substr(found.get_end())
		else:code=code.replace("void fragment()",declarations+"\nvoid vertex() {"+vertex_code+"}\nvoid fragment()")
		var fragment:=RegEx.new();fragment.compile("void fragment\\(\\)\\s*\\{")
		var opening:=fragment.search(code);var depth:=1;var at:=opening.get_end()
		while depth>0:
			if code[at]=="{":depth+=1
			elif code[at]=="}":depth-=1
			at+=1
		var addition:="\nEMISSION += ALBEDO * min(trajectory_illumination(), vec3(.55));\n"
		if mtoon:addition="\nif (isOutline < .5) { EMISSION += ALBEDO * min(trajectory_illumination(), vec3(.55)); }\n"
		code=code.substr(0,at-1)+addition+code.substr(at-1)
		var shader:=Shader.new();shader.code=code;shaders[key]=shader
	var result: ShaderMaterial=source.duplicate() if mtoon else ShaderMaterial.new()
	result.shader=shaders[key]
	if not mtoon:
		result.next_pass=source.next_pass;result.render_priority=source.render_priority
		result.set_shader_parameter("avatar_color",source.albedo_color)
		result.set_shader_parameter("avatar_texture",source.albedo_texture)
		result.set_shader_parameter("avatar_metallic",source.metallic)
		result.set_shader_parameter("avatar_roughness",source.roughness)
		result.set_shader_parameter("avatar_emission",source.emission)
		result.set_shader_parameter("avatar_emission_texture",source.emission_texture)
		result.set_shader_parameter("avatar_energy",source.emission_energy_multiplier if source.emission_enabled else 0.0)
	return result
func prepare(avatar: Node3D) -> void:
	receivers.clear();assignments.clear();var copies: Dictionary={}
	for mesh in avatar.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh or not mesh.is_visible_in_tree():continue
		for i in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(i)
			if not material:continue
			if material is ShaderMaterial and not material.shader.resource_path.contains("mtoon"):continue
			if not copies.has(material):copies[material]=variant(material);receivers.append(copies[material])
			assignments.append({"mesh":mesh,"surface":i,"original":material,"copy":copies[material],"override":mesh.material_override,"surface_override":mesh.get_surface_override_material(i),"shader":material.shader if material is ShaderMaterial else null})
	for assignment in assignments:
		assignment.mesh.material_override=null;assignment.mesh.set_surface_override_material(assignment.surface,assignment.copy)
func sources(count: int,color: Color,blocked: bool=false,shift: Vector3=Vector3.ZERO) -> void:
	starts.resize(8);ends.resize(8);colors.resize(8)
	for i in 8:
		var a:=Vector3(-2,.7+i*.06,.7)+shift;var b:=a+Vector3.UP
		starts[i]=Vector4(a.x,a.y,a.z,4);ends[i]=Vector4(b.x,b.y,b.z,1.3)
		colors[i]=Vector4(color.r,color.g,color.b,1)
	tree_data=TreeData.new()
	tree_data.head=tree_data.box(AABB(Vector3(-1.55,-2,-5)+shift,Vector3(.1,7,10))) if blocked else -1
	tree_data.pack()
	for material in receivers:
		material.set_shader_parameter("trajectory_count",count)
		material.set_shader_parameter("trajectory_start",starts);material.set_shader_parameter("trajectory_end",ends);material.set_shader_parameter("trajectory_color",colors)
		tree_data.apply(material,true)
func use_originals(enabled: bool) -> void:
	for assignment in assignments:
		assignment.mesh.set_surface_override_material(assignment.surface,assignment.original if enabled else assignment.copy)
func pose(avatar: Node3D) -> bool:
	if "skeleton" in avatar:
		var skeleton: Skeleton3D=avatar.skeleton
		for bone in ["LeftUpperArm","RightUpperArm","LeftLowerArm"]:
			var index:=skeleton.find_bone(bone)
			if index>=0:skeleton.set_bone_pose_rotation(index,Quaternion(Vector3.FORWARD,.65 if bone=="LeftUpperArm" else -.45))
		skeleton.force_update_all_bone_transforms();return true
	avatar.animate(.3,Vector3(3,0,2),"crouch",1.2,true,{},false);return false
func benchmark(name: String) -> void:
	for index in 6:
		var count: int=[0,1,4,4,1,0][index];sources(count,Color(1,.2,.03),false)
		for i in 90:await process_frame
		var gpu: Array=[];var draws: Array=[]
		for i in 300:
			await process_frame;gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		records.append({"model":name,"emitters":count,"gpu_ms":stats(gpu),"draws":stats(draws),"materials":receivers.size()})
func map_example(library: Node) -> void:
	var level=preload("res://deathmatch/maps/loader.gd").read("res://maps/qsrc_dm6.bsp");stage.add_child(level)
	for node in level.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	await physics_frame;await physics_frame
	var dir:=Vector3(.194305,-.089638,.976837).normalized()
	camera.position=Vector3(47.25,2.03,-7.25);camera.fov=65
	var ahead:=camera.position+dir*2
	var floor_hit:=stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead,ahead-Vector3.UP*10,1))
	check(not floor_hit.is_empty(),"DM6 example has a valid floor")
	if floor_hit.is_empty():level.free();return
	var avatar=library.create_avatar(FileAccess.get_sha256(library.Paths.folder("vrm")+"sample_d.vrm"));stage.add_child(avatar)
	avatar.position=floor_hit.position+Vector3.UP*.02
	var toward: Vector3=camera.position-avatar.position;toward.y=0;avatar.basis=Basis.looking_at(toward.normalized())
	for node in avatar.find_children("*","Node",true,false):
		node.set_process(false);node.set_physics_process(false)
		if node is SkeletonModifier3D:node.active=false
		if node is AnimationMixer:node.active=false
	avatar.set_process(false);avatar.set_physics_process(false)
	if avatar.gun:avatar.gun.hide()
	if avatar.offhand_gun:avatar.offhand_gun.hide()
	pose(avatar);camera.look_at(avatar.position+Vector3.UP*.87)
	await process_frame;prepare(avatar);sources(0,Color.WHITE)
	tree_data=TreeData.new();check(tree_data.open("res://maps/qsrc_dm6.bsp"),"DM6 avatar uses actual BSP occlusion")
	var a:=camera.position+dir*.4;var b: Vector3=avatar.position+Vector3.UP*1.25+toward.normalized()*.5
	starts[0]=Vector4(a.x,a.y,a.z,3);ends[0]=Vector4(b.x,b.y,b.z,1.3);colors[0]=Vector4(1,.2,.03,1)
	var trail:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.015,.015,a.distance_to(b));trail.mesh=box
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,.5,.08);trail.material_override=material;stage.add_child(trail);trail.position=(a+b)*.5;trail.look_at(b)
	for receiver in receivers:
		tree_data.apply(receiver,true);receiver.set_shader_parameter("trajectory_start",starts);receiver.set_shader_parameter("trajectory_end",ends);receiver.set_shader_parameter("trajectory_color",colors)
	var baseline:=await shot("dm6-baseline")
	for receiver in receivers:receiver.set_shader_parameter("trajectory_count",1)
	var lit:=await shot("dm6-lit");var difference:=compare(baseline,lit)
	check(difference.changed>150,"Avatar is illuminated in actual dark BSP scene")
	records.append({"map":"qsrc_dm6","model":"sample_d","difference":difference})
	assignments.clear();receivers.clear();avatar.free();trail.free();level.free()
func test_avatar(name: String,avatar: Node3D) -> void:
	stage.add_child(avatar);avatar.rotation.y=PI
	for node in avatar.find_children("*","Node",true,false):
		node.set_process(false);node.set_physics_process(false)
		if node is SkeletonModifier3D:node.active=false
		if node is AnimationMixer:node.active=false
	avatar.set_process(false);avatar.set_physics_process(false)
	for node in avatar.find_children("*Weapon*","Node3D",true,false):node.hide()
	if "gun" in avatar and avatar.gun:avatar.gun.hide()
	if "offhand_gun" in avatar and avatar.offhand_gun:avatar.offhand_gun.hide()
	var original:=await shot(name+"-original")
	prepare(avatar);check(not receivers.is_empty(),name+": receiver materials prepared")
	sources(0,Color.WHITE)
	var baseline:=await shot(name+"-baseline")
	check(compare(original,baseline).max_error<.008,name+": original appearance preserved with effect off")
	sources(1,Color(1,.2,.03));var warm:=await shot(name+"-warm")
	var warm_delta:=compare(baseline,warm)
	check(warm_delta.changed>150,name+": trail illuminates avatar")
	check(warm_delta.white_fraction<.03,name+": bounded brightness")
	sources(1,Color(.03,.2,1));var cool:=await shot(name+"-cool")
	var cool_delta:=compare(baseline,cool)
	check(warm_delta.mean_delta[0]-warm_delta.mean_delta[2]>cool_delta.mean_delta[0]-cool_delta.mean_delta[2]+.01,name+": warm/cool response")
	sources(1,Color(1,.2,.03),true)
	var blocked:=await shot(name+"-blocked")
	check(compare(baseline,blocked).max_error<.008,name+": BSP wall blocks light on avatar")
	var skinned:=pose(avatar)
	sources(0,Color.WHITE);var posed_baseline:=await shot(name+"-posed-baseline")
	sources(1,Color(1,.2,.03));var posed:=await shot(name+"-posed-lit")
	check(compare(posed_baseline,posed).changed>100,name+": posed mesh receives illumination")
	check(compare(baseline,posed_baseline).changed>100,name+": pose actually changes rendered mesh")
	# Translate avatar, camera, source and occluder together to detect wrong spaces.
	var shift:=Vector3(20,4,-15);avatar.position+=shift;camera.position+=shift;sources(1,Color(1,.2,.03),false,shift)
	var translated:=await shot(name+"-translated")
	var parity:=compare(posed,translated)
	check(parity.mean_delta.all(func(v):return absf(v)<.003),name+": translation preserves illumination")
	avatar.position-=shift;camera.position-=shift;sources(1,Color(1,.2,.03))
	for assignment in assignments:
		check(assignment.original!=assignment.copy,name+": private receiver material")
		if assignment.original is ShaderMaterial:check(assignment.original.shader==assignment.shader,name+": shared source shader unchanged")
		check(assignment.original.next_pass==assignment.copy.next_pass,name+": outline/extra pass preserved")
	records.append({"model":name,"warm":warm_delta,"cool":cool_delta,"skinned":skinned,"translation":parity,"materials":receivers.size()})
	await benchmark(name)
	assignments.clear();receivers.clear();avatar.free();print("AVATAR_TRAJECTORY_MODEL ",name)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(800,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	viewport=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	stage=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.02;env.environment.reflected_light_source=2;stage.add_child(env)
	camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,1,3.2);camera.look_at(Vector3(0,.87,0));camera.fov=43;camera.current=true
	var library:=Library.new();stage.add_child(library)
	for name in ["sample_d","sample_f","sample_g"]:
		var avatar=library.create_avatar(FileAccess.get_sha256(library.Paths.folder("vrm")+name+".vrm"))
		check(avatar!=null,name+": real VRM loaded")
		if avatar:await test_avatar(name,avatar)
	var placeholder=preload("res://deathmatch/art.gd").marine(Color(.65,.7,.8))
	await test_avatar("placeholder",placeholder)
	await map_example(library)
	check(stage.find_children("*","Light3D",true,false).is_empty(),"No realtime light nodes")
	var result:={"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[800,800],"frames_per_block":300,"checks":checks,"records":records,"failures":failures}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	stage.free();print("AVATAR_TRAJECTORY_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
