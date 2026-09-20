extends SceneTree
func _initialize():run.call_deferred()
func run():
	var zone:=int(OS.get_cmdline_user_args()[0]);var folder:="res://maps/CQDistricts/district_%02d/"%zone
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();world.add_child(environment)
	var level: Node3D=load(folder+"presentation.scn").instantiate();world.add_child(level)
	preload("res://deathmatch/conquest/presentation.gd").apply(world)
	var camera:=Camera3D.new();camera.far=400;camera.fov=80;world.add_child(camera);camera.current=true
	DirAccess.make_dir_recursive_absolute("res://test-results/cq-maps")
	for view in [["plaza",Vector3(21,2,21),Vector3(-70,17,-70)],["interior",Vector3(-72,2,-87),Vector3(-72,12,-63)],["gallery",Vector3(-63,17,-88),Vector3(15,8,-65)],["aerial",Vector3(115,90,115),Vector3(0,4,0)]]:
		camera.position=view[1];camera.look_at(view[2]);await process_frame
		for i in 20:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/cq-maps/%02d-%s.png"%[zone,view[0]])
	world.free();quit()
