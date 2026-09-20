extends SceneTree
func _initialize():run.call_deferred()
func run():
	var zone:=int(OS.get_cmdline_user_args()[0]);var folder:="res://maps/CQDistricts/district_%02d/"%zone
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();world.add_child(environment)
	var level: Node3D=preload("res://deathmatch/maps/loader.gd").read(folder+"district.bsp") if OS.get_cmdline_user_args().has("--raw") else load(folder+"presentation.scn").instantiate();world.add_child(level)
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"layout.json"));var room: Dictionary=layout.rooms[0];var c:=Vector3(room.center[0],0,room.center[2]);var d: float=room.half_size[1]
	var car: Array=layout.props.filter(func(p):return p.kind=="parked_vehicle" or p.kind=="freight_vehicle")[0].position;var street:=Vector3(car[0],0,car[2]);var street_eye:=street+Vector3(9,2.1,6);var nearest:=INF
	for road in layout.streets:
		for i in road.size()-1:
			var a:=Vector3(road[i][0],0,road[i][1]);var b:=Vector3(road[i+1][0],0,road[i+1][1]);var p:=Geometry3D.get_closest_point_to_segment(street,a,b)
			if p.distance_to(street)<nearest:
				nearest=p.distance_to(street);street_eye=p.move_toward(a,6)+Vector3.UP*1.9
	preload("res://deathmatch/conquest/presentation.gd").apply(world)
	var camera:=Camera3D.new();camera.far=400;camera.fov=80;world.add_child(camera);camera.current=true
	DirAccess.make_dir_recursive_absolute("res://test-results/cq-maps")
	for view in [["street",street_eye,street+Vector3.UP],["plaza",Vector3(21,2,21),Vector3(-70,17,-70)],["interior",c+Vector3(0,2,-d+3),c+Vector3(0,7,0)],["gallery",c+Vector3(0,7,-d-1.5),Vector3(0,2,0)],["upper",Vector3(-4,7.8,-12),Vector3(-31,7,37)],["skycourt",Vector3(4,1.9,0),Vector3(-2,13,0)],["aerial",Vector3(115,90,115),Vector3(0,4,0)]]:
		camera.position=view[1];camera.look_at(view[2]);await process_frame
		for i in 20:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/cq-maps/%02d-%s.png"%[zone,view[0]])
	world.free();quit()
