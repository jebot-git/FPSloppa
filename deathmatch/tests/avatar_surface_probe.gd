extends SceneTree
## Regression for view-dependent rim/matcap leaking into arena emission.
var failures: Array=[]
var world: Node3D
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func capture(label: String) -> Image:
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.save_png("res://test-results/avatar-emission-"+label+".png");return image
func difference(a: Image,b: Image) -> float:
	var total:=0.0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var aa:=a.get_pixel(x,y);var bb:=b.get_pixel(x,y)
			total+=absf(aa.r-bb.r)+absf(aa.g-bb.g)+absf(aa.b-bb.b)
	return total/(a.get_width()*a.get_height()*.25)
func run() -> void:
	root.size=Vector2i(900,900);root.content_scale_size=root.size
	world=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1,2.8);camera.look_at(Vector3(0,.9,0));camera.fov=43
	var library=load("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var avatar=library.create_avatar(FileAccess.get_sha256(library.Paths.folder("vrm")+"sample_d.vrm"));world.add_child(avatar);avatar.rotation.y=PI
	avatar.gun.hide();avatar.offhand_gun.hide()
	for i in 6:await process_frame
	avatar.process_mode=Node.PROCESS_MODE_DISABLED
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-35,-20,0);light.light_energy=.7
	var materials: Array=[]
	for mesh in avatar.visual_meshes:
		for index in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(index)
			if material is ShaderMaterial and not material in materials:materials.append(material)
	var white:=Image.create(1,1,false,Image.FORMAT_RGB8);white.fill(Color.WHITE);var texture:=ImageTexture.create_from_image(white)
	for material in materials:
		material.set_shader_parameter("_EmissionColor",Color.BLACK)
		material.set_shader_parameter("_RimColor",Color.BLACK)
		material.set_shader_parameter("_MatcapColor",Color.BLACK)
	var plain:=await capture("plain")
	for material in materials:
		material.set_shader_parameter("_RimColor",Color(4,4,4))
		material.set_shader_parameter("_MatcapColor",Color(4,4,4))
		material.set_shader_parameter("_SphereAdd",texture)
	var rim:=await capture("rim-matcap")
	var rim_delta:=difference(plain,rim)
	check(rim_delta<.0001,"Arena shading ignores legacy rim/matcap emission (%s)"%rim_delta)
	for material in materials:
		material.set_shader_parameter("_EmissionColor",Color(.06,.02,.01))
		material.set_shader_parameter("_EmissionMap",texture)
		material.set_shader_parameter("_EmissionMultiplier",1.0)
	var emissive:=await capture("authored")
	var emission_delta:=difference(rim,emissive)
	check(emission_delta>.001,"Authored emissive texture still affects output (%s)"%emission_delta)
	print("AVATAR_EMISSION_RESULT ",JSON.stringify({"rim_delta":rim_delta,"authored_emission_delta":emission_delta,"failures":failures}))
	world.free();quit(0 if failures.is_empty() else 1)
