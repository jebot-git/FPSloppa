extends SceneTree
var g
var camera: Camera3D
var prefix: String
var report: Dictionary={}
func _initialize():run.call_deferred()
func capture(name: String,at: Vector3,target: Vector3) -> void:
	camera.position=at;camera.look_at(target);camera.make_current()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix+"-"+name+".png")
func run() -> void:
	prefix="res://test-results/titanball/gate-"+(OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "probe")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="tb_ashfall";g.start_host("Hangar visibility probe",0,100,10,true,"tb")
	g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
	if g.viewmodel:g.viewmodel.hide()
	var tb=g.match_mode.titanball;var gate=tb.gate_ref.get_ref()
	report={"preparing":tb.preparing(),"gate":str(gate.get_path()),"position":gate.position,"visible":gate.visible,"attributes":gate.attributes,"meshes":[],"occlusion_enabled":root.use_occlusion_culling}
	for mesh in gate.find_children("*","MeshInstance3D",true,false):
		var materials: Array=[]
		for i in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(i)
			materials.append({"class":material.get_class() if material else "null","resource":material.resource_path if material else "","shader":material.shader.code.substr(0,300) if material is ShaderMaterial else ""})
		report.meshes.append({"path":str(mesh.get_path()),"visible":mesh.is_visible_in_tree(),"layers":mesh.layers,"transform":mesh.global_transform,"bounds":mesh.get_aabb(),"surfaces":mesh.mesh.get_surface_count(),"materials":materials})
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(0,1.6,16),Vector3(0,1.6,22),1)
	await physics_frame;await physics_frame
	report.closed_collision=not g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	camera=g.camera;report.player_camera_mask=camera.cull_mask
	g.players[1].spectator=false
	await capture("player-inside",Vector3(0,1.6,10),Vector3(0,1.6,19))
	camera=Camera3D.new();g.add_child(camera);camera.fov=80;camera.cull_mask=g.camera.cull_mask;g.players[1].spectator=true
	await capture("spectator-inside",Vector3(0,1.6,10),Vector3(0,1.6,19))
	await capture("outside",Vector3(0,5,28),Vector3(0,5,19))
	await capture("observer-original",Vector3(12,10,-16),Vector3(0,4,0))
	await capture("observer-inside",Vector3(12,10,-6),Vector3(0,4,0))
	root.use_occlusion_culling=false;camera.cull_mask=(1<<20)-1
	for mesh in gate.find_children("*","GeometryInstance3D",true,false):mesh.ignore_occlusion_culling=true
	await capture("observer-no-occlusion",Vector3(12,10,-16),Vector3(0,4,0))
	await capture("inside-no-occlusion",Vector3(0,1.6,10),Vector3(0,1.6,19))
	var originals: Dictionary={}
	for mesh in gate.find_children("*","MeshInstance3D",true,false):
		originals[mesh]=mesh.material_override
		var material:=StandardMaterial3D.new();material.albedo_color=Color.ORANGE;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
		mesh.material_override=material;mesh.show();mesh.layers=1
	gate.show()
	await capture("inside-solid-material",Vector3(0,1.6,10),Vector3(0,1.6,19))
	for mesh in originals:mesh.material_override=originals[mesh]
	tb.advance_time(60.);await physics_frame;await physics_frame
	report.open_position=gate.position;report.open_collision=not g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty();report.preparation_after=tb.preparation_left
	await capture("open",Vector3(0,1.6,10),Vector3(0,1.6,19))
	FileAccess.open(prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("GATE_PROBE_RESULT ",JSON.stringify(report))
	g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit()
