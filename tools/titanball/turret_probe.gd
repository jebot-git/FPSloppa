extends SceneTree
var view
var camera: Camera3D
var rows: Array=[]
var failures: Array=[]
func _initialize():run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.12,.15,.2);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=1.;environment.environment=env;world.add_child(environment)
	view=preload("res://deathmatch/vehicles/ba2/view.gd").new();world.add_child(view);view.setup()
	camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(13,8,10);camera.look_at(Vector3(0,6,0));camera.make_current()
	var bones: Array=[]
	for i in view.skeleton.get_bone_count():bones.append({"name":view.skeleton.get_bone_name(i),"rest":view.skeleton.get_bone_rest(i)})
	var meshes: Array=[]
	for m in view.model.find_children("*","MeshInstance3D",true,false):
		var weights: Dictionary={}
		for surface in m.mesh.get_surface_count():
			var arrays: Array=m.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_BONES]==null:continue
			for i in arrays[Mesh.ARRAY_BONES].size():
				if arrays[Mesh.ARRAY_WEIGHTS][i]>.5:weights[str(arrays[Mesh.ARRAY_BONES][i])]=weights.get(str(arrays[Mesh.ARRAY_BONES][i]),0)+1
		meshes.append({"name":m.name,"skeleton":str(m.skeleton),"skin_binds":m.skin.get_bind_count() if m.skin else 0,"weights":weights})
	for angle in [-25.,0.,25.]:
		var state: Dictionary={"distance":0.,"speed":0.,"pitches":[deg_to_rad(angle),deg_to_rad(angle)]}
		for i in 12:view.update_robot(state,true,false);await process_frame
		var poses: Array=[]
		for name in ["Cannon.L","Cannon.R"]:
			var index: int=view.skeleton.find_bone(name)
			var barrel: Vector3=(view.skeleton.global_basis*view.skeleton.get_bone_global_pose(index).basis.y).normalized()
			var expected:=Basis(Vector3.RIGHT,deg_to_rad(angle))*Vector3.BACK
			if barrel.dot(expected)<.999:failures.append("%s %s elevation disagrees with firing direction"%[name,angle])
			poses.append({"bone":name,"rotation":view.skeleton.get_bone_pose_rotation(index),"global":view.skeleton.get_bone_global_pose(index)})
		await RenderingServer.frame_post_draw
		var file: String="res://test-results/titanball/turret-probe-%s.png"%int(angle)
		root.get_texture().get_image().save_png(file);rows.append({"command_degrees":angle,"poses":poses,"file":file})
	var result: Dictionary={"failures":failures,"rest_only":view.skeleton.show_rest_only,"bones":bones,"meshes":meshes,"samples":rows}
	FileAccess.open("res://test-results/titanball/turret-probe.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("TURRET_PROBE_RESULT ",JSON.stringify(result))
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
