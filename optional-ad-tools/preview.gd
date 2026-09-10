extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args();var folder: String=args[0];var ids:=args[1].split(",")
	root.size=Vector2i(1280,800)
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/adaptation-report.json"))
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false);game.hud.hide()
	for row: Dictionary in report.maps:
		if not row.id in ids or row.status!="installed-candidate":continue
		var id: String=row.id
		var path: String=folder+"/maps/"+id+".bsp";game.map_catalog=[{"id":id,"title":row.title,"path":path,"scene":folder+"/preview-cache/"+row.sha256+".scn","sha256":row.sha256}]
		game._load_map(id)
		var camera: Camera3D=game.get_node("Overview");camera.make_current();game.camera=camera;camera.fov=95
		DirAccess.make_dir_recursive_absolute(folder+"/screenshots")
		for at in [0,5,10]:
			if at>=row.validation.spawns.size():continue
			var pos: Vector3=game.spawn_points[at];camera.position=pos+Vector3.UP*1.6
			# Use a real player spawn's authored facing, then pitch slightly down.
			camera.rotation=Vector3(-.08,game.spawn_yaws[at],0)
			for frame in 20:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/screenshots/"+id+"-"+str(at)+".png")
			print("AD_PREVIEW ",id," ",at)
	game.free();await process_frame;quit()
