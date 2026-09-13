extends SceneTree
var failures: Array=[]
var fallback:=OS.get_cmdline_user_args().has("--fallback")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1800,800);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("202832");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,2,8);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.7;camera.look_at(Vector3(0,.7,0))
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-35,-25,0)
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(15,5);world.add_child(floor_mesh)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("4b5663");floor_mesh.material_override=mat
	var library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var fixtures: Array=[["WALK",Vector3(0,0,-3),"stand",1.65,true],["RUN",Vector3(0,0,-9.4),"stand",1.65,true],["CROUCH",Vector3(0,0,-3),"crouch",1.05,true],["PRONE",Vector3(0,0,-1.5),"prone",.65,true],["JUMP",Vector3(0,5,-5),"stand",1.65,false],["FALL",Vector3(0,-5,-5),"stand",1.65,false]]
	for i in fixtures.size():
		var f: Array=fixtures[i];var actor:=Node3D.new();actor.position.x=(i-2.5)*1.45;actor.rotation.y=PI*.70;world.add_child(actor)
		var avatar=preload("res://deathmatch/art.gd").marine(Color("647f9c")) if fallback else library.create_avatar("9adf1b44e959d2688d62c2dd558e74315d6aa40e3bf8d281390b7a85dc0df9b7");actor.add_child(avatar);avatar.process_mode=Node.PROCESS_MODE_DISABLED
		if fallback:
			for tick in 74:avatar.animate(1.0/60,f[1],f[2],f[3],f[4],{},false)
			var label:=Label3D.new();label.text=f[0];label.font_size=36;label.pixel_size=.003;label.position=Vector3(actor.position.x,2.15,0);world.add_child(label)
			continue
		avatar.speed=Vector2(f[1].x,f[1].z).length();avatar.movement=f[1];avatar.stance=f[2];avatar.collider_height=f[3];avatar.grounded=f[4]
		for tick in 74:avatar._process(1.0/60);avatar.solver._process_modification_with_delta(1.0/60)
		avatar.gun.hide();avatar.offhand_gun.hide()
		var label:=Label3D.new();label.text=f[0];label.font_size=36;label.pixel_size=.003;label.position=Vector3(actor.position.x,2.15,0);world.add_child(label)
		var positions: Dictionary={}
		for bone in ["Hips","Head","LeftFoot","RightFoot","LeftLowerLeg","RightLowerLeg"]:
			var point: Vector3=avatar.to_local(avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(avatar.skeleton.find_bone(bone)).origin))
			positions[bone]=str(point)
			if not point.is_finite() or point.y<-.12:failures.append(f[0]+" invalid/below-floor "+bone)
		print("STANCE_POSE ",f[0]," ",JSON.stringify(positions))
	for i in 8:await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/stance-locomotion/fallback-poses.png" if fallback else "res://test-results/stance-locomotion/poses.png")
	print("AVATAR_STANCES_RESULT ",JSON.stringify(failures));world.free();quit(0 if failures.is_empty() else 1)
