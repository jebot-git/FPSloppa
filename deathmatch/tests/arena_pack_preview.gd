extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false);game.hud.hide()
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://optional-arena-pack/manifest.json"))
	var args:=OS.get_cmdline_user_args();var only:=""
	if args.has("--only"):only=args[args.find("--only")+1]
	DirAccess.make_dir_recursive_absolute("res://optional-arena-pack/screenshots")
	for row: Dictionary in rows:
		if not only.is_empty() and not row.id in only.split(","):continue
		var path: String=ProjectSettings.globalize_path("res://optional-arena-pack/"+row.id+".bsp")
		game.map_catalog=[{"id":row.id,"title":row.title,"path":path,"scene":"user://arena-pack-baked-final/"+FileAccess.get_sha256(path)+".scn","sha256":FileAccess.get_sha256(path)}]
		game._load_map(row.id);game.match_mode.kind=row.mode;game.match_mode.reset()
		var camera: Camera3D=game.get_node("Overview");camera.make_current();game.camera=camera
		var middle: Dictionary=row.rooms[row.rooms.size()/2]
		if row.mode in ["ctf","tf"]:middle=row.rooms[1]
		var room: Vector3=Vector3(-middle.position[1],middle.position[2],-middle.position[0])/32.0
		camera.position=room+Vector3((row.half_room-60)/32.0,1.7,(row.half_room-64)/32.0)
		camera.look_at(room+Vector3(-row.half_room/32.0,1.9,-row.half_room/40.0));camera.fov=90
		for i in 12:await process_frame
		await create_timer(.25).timeout
		var runtime=game.get_node("Map/MapRuntime")
		print("PREVIEW_LIGHTS ",runtime.lights.size()," active ",runtime.is_processing()," camera ",camera.global_position)
		for lamp in runtime.lights:
			if lamp.visible:print("LAMP ",lamp.global_position," ",lamp.light_energy," ",lamp.omni_range)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://optional-arena-pack/screenshots/"+row.id+".png")
		print("ARENA_PREVIEW ",row.id)
	game.free();await process_frame;await process_frame;quit()
