extends SceneTree
var game
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func shot(name: String) -> void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hispeed-"+name+".png")
func run() -> void:
	var path: String=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-visual.scn","sha256":hash}]
	check(game._load_map(key),"Rebaked BSP loads")
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	if game.hud:game.hud.hide()
	var camera: Camera3D=game.get_node("Overview");game.camera=camera;camera.make_current()
	var map=game.get_node("Map")
	var baked_faces:=0;var rgb:=false;var invalid:=0;var overflow:=0
	for node in [map]+map.find_children("*","Node",true,false):
		baked_faces+=int(node.get_meta("baked_light_faces",0));rgb=rgb or bool(node.get_meta("baked_light_rgb",false))
		invalid+=int(node.get_meta("baked_light_invalid_faces",0));overflow+=int(node.get_meta("baked_light_overflow_faces",0))
	check(invalid==0 and overflow==0,"No malformed lightmap faces or atlas overflow")
	check(baked_faces>1000 and rgb,"Embedded RGB lightmap applied to map faces (%s)"%baked_faces)
	camera.position=Vector3(540,370,2770)/32;camera.look_at(Vector3(0,80,2600)/32)
	await shot("helicopter-front")
	camera.position=Vector3(-620,330,2320)/32;camera.look_at(Vector3(-140,100,2600)/32)
	await shot("helicopter-tail")
	var library=preload("res://deathmatch/avatars/library.gd").new();game.add_child(library)
	for sample in ["sample_d","sample_f","sample_g"]:
		var avatar=library.create_avatar(FileAccess.get_sha256(library.Paths.folder("vrm")+sample+".vrm"))
		check(avatar!=null,"Load VRM "+sample)
		if not avatar:continue
		game.add_child(avatar);avatar.set_process(false);avatar.rotation.y=PI
		if avatar.gun:avatar.gun.hide()
		if avatar.offhand_gun:avatar.offhand_gun.hide()
		for mesh in avatar.visual_meshes:
			for i in mesh.mesh.get_surface_count():
				var material: Material=mesh.get_active_material(i)
				if material is ShaderMaterial:check(material.get_shader_parameter("_ArenaLightingEnabled")==true,"Current MToon arena lighting active")
		for location in [{"name":"deck","feet":Vector3(0,.05,65)},{"name":"car3","feet":Vector3(0,.05,-16)},{"name":"upper","feet":Vector3(0,4.55,-57)}]:
			avatar.position=location.feet;camera.position=avatar.position+Vector3(0,1.05,3);camera.look_at(avatar.position+Vector3.UP*.9);camera.fov=45
			await shot("vrm-"+sample+"-"+location.name)
		avatar.free()
	print("HISPEED_VISUAL_RESULT ",JSON.stringify({"map_sha256":hash,"baked_faces":baked_faces,"rgb":rgb,"failures":failures}))
	game.free();quit(0 if failures.is_empty() else 1)
