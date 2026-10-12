extends "res://tools/voxelspace/run.gd"
const VoxelTerrain=preload("res://tools/voxelspace/voxel_terrain.gd")
const FactoryLOD=preload("res://tools/voxelspace/factory_lod.gd")
var factory_switcher
func run() -> void:
	output="res://test-results/factory-optimization/rendering"
	if DisplayServer.get_name()=="headless":push_error("Real Vulkan rendering required");quit(2);return
	interactive=OS.get_cmdline_user_args().has("--interactive")
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.add_child(world);world.add_child(camera);camera.current=true;camera.fov=70;camera.near=.1;camera.far=300;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.38,.54,.65);world.add_child(environment)
	map.generate(output);camera.position=Vector3(0,10,68)
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	if interactive:
		hud=Label.new();hud.position=Vector2(20,20);hud.add_theme_font_size_override("font_size",18);root.add_child(hud);switch_mode("factory_lod");return
	for variant in ["baseline","native_csg","openscad","blender_planar","greedy","culled","factory_lod","voxel_fine","voxel_lod","voxel_merged_fine","voxel_merged_coarse"]:
		await select(variant);await sample(variant+"_front",viewport)
	for variant in ["voxel_merged_fine","voxel_lod","culled","native_csg","baseline"]:
		await select(variant);await sample(variant+"_front_repeat",viewport)
	camera.position=Vector3(66,14,68);camera.rotation.y=deg_to_rad(44)
	for variant in ["baseline","culled","voxel_lod"]:
		await select(variant);await sample(variant+"_diagonal",viewport)
	camera.position=Vector3(0,8,5);camera.rotation=Vector3.ZERO
	for variant in ["baseline","culled","factory_lod"]:
		await select(variant);await sample(variant+"_interior",viewport)
	for variant in ["baseline","factory_lod","voxel_lod"]:
		await select(variant);await sample(variant+"_flyby",viewport)
	camera.position=Vector3(0,20,205);camera.rotation=Vector3.ZERO
	for variant in ["baseline","factory_lod","voxel_lod","voxel_merged_coarse"]:
		await select(variant);await sample(variant+"_far",viewport)
	camera.position=Vector3(0,5,60)
	library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.shadow_enabled=false;world.add_child(light);spawn_avatars("sample_d")
	for variant in ["baseline","factory_lod","voxel_merged_fine","voxel_lod","factory_lod","baseline"]:
		await select(variant);await sample(variant+"_32_d_"+str(rows.size()),viewport)
	clear_avatars()
	var report:={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1440,900],"rows":rows,"setup_times":setup_times,"scope":"Same generated terrain source and factory envelope. Factory union/cleanup tests use heightfield patch terrain. Voxel cases change terrain geometry and color sampling. 32 animated copies of bundled D, springs off and production distance LOD; mono, no networking/combat/collision/XR."}
	FileAccess.open(output+"/optimization.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	clear_scene();world.free();await process_frame;await process_frame;quit()
func clear_scene() -> void:
	factory_switcher=null;super.clear_scene()
func switch_mode(variant: String) -> void:
	clear_scene();factory_switcher=null;mode=variant;scene=Node3D.new();world.add_child(scene)
	if variant.begins_with("voxel"):
		patch=VoxelTerrain.new();scene.add_child(patch)
		var merged:=0 if variant=="voxel_merged_fine" else 2 if variant=="voxel_merged_coarse" else -1
		patch.setup(map,variant=="voxel_fine",merged);patch.update(camera)
	else:patch=PatchTerrain.new();scene.add_child(patch);patch.setup(map);patch.update(camera)
	if variant=="factory_lod" or variant.begins_with("voxel"):
		factory_switcher=FactoryLOD.new();scene.add_child(factory_switcher);factory_switcher.setup();factory_switcher.update(camera);factory=factory_switcher
	else:
		factory=MeshInstance3D.new();factory.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if variant=="baseline":factory.mesh=map.factory_mesh
		elif variant=="openscad":factory.mesh=load("res://tools/voxelspace/assets/factory.csg")
		else:factory.mesh=load("res://tools/voxelspace/assets/factory_"+variant+".res")
		scene.add_child(factory)
func sample(label: String,viewport: RID) -> void:
	await measure(label,viewport)
	rows[-1].factory_lod=factory_switcher.lod if factory_switcher!=null else 0
	rows[-1].factory_triangles=factory.mesh.surface_get_array_index_len(0)/3 if factory.mesh.surface_get_array_index_len(0)>0 else factory.mesh.surface_get_array_len(0)/3
func flyby(frame: int) -> void:
	var phase:=float(frame)/360.0*TAU
	camera.position=Vector3(sin(phase)*120,14,125+cos(phase)*90)
	camera.rotation=Vector3(0,atan2(camera.position.x,camera.position.z),0)
func _process(delta: float) -> bool:
	super._process(delta)
	if factory_switcher!=null:factory_switcher.update(camera)
	if interactive and hud:hud.text="FACTORY GEOMETRY / "+mode+"\nWASD fly · Q/E height · RMB yaw\n1 baseline · 2 Godot CSG · 3 OpenSCAD · 4 exact greedy · 5 hidden-face culled · 6 factory LOD · 7 voxel chunks · 8 merged voxels\n%.1f FPS"%Engine.get_frames_per_second()
	return false
func _input(event: InputEvent) -> void:
	if not interactive:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:mouse_held=event.pressed
	if event is InputEventMouseMotion and mouse_held:camera.rotation.y-=event.relative.x*.004
	if event is InputEventKey and event.pressed:
		var modes:={KEY_1:"baseline",KEY_2:"native_csg",KEY_3:"openscad",KEY_4:"greedy",KEY_5:"culled",KEY_6:"factory_lod",KEY_7:"voxel_lod",KEY_8:"voxel_merged_fine"}
		if modes.has(event.keycode):switch_mode(modes[event.keycode])
		elif event.keycode==KEY_ESCAPE:quit()
