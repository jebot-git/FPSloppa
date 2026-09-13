extends SceneTree
## Isolated rendering experiment; never changes game settings or saved materials.
const OUT="res://test-results/effect-lighting/"
var room:Node3D
var lamps:Array[OmniLight3D]=[]
var fill:Array[OmniLight3D]=[]
var records:Array=[]
func _initialize():run.call_deferred()
func texture(colour:Color)->ImageTexture:
	var im:=Image.create(2,2,false,Image.FORMAT_RGB8);im.fill(colour)
	return ImageTexture.create_from_image(im)
func box(pos:Vector3,size:Vector3,material:Material)->void:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=material;node.position=pos;room.add_child(node)
func quantile(values:Array,fraction:float)->float:
	var ordered:=values.duplicate();ordered.sort();return ordered[int((ordered.size()-1)*fraction)]
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Real rendering is required");quit(1);return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	room=Node3D.new();root.add_child(room)
	var env:=WorldEnvironment.new();var settings:=Environment.new();env.environment=settings;room.add_child(env)
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.02,.02,.025)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color(.48,.57,.7);settings.ambient_light_energy=.6;settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var camera:=Camera3D.new();room.add_child(camera);camera.position=Vector3(0,3.4,9);camera.look_at(Vector3(0,1,-1));camera.fov=60;camera.make_current()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-20,0);sun.light_energy=.25;sun.shadow_enabled=false;room.add_child(sun)
	var baked:=ShaderMaterial.new();baked.shader=load("res://deathmatch/maps/baked_light.gdshader")
	var base:=texture(Color(.45,.45,.45));var atlas:=texture(Color(.03,.03,.03))
	for key in ["base_texture","base_linear","base_nearest"]:baked.set_shader_parameter(key,base)
	baked.set_shader_parameter("bake_texture",atlas);baked.set_shader_parameter("contrast_lighting",true)
	box(Vector3(0,-.15,-1),Vector3(13,.3,13),baked)
	box(Vector3(0,2.5,-5),Vector3(13,5,.25),baked)
	box(Vector3(-6.5,2.5,-1),Vector3(.25,5,8),baked)
	box(Vector3(6.5,2.5,-1),Vector3(.25,5,8),baked)
	var library=load("res://deathmatch/avatars/library.gd").new();room.add_child(library)
	var models:Array=[]
	for i in 8:
		var sample:String=["sample_d","sample_f","sample_g"][i%3]
		var path:String=library.Paths.folder("vrm")+sample+".vrm";var hash:=FileAccess.get_sha256(path)
		var avatar=library.create_avatar(hash)
		if avatar==null:push_error("Avatar load failed: "+sample);quit(1);return
		room.add_child(avatar);avatar.position=Vector3((i%4-1.5)*2.4,0,-float(i/4)*2.8);avatar.rotation.y=PI;avatar.process_mode=Node.PROCESS_MODE_DISABLED
		if avatar.gun:avatar.gun.hide()
		if avatar.offhand_gun:avatar.offhand_gun.hide()
		models.append({"sample":sample,"sha256":hash})
	for i in 4:
		var lamp:=OmniLight3D.new();lamp.position=Vector3((i%2-.5)*7,3,-float(i/2)*3);lamp.omni_range=12;lamp.light_color=Color.WHITE;lamp.light_specular=0;lamp.shadow_enabled=false;room.add_child(lamp);fill.append(lamp)
	for i in 8:
		var lamp:=OmniLight3D.new();lamp.position=Vector3((i%4-1.5)*1.5,1.3,1-float(i/4)*3);lamp.omni_range=7;lamp.light_energy=4;lamp.light_color=Color(1,.35,.08) if i%2==0 else Color(.08,.35,1);lamp.light_specular=0;lamp.shadow_enabled=false;lamp.light_bake_mode=Light3D.BAKE_DISABLED;lamp.light_indirect_energy=0;lamp.hide();room.add_child(lamp);lamps.append(lamp)
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	# Sustained lights measure overlap cost, not a favorable average over dark frames.
	for condition in ["dim","lit"]:
		for lamp in fill:lamp.visible=condition=="lit";lamp.light_energy=1.0
		for block in 3:
			var counts:Array=[0,2,4,8,0] if block%2==0 else [0,8,4,2,0]
			for count:int in counts:
				for i in lamps.size():lamps[i].visible=i<count
				for i in 90:await process_frame
				var gpu:Array=[];var cpu:Array=[];var draws:Array=[];var frames:Array=[];var previous:=Time.get_ticks_usec()
				for i in 180:
					await process_frame
					var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				records.append({"condition":condition,"block":block,"effect_lights":count,"map_lights":4 if condition=="lit" else 0,"gpu_p50_ms":quantile(gpu,.5),"gpu_p95_ms":quantile(gpu,.95),"render_cpu_p50_ms":quantile(cpu,.5),"frame_p50_ms":quantile(frames,.5),"draws":quantile(draws,.5),"gpu_samples":gpu})
				if block==0:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUT+condition+"-"+str(count)+".png")
				print("EFFECT_LIGHTING ",condition," ",block," ",count," GPU ",records[-1].gpu_p50_ms)
	var inputs:Dictionary={}
	for file in ["project.godot","deathmatch/maps/baked_light.gdshader","deathmatch/avatars/lighting.gd","addons/Godot-MToon-Shader/mtoon_common.gdshaderinc","tools/effect_lighting/render.gd"]:inputs[file]=FileAccess.get_sha256("res://"+file)
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info(),"size":[1280,800],"msaa":4,"models":models,"inputs":inputs,"records":records,"limits":"Controlled room with current baked-map shader and eight real VRMs. Static models; no gameplay, particles, map occlusion or stereo. Eight effect lights with four map lights deliberately exceeds Mobile's per-mesh omni limit."},"  "))
	room.queue_free();for i in 3:await process_frame
	quit()
