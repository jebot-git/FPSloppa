extends SceneTree
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
const Clips=preload("res://deathmatch/avatars/lod_clips.gd")
var failures: Array=[]
var checks:=0
var rigs: Array=[]
var camera:=Camera3D.new()
var world:=Node3D.new()
var before: Dictionary={}
var output:="/tmp/cq-lod-runtime"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func settle(seconds: float=.3) -> void:await create_timer(seconds).timeout
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	root.add_child(world);world.add_child(camera);camera.current=true;camera.fov=85;camera.position=Vector3(0,1,30)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();world.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.025,.04,.07)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-25,0)
	var library:=Library.new()
	for sample in ["sample_d","sample_f","sample_g"]:
		library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
		var rig=Loader.create_avatar(library,sample)
		if rig==null:push_error("VRM import failed");quit(1);return
		var actor:=Node3D.new();world.add_child(actor);actor.position.x=(rigs.size()-1)*2.5;actor.add_child(rig)
		rig.set_weapon(2,"ut99");rig.movement=Vector3(0,0,-4);rig.speed=4
		for instance in rig.visual_meshes:
			var mesh: ArrayMesh=instance.mesh
			var surfaces: Array=[]
			for surface in mesh.get_surface_count():surfaces.append([var_to_bytes(mesh.surface_get_arrays(surface)).hex_encode().sha256_text(),var_to_bytes(mesh.surface_get_blend_shape_arrays(surface)).hex_encode().sha256_text(),mesh.surface_get_material(surface)])
			before[mesh]=surfaces
		rig.enable_distance_lod();rigs.append(rig)
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		var complete:=true
		for mesh in before:complete=complete and mesh.get_meta("cq_mesh_lod","")=="ready"
		if complete:break
		await process_frame
	for mesh in before:
		check(mesh.get_meta("cq_mesh_lod","")=="ready","LOD generation finished")
		check(int(mesh.get_meta("cq_mesh_lod_levels",0))>0,"Mesh has generated LOD levels")
		check(mesh.get_surface_count()==before[mesh].size(),"Material surfaces preserved")
		for surface in mesh.get_surface_count():
			check(var_to_bytes(mesh.surface_get_arrays(surface)).hex_encode().sha256_text()==before[mesh][surface][0],"Vertices/skin/UV arrays unchanged")
			check(var_to_bytes(mesh.surface_get_blend_shape_arrays(surface)).hex_encode().sha256_text()==before[mesh][surface][1],"Morph arrays unchanged")
			check(mesh.surface_get_material(surface)==before[mesh][surface][2],"Original MToon material retained")
	await settle()
	for rig in rigs:
		check(rig.distance_lod.using_generic and not rig.solver.active,"Far rig replaces IK")
		check(not rig.eyes.active and not rig.mouth.is_processing(),"Far cosmetics paused")
		for secondary in rig.secondary_nodes:check(secondary.local_body_disabled,"Far spring simulation paused")
		for mesh in rig.visual_meshes:check(mesh.visibility_range_end==0,"Avatar remains visible beyond 65 m")
	var first=rigs[1]
	var previous_key: String=first.distance_lod.current_key
	first.movement=Vector3(4,0,0)
	Clips.bake_frame=Engine.get_process_frames() # Another avatar owns this frame's bake budget.
	first.distance_lod.update(1.0/60)
	check(first.distance_lod.using_generic and first.distance_lod.current_key==previous_key,"Clip-cache miss retains the previous generic pose")
	await settle()
	check(first.distance_lod.current_key!=previous_key,"Deferred directional clip becomes available")
	# Tier hysteresis and scope promotion.
	camera.position.z=17;await settle();check(first.distance_lod.tier==2,"18 m tier hysteresis prevents churn")
	camera.position.z=14;await settle();check(first.distance_lod.tier==1 and first.solver.active,"Near range restores IK")
	camera.position.z=30;await settle();check(first.distance_lod.tier==2,"Distance enters generic tier")
	camera.fov=15;await settle();check(first.distance_lod.tier==0 and first.solver.active,"Scope magnification restores detailed IK")
	camera.fov=85;camera.position.z=80;await settle();check(first.distance_lod.tier==3,"Long distance uses 15 Hz tier")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)>0,"Avatars actually render at 80 m")
		root.get_texture().get_image().save_png(output+"-80m.png")
	first.set_first_person(true);await settle();check(first.distance_lod.tier==0 and first.solver.active and not first.distance_lod.using_generic,"Local first-person never uses generic pose")
	first.set_first_person(false);camera.position.z=30;await settle()
	var xr_camera:=XRCamera3D.new();world.add_child(xr_camera);xr_camera.position=Vector3(0,1,30);xr_camera.current=true;await settle()
	check(first.solver.active and not first.distance_lod.using_generic and not first.distance_lod.active,"XR camera retains legacy IK without generic modifier")
	first.solver.solve_tick=0;first.solver._process_modification_with_delta(0)
	check(is_equal_approx(first.solver.solve_tick,1.0/15.0),"XR remote IK retains 15 Hz distant cadence")
	xr_camera.free();camera.current=true;await settle()
	# Exercise generic stances/directions, airborne states, aim, death and return.
	var states:=[["stand",1.65,Vector3(0,0,-9.4),true],["crouch",1.05,Vector3(2,0,0),true],["prone",.65,Vector3(0,0,1),true],["stand",1.65,Vector3(0,5,0),false],["stand",1.65,Vector3(0,-5,0),false],["stand",1.65,Vector3.ZERO,false]]
	for state in states:
		for rig in rigs:rig.stance=state[0];rig.collider_height=state[1];rig.movement=state[2];rig.speed=Vector2(state[2].x,state[2].z).length();rig.grounded=state[3];rig.aim_pitch=.35
		await settle(.35)
		for rig in rigs:
			check(rig.distance_lod.using_generic,"Generic state ready: "+str(state[0])+str(state[2]))
			for bone in rig.distance_lod.bone_ids:
				var pose: Transform3D=rig.skeleton.get_bone_global_pose(bone)
				check(pose.is_finite() and pose.origin.length()<10,"Retargeted bones remain finite and bounded")
	first.dead=true;await settle();check(first.solver.active and not first.distance_lod.using_generic,"Death restores death-pose solver")
	first.dead=false;await settle();check(first.distance_lod.using_generic,"Respawn restores distance animation")
	var duplicate=Loader.create_avatar(library,"sample_d")
	check(duplicate.visual_meshes[0].mesh==rigs[0].visual_meshes[0].mesh,"Repeated VRM reuses generated mesh resource");duplicate.free()
	# A close inspection render of sampled far poses; camera promotion is disabled
	# by freezing rig updates after the distant animations have been evaluated.
	if DisplayServer.get_name()!="headless":
		for index in rigs.size():
			var rig=rigs[index];rig.stance="stand";rig.collider_height=1.65;rig.grounded=true;rig.movement=Vector3(0,0,-4);rig.speed=4
		await settle(.4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"-far.png")
		for rig in rigs:
			rig.set_process(false);rig.distance_lod.active=false;rig.solver.active=false
			for bone in rig.distance_lod.last_pose:
				rig.skeleton.set_bone_pose_rotation(bone,rig.distance_lod.last_pose[bone][0]);rig.skeleton.set_bone_pose_position(bone,rig.distance_lod.last_pose[bone][1])
		camera.position=Vector3(0,1.3,-6);camera.look_at(Vector3(0,.85,0));camera.fov=65
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"-detail.png")
	var report:={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"retargeted_clips":Clips.bakes,"mesh_jobs":root.get_node("AvatarMeshLOD").completed}
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CQ_LOD_RUNTIME ",JSON.stringify(report));world.free();library.free();quit(0 if failures.is_empty() else 1)
