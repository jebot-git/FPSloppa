extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(360,360);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var body:=StaticBody3D.new();body.position=Vector3(1000,1,-2.1);world.add_child(body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,4,.2);shape.shape=box;body.add_child(shape)
	var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=box.size;mesh.mesh=cube;body.add_child(mesh)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("9d978b");mesh.material_override=mat
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(1000,1,0);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.9;camera.make_current()
	var marks:=preload("res://deathmatch/effects/bullet_marks.gd").new();world.add_child(marks);marks.set_process(false)
	var layer:=CanvasLayer.new();world.add_child(layer);var label:=Label.new();label.position=Vector2(16,12);label.add_theme_font_size_override("font_size",22);layer.add_child(label)
	DirAccess.make_dir_recursive_absolute("res://test-results/weapon-decals")
	await physics_frame;await physics_frame
	for style in 7:
		marks.elapsed+=marks.LIFETIME+1
		assert(marks.place(Vector3(1000,1,-2),Vector3.BACK,style));marks._process(0)
		label.text=["Bullet · 6.5 cm","Cut · 22 cm","Dent · 16 cm","Scorch · 65 cm","Energy · 24 cm","Bio · 48 cm","Pin · 4.5 cm"][style]
		for frame in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/weapon-decals/style-%d.png"%style)
	world.free();quit()
