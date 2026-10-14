extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("25312c");world.add_child(env)
	var library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(4,2.7,-5.5);camera.look_at(Vector3(0,.8,0));camera.current=true;camera.fov=55
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(30,30);floor_mesh.material_override=preload("res://deathmatch/art.gd").material(Color("536658"));world.add_child(floor_mesh)
	var hash:String=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false)
	for i in 3:
		var avatar=library.create_avatar(hash);world.add_child(avatar);avatar.position.x=(i-1)*2.2;avatar.set_weapon(1,"cq_shocktroop");avatar.set_equipment("jetpack");avatar.preview_mode=0
		var pack=preload("res://deathmatch/conquest/jetpack_model.gd").new();world.add_child(pack);avatar.backpack=pack
		if i==0:
			avatar.target_xr_pose=preload("res://deathmatch/vr/poses.gd").neutral();avatar.target_xr_pose.right.origin=Vector3(1.4,1.7,-.6);avatar.target_xr_pose.weapon=avatar.target_xr_pose.right
		if i==2:avatar.stance="prone";avatar.preview_mode=-1
		var label:=Label3D.new();label.text=["CONSTRAINED REACH","SHOULDER / BACK MOUNTS","INCAPACITATED HAND ATTACHMENT"][i];label.position=Vector3(0,2.1,0);label.font_size=24;label.pixel_size=.003;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;avatar.add_child(label)
	DisplayServer.window_set_title("UT99 · attachments and anatomical reach")
	for i in 50:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/ut99-attachments"))
	root.get_texture().get_image().save_png("res://test-results/ut99-attachments/front.png")
	camera.position=Vector3(-3,2.2,5.5);camera.look_at(Vector3(0,.8,0))
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/ut99-attachments/back.png")
	print("ATTACHMENT_PREVIEW_PASS");quit()
